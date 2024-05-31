// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/TransferHelper.sol";

contract CascadeLimitOrder is Ownable {
    struct Order {
        int24 lowerTargetTick; // For Buy Limit Orders
        int24 upperTargetTick; // For Take-Profit Orders
        bool isOnLower;
        address user;
        uint256 tokenId;
    }

    IUniswapV3Pool pool;
    INonfungiblePositionManager positionManager;

    IERC20 tokenA;
    IERC20 tokenB;

    mapping(uint256 => Order) public orders;
    uint256 private _orderCount;

    event OrderPlaced(
        uint256 indexed orderId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );
    event OrderExecuted(uint256 indexed orderId);

    constructor(
        address _pool,
        INonfungiblePositionManager _positionManager
    ) Ownable(msg.sender) {
        pool = IUniswapV3Pool(_pool);
        positionManager = INonfungiblePositionManager(_positionManager);
        tokenA = IERC20(pool.token0());
        tokenB = IERC20(pool.token1());
    }

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

        uint256 tokenId;
        bool isInRange = lowerTargetTick < tick &&
            tick < upperTargetTick &&
            lowerTargetTickSpacing < tick &&
            tick < upperTargetTickSpacing;
        bool isAbove = upperTargetTick < tick &&
                upperTargetTickSpacing < tick;
        if (isInRange) {
            // if isOnLower => Buy Limit Orders, if not => Take-Profit Orders
            (tokenId) = _placeOrder(
                isOnLower ? tokenA : tokenB,
                amount,
                isOnLower ? lowerTargetTickSpacing : upperTargetTick,
                isOnLower ? lowerTargetTick : upperTargetTickSpacing,
                isOnLower
            );
        } else {
            // If is Above  => Buy Limit Orders, if not => Take-Profit Orders
            (tokenId) = _placeOrder(
                isAbove ? tokenA : tokenB,
                amount,
                isAbove ? lowerTargetTickSpacing : upperTargetTick,
                isAbove ? lowerTargetTick : upperTargetTickSpacing,
                isAbove
            );
        }
        
        _orderCount++;
        orders[_orderCount] = Order({
            lowerTargetTick: lowerTargetTick,
            upperTargetTick: upperTargetTick,
            isOnLower: isInRange ? isOnLower : isAbove,
            user: msg.sender,
            tokenId: tokenId
        });
    }

    function executeOrder(uint256 orderId) external {
        // TODO: Where is the position (on the first or second target price)
        // TODO: verify if the current tick is > or < the first and second target price
        // Burn actual postion + claim fees
        // TODO: Create a limit order with a small range on the other tick
        // _placeOrder(token, amount, secondTargetPrice)
        // tweak isOnFirst orders[_orderCount].isOnFirst = !orders[_orderCount].isOnFirst;
        // ...
        // emit OrderExecuted(tokenId);
    }

    // Create a limit order with a small range
    function _placeOrder(
        IERC20 token,
        uint256 amount,
        int24 tickLower,
        int24 tickUpper,
        bool isOnLower
    ) private returns (uint256) {
        TransferHelper.safeApprove(
            address(token),
            address(positionManager),
            amount
        );

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                fee: pool.fee(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: isOnLower ? amount : 0,
                amount1Desired: isOnLower ? 0 : amount,
                amount0Min: 0, // TODO: set a slippage tolerance
                amount1Min: 0, // TODO: set a slippage tolerance
                recipient: address(this),
                deadline: block.timestamp + 15 minutes // TODO: set a deadline
            });

        (uint256 tokenId, uint128 liquidity, , ) = positionManager.mint(params);

        emit OrderPlaced(tokenId, tickLower, tickUpper, liquidity);

        return tokenId;
    }

    function cancelOrder(uint256 orderId) external {
        // TODO: burn the position
        // TODO: refund the user

        delete orders[orderId];
    }
}
