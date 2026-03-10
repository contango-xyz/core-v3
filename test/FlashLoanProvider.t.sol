// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC7399 } from "../src/flashloan/dependencies/IERC7399.sol";
import { ERC20Lib } from "../src/libraries/ERC20Lib.sol";

contract FlashLoanProvider is IERC7399 {

    using ERC20Lib for IERC20;

    // fee in e4 (0.005e4 = 0.05%)
    uint256 public fee;

    function setFee(uint256 _fee) public returns (IERC7399) {
        fee = _fee;
        return this;
    }

    function maxFlashLoan(IERC20 asset) external view override returns (uint256) {
        return asset.myBalance();
    }

    function flashFee(
        IERC20,
        /* asset */
        uint256 amount
    )
        public
        view
        override
        returns (uint256)
    {
        return amount * fee / 1e4;
    }

    function flash(
        address loanReceiver,
        IERC20 asset,
        uint256 amount,
        bytes calldata data,
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback
    ) external override returns (bytes memory result) {
        uint256 balanceBefore = asset.myBalance();

        IERC20(asset).transferOut(address(this), loanReceiver, amount);
        uint256 loanFee = flashFee(asset, amount);
        result = callback(msg.sender, address(this), asset, amount, loanFee, data);

        if (asset.myBalance() < (balanceBefore + loanFee)) revert("Flashloan not repaid");
    }

}
