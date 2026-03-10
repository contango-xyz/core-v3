//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ACCOUNT_BALANCE } from "../constants.sol";
import { ERC20Lib, EIP2098Permit } from "../libraries/ERC20Lib.sol";
import { IWETH9 } from "../dependencies/IWETH9.sol";

contract TokenAction {

    using ERC20Lib for *;
    using Address for *;

    event NativeTransfer(address indexed to, uint256 amount);

    IWETH9 public immutable NATIVE_TOKEN;

    constructor(IWETH9 _nativeToken) {
        NATIVE_TOKEN = _nativeToken;
    }

    function pull(IERC20 token, uint256 amount, address from, bool usePermit2) external returns (uint256) {
        return token.transferOut(from, address(this), _remoteAmount(token, amount, from), usePermit2);
    }

    function pullWithPermit(IERC20 token, uint256 amount, address from, EIP2098Permit memory permit) external returns (uint256) {
        return token.transferOut(from, address(this), _remoteAmount(token, amount, from), permit);
    }

    function push(IERC20 token, uint256 amount, address to) external returns (uint256) {
        return token.transferOut(address(this), to, _localAmount(token, amount));
    }

    function transfer(IERC20 token, uint256 amount, address from, address to) external returns (uint256) {
        return token.transferOut(from, to, _remoteAmount(token, amount, from));
    }

    function approve(IERC20 token, uint256 amount, address spender) external returns (uint256) {
        return token.forceApprove(spender, _localAmount(token, amount));
    }

    function infiniteApprove(IERC20 token, address spender) external {
        token.forceApprove(spender, type(uint256).max);
    }

    function depositNative(uint256 amount, address to) external payable returns (uint256) {
        return NATIVE_TOKEN.depositNative(_nativeAmount(amount), to);
    }

    function withdrawNative(uint256 amount, address payable to) external returns (uint256) {
        return NATIVE_TOKEN.transferOutNative(to, _localAmount(NATIVE_TOKEN, amount));
    }

    function transferNative(uint256 amount, address payable to) external {
        require(to != address(0), ERC20Lib.ZeroDestination());
        amount = _nativeAmount(amount);
        uint256 balance = address(this).balance;
        require(balance >= amount, ERC20Lib.InsufficientNativeBalance(balance, amount));
        to.sendValue(amount);
        emit NativeTransfer(to, amount);
    }

    function _remoteAmount(IERC20 token, uint256 amount, address from) internal view returns (uint256) {
        return amount == ACCOUNT_BALANCE ? token.balanceOf(from) : amount;
    }

    function _localAmount(IERC20 token, uint256 amount) internal view returns (uint256) {
        return amount == ACCOUNT_BALANCE ? token.myBalance() : amount;
    }

    function _nativeAmount(uint256 amount) internal view returns (uint256) {
        return amount == ACCOUNT_BALANCE ? address(this).balance : amount;
    }

}
