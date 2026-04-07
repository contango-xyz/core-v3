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

    /**
     * @notice Pulls tokens from a remote address to the current contract.
     * @dev See `TokenAction.t.sol` for examples.
     * @param token The ERC20 token to pull.
     * @param amount The amount to pull. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param from The address to pull tokens from.
     * @param usePermit2 Whether to use the Permit2 protocol.
     * @return The actual amount pulled.
     * @custom:example `pull(mockToken, 100e18, user1, false)`
     */
    function pull(IERC20 token, uint256 amount, address from, bool usePermit2) external returns (uint256) {
        return token.transferOut(from, address(this), _remoteAmount(token, amount, from), usePermit2);
    }

    /**
     * @notice Pulls tokens from a remote address using an EIP-2098 permit.
     * @dev Supports both standard ERC-2612 and Permit2 signatures via `ERC20Lib`.
     * @param token The ERC20 token to pull.
     * @param amount The amount to pull.
     * @param from The address to pull tokens from.
     * @param permit The encoded permit data.
     * @return The actual amount pulled.
     * @custom:example `pullWithPermit(mockToken, amount, user1, permit)`
     */
    function pullWithPermit(IERC20 token, uint256 amount, address from, EIP2098Permit memory permit) external returns (uint256) {
        return token.transferOut(from, address(this), _remoteAmount(token, amount, from), permit);
    }

    /**
     * @notice Pushes tokens from the current contract to a remote address.
     * @param token The ERC20 token to push.
     * @param amount The amount to push. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param to The destination address.
     * @return The actual amount pushed.
     * @custom:example `push(mockToken, ACCOUNT_BALANCE, user2)`
     */
    function push(IERC20 token, uint256 amount, address to) external returns (uint256) {
        return token.transferOut(address(this), to, _localAmount(token, amount));
    }

    /**
     * @notice Transfers tokens from one remote address to another.
     * @param token The ERC20 token to transfer.
     * @param amount The amount to transfer. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param from The source address.
     * @param to The destination address.
     * @return The actual amount transferred.
     */
    function transfer(IERC20 token, uint256 amount, address from, address to) external returns (uint256) {
        return token.transferOut(from, to, _remoteAmount(token, amount, from));
    }

    /**
     * @notice Approves a spender to use tokens from the current contract.
     * @param token The ERC20 token to approve.
     * @param amount The amount to approve. Use `ACCOUNT_BALANCE` for the current balance.
     * @param spender The address to approve.
     * @return The actual amount approved.
     */
    function approve(IERC20 token, uint256 amount, address spender) external returns (uint256) {
        return token.forceApprove(spender, _localAmount(token, amount));
    }

    /**
     * @notice Grants infinite approval to a spender.
     * @param token The ERC20 token to approve.
     * @param spender The address to approve.
     */
    function infiniteApprove(IERC20 token, address spender) external {
        token.forceApprove(spender, type(uint256).max);
    }

    /**
     * @notice Deposits native tokens (ETH) into the WETH contract.
     * @param amount The amount to deposit. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param to The destination address for the WETH.
     * @return The actual amount deposited.
     */
    function depositNative(uint256 amount, address to) external payable returns (uint256) {
        return NATIVE_TOKEN.depositNative(_nativeAmount(amount), to);
    }

    /**
     * @notice Withdraws native tokens (ETH) from the WETH contract.
     * @param amount The amount to withdraw. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param to The destination address for the ETH.
     * @return The actual amount withdrawn.
     */
    function withdrawNative(uint256 amount, address payable to) external returns (uint256) {
        return NATIVE_TOKEN.transferOutNative(to, _localAmount(NATIVE_TOKEN, amount));
    }

    /**
     * @notice Transfers native tokens (ETH) to a destination address.
     * @param amount The amount to transfer. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param to The destination address.
     */
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
