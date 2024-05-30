// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CascadeLimitOrder is Ownable {
    struct Order {
        int24 lowerTargetTick; // For Buy Limit Orders
        int24 upperTargetTick; // For Take-Profit Orders
        bool isOnLower;
        address user;
    }

    ISwapRouter router;
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
        address _router,
        address _pool,
        INonfungiblePositionManager _positionManager
    ) Ownable(msg.sender) {
        router = ISwapRouter(_router);
        pool = IUniswapV3Pool(_pool);
        positionManager = INonfungiblePositionManager(_positionManager);
        tokenA = IERC20(pool.token0());
        tokenB = IERC20(pool.token1());
    }

    function placeInitialOrder(
        address token,
        uint256 amount,
        int24 lowerTargetTick,
        int24 upperTargetTick
    ) external {
        require(amount > 0, "Amount must be greater than 0");

        (, int24 tick, , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        int24 lowerTargetTickSpacing = lowerTargetTickSpacing - tickSpacing;
        int24 upperTargetTickSpacing = upperTargetTickSpacing + tickSpacing;

        bool isInRange = lowerTargetTick < tick && tick < upperTargetTick && lowerTargetTickSpacing < tick && tick < upperTargetTickSpacing;
        if (isInRange) {
            if (token == address(tokenA)) {
                // Buy Limit Orders
                _placeOrder(
                    tokenA,
                    amount,
                    lowerTargetTickSpacing,
                    lowerTargetTick,
                    true
                );
            } else {
                // Take-Profit Orders
                _placeOrder(
                    tokenB,
                    amount,
                    upperTargetTick,
                    upperTargetTickSpacing,
                    false
                );
            }
        } else {
            if (lowerTargetTick > tick && lowerTargetTickSpacing > tick) {
                // Take-Profit Orders
                _placeOrder(
                    tokenB,
                    amount,
                    upperTargetTick,
                    upperTargetTickSpacing,
                    false
                );
            } else if (upperTargetTick < tick && upperTargetTickSpacing < tick) {
                // Buy Limit Orders
                _placeOrder(
                    tokenA,
                    amount,
                    lowerTargetTickSpacing,
                    lowerTargetTick,
                    true
                );
            }
        }

        // ...

        _orderCount++;
        orders[_orderCount] = Order({
            firstTargetTick: firstTargetTick,
            secondTargetTick: secondTargetTick,
            isOnFirst: true, // TODO: Verify if isOnFirst or isOnSecond with the previous logic
            user: msg.sender
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

        emit OrderExecuted(tokenId);
    }

    // Create a limit order with a small range
    function _placeOrder(
        address token,
        uint256 amount,
        int24 tickLower,
        int24 tickUpper,
        bool isOnFirst
    ) private {
        TransferHelper.safeApprove(
            token,
            address(nonfungiblePositionManager),
            amount
        );

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: pool.fee(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: isOnFirst ? amount : 0,
                amount1Desired: isOnFirst ? 0 : amount,
                amount0Min: 0, // TODO: set a slippage tolerance
                amount1Min: 0, // TODO: set a slippage tolerance
                recipient: address(this),
                deadline: block.timestamp + 15 minutes // TODO: set a deadline
            });

        (uint256 tokenId, uint128 liquidity, , ) = positionManager.mint(params);

        emit OrderPlaced(tokenId, tickLower, tickUpper, liquidity);
    }

    function cancelOrder(uint256 orderId) external {
        // TODO: burn the position
        // TODO: refund the user

        delete orders[orderId];
    }
}
