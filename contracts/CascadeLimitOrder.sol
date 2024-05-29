// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CascadeLimitOrder is Ownable {
    struct Order {
        int24 firstTargetPrice; // tick
        int24 secondTargetPrice; // tick
        bool isOnFirst;
        address user;
    }

    ISwapRouter router;

    mapping(uint256 => Order) public orders;
    uint256 private _orderCount;

    constructor(address _router) Ownable(msg.sender) {
        router = ISwapRouter(_router);
    }

    function placeInitialOrder(
        address token,
        uint256 amount,
        int24 firstTargetPrice,
        int24 secondTargetPrice
    ) external {
        // TODO: Verify if current tick > secondTargetPrice && < firstTargetPrice
        // TODO: Verify if good token is given with the previous logic

        // TODO: Create a limit order with a small range
        // _placeOrder

        // ...

        _orderCount++;
        orders[_orderCount] = Order({
            firstTargetPrice: firstTargetPrice,
            secondTargetPrice: secondTargetPrice,
            isOnFirst: true, // TODO: Verify if isOnFirst or isOnSecond with the previous logic
            user: msg.sender
        });
    }

    function executeOrder(uint256 orderId) external {   
        // TODO: Where is the position (on the first or second target price)
        // TODO: verify if the current tick is > or < the first and second target price

        // Burn actual postion + claim fees
        // Swap actual token to the other token

        // TODO: Create a limit order with a small range on the other tick
        // _placeOrder

        // tweak isOnFirst

        // ...
    }

    function _placeOrder(
        address token,
        uint256 amount,
        int24 targetPrice,
        bool isOnFirst
    ) private {
        // TODO: Create a limit order with a small range
    }

    function cancelOrder(uint256 orderId) external {
        
        // TODO: burn the position
        // TODO: refund the user

        delete orders[orderId];
    }
}
