//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract AsyncSpotMarket {

    using Address for *;

    struct Swap {
        IERC20 sell;
        uint256 sellAmount;
        IERC20 buy;
        uint256 buyAmount;
    }

    struct Hook {
        address target;
        bytes data;
    }

    struct Order {
        address account;
        Hook preHook;
        Swap swap;
        Hook postHook;
    }

    uint256 public spread;

    constructor(uint256 _spread) {
        spread = _spread;
    }

    function setSpread(uint256 _spread) external {
        spread = _spread;
    }

    function settle(Order memory order) external {
        uint256 buyAmount = order.swap.buyAmount * (1e18 - spread) / 1e18;

        order.swap.buy.transfer(order.account, buyAmount);

        if (order.preHook.target != address(0)) order.preHook.target.functionCall(order.preHook.data);

        order.swap.sell.transferFrom(order.account, address(this), order.swap.sellAmount);

        if (order.postHook.target != address(0)) order.postHook.target.functionCall(order.postHook.data);
    }

}
