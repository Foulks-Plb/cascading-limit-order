// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./interfaces/TransferHelper.sol";
import "./interfaces/INonfungiblePositionManager.sol";

contract CascadeLimitOrder {
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint24 public constant poolFee = 3000;

    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    IUniswapV3Pool public immutable pool;

    /// @notice Represents the strategy for cascading limit orders
    struct Strategy {
        uint256 tokenId;
        int24 lowerTargetTick;
        int24 upperTargetTick;
        bool isOnLower;
        address owner;
        uint128 liquidity;
    }
    uint256 private _strategyCount;
    mapping(uint256 => Strategy) public strategies;

    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        IUniswapV3Pool _pool
    ) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
        pool = _pool;
    }

    /// @notice Create and place an initial order for a strategy
    /// @param amount The amount of liquidity to place in the order
    /// @param lowerTargetTick The lower tick of the position
    /// @param upperTargetTick The upper tick of the position
    /// @param isOnLower If the order is on the lower side of the tick
    function placeInitialOrder(
        uint256 amount,
        int24 lowerTargetTick,
        int24 upperTargetTick,
        bool isOnLower
    ) external {
        require(amount > 0, "Amount must be greater than 0");
        require(
            lowerTargetTick < upperTargetTick,
            "Lower target tick must be less than upper target tick"
        );

        (, int24 tick, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        int24 lowerTargetTickSpacing = lowerTargetTick - tickSpacing;
        int24 upperTargetTickSpacing = upperTargetTick + tickSpacing;

        require(
            tick != lowerTargetTick &&
                tick != upperTargetTick &&
                tick != upperTargetTickSpacing &&
                tick != lowerTargetTickSpacing,
            "Tick is equal to target tick"
        );

        uint256 tokenId;
        uint128 liquidity;
        bool isInRange = lowerTargetTick < tick && tick < upperTargetTick;
        bool isAbove = upperTargetTickSpacing < tick;

        if (isInRange) {
            // if isOnLower => Buy Limit Orders, if not => Take-Profit Orders
            (tokenId, liquidity) = mintPosition(
                isOnLower ? lowerTargetTickSpacing : upperTargetTick,
                isOnLower ? lowerTargetTick : upperTargetTickSpacing,
                isOnLower ? amount : 0,
                isOnLower ? 0 : amount
            );
        } else {
            // If is Above  => Buy Limit Orders, if not => Take-Profit Orders
            (tokenId, liquidity) = mintPosition(
                isAbove ? lowerTargetTickSpacing : upperTargetTick,
                isAbove ? lowerTargetTick : upperTargetTickSpacing,
                isAbove ? amount : 0,
                isAbove ? 0 : amount
            );
        }

        _strategyCount++;
        strategies[_strategyCount] = Strategy({
            tokenId: tokenId,
            lowerTargetTick: lowerTargetTick,
            upperTargetTick: upperTargetTick,
            isOnLower: isInRange ? isOnLower : isAbove,
            owner: msg.sender,
            liquidity: liquidity
        });
    }

    /// @notice Calls the mint function defined in periphery, mints the same amount of each token.
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 to mint
    /// @param amount1 The amount of token1 to mint
    /// @return tokenId The id of the newly minted ERC721
    /// @return liquidity The amount of liquidity for the position
    function mintPosition(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) public returns (uint256 tokenId, uint128 liquidity) {
        // transfer tokens to contract
        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amount0
        );
        TransferHelper.safeTransferFrom(
            USDC,
            msg.sender,
            address(this),
            amount1
        );

        // Approve the position manager
        TransferHelper.safeApprove(
            DAI,
            address(nonfungiblePositionManager),
            amount0
        );
        TransferHelper.safeApprove(
            USDC,
            address(nonfungiblePositionManager),
            amount1
        );

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: DAI,
                token1: USDC,
                fee: poolFee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0, // TODO: set a slippage tolerance
                amount1Min: 0, // TODO: set a slippage tolerance
                recipient: address(this),
                deadline: block.timestamp + 15 minutes
            });

        (tokenId, liquidity, , ) = nonfungiblePositionManager.mint(params);
    }

    /// @notice Exucutes the order for a given strategy and tweaks the strategy
    /// @param strategyId The id of the strategy
    function executeOrder(uint256 strategyId) external {
        Strategy memory strategy = strategies[strategyId];
        (, int24 tick, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        int24 lowerTargetTickSpacing = strategy.lowerTargetTick - tickSpacing;
        int24 upperTargetTickSpacing = strategy.upperTargetTick + tickSpacing;

        uint256 amount0;
        uint256 amount1;
        // If isOnLower, must tick < lowerTargetTickSpacing
        // If !isOnLower, must tick > upperTargetTickSpacing
        if (strategy.isOnLower && tick < lowerTargetTickSpacing) {
            (amount0, amount1) = _removeLiquidityInPosition(strategy.tokenId);
        } else if (!strategy.isOnLower && tick < upperTargetTickSpacing) {
            (amount0, amount1) = _removeLiquidityInPosition(strategy.tokenId);
        } else {
            revert("Strategy cant tweak");
        }

        // Create a new position to tweak the strategy
        (uint256 tokenId, uint128 liquidity) = mintPosition(
            strategy.isOnLower
                ? strategy.upperTargetTick
                : lowerTargetTickSpacing,
            strategy.isOnLower
                ? upperTargetTickSpacing
                : strategy.lowerTargetTick,
            strategy.isOnLower ? 0 : amount0,
            strategy.isOnLower ? amount1 : 0
        );

        // Send fees collected from other token to owner
        TransferHelper.safeTransfer(
            strategy.isOnLower ? DAI : USDC,
            strategy.owner,
            strategy.isOnLower ? amount0 : amount1
        );

        // update strategy
        strategy.liquidity = liquidity;
        strategy.tokenId = tokenId;
        strategy.isOnLower = !strategy.isOnLower;
        strategies[strategyId] = strategy;
    }

    /// @notice A function that removes liquidity.
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount received back in token0
    /// @return amount1 The amount returned back in token1
    function _removeLiquidityInPosition(
        uint256 tokenId
    ) internal returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
            .DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: strategies[tokenId].liquidity,
                amount0Min: 0, // TODO: set a slippage tolerance
                amount1Min: 0, // TODO: set a slippage tolerance
                deadline: block.timestamp + 15 minutes
            });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
    }

    function cancelStrategy(uint256 strategyId) external {
        // TODO: remove liquidity
        // TODO: refund the user

        // delete strategies[strategyId];
    }
}
