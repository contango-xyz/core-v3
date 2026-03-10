//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SpotMarket {

    using SafeERC20 for IERC20;

    uint256 public spread;

    constructor(uint256 _spread) {
        spread = _spread;
    }

    function setSpread(uint256 _spread) external {
        spread = _spread;
    }

    function swap(IERC20 sell, uint256 sellAmount, IERC20 buy, uint256 buyAmount) public {
        buyAmount = buyAmount * (1e18 - spread) / 1e18;
        sell.safeTransferFrom(msg.sender, address(this), sellAmount);
        buy.safeTransfer(msg.sender, buyAmount);
    }

    function swapAtPrice(IERC20 sell, uint256 sellAmount, IERC20 buy, uint256 price) external {
        uint256 buyAmount = sellAmount * price / 1e18;
        buyAmount = buyAmount * (10 ** IERC20Metadata(address(buy)).decimals()) / (10 ** IERC20Metadata(address(sell)).decimals());

        swap(sell, sellAmount, buy, buyAmount);
    }

}
