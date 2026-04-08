//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IWETH9 } from "../dependencies/IWETH9.sol";
import { IPermit2, ISignatureTransfer } from "../dependencies/permit2/IPermit2.sol";

/**
 * @notice Represents a compact EIP-2098 signature for ERC20 permits.
 * @dev See `PermitUtils.t.sol` for generation examples.
 * @param amount The amount permitted or transferred.
 * @param deadline The expiration timestamp of the signature.
 * @param r The first 32 bytes of the signature.
 * @param vs The combined `v` and `s` values of the signature.
 * @param version The permit version: 1 for standard ERC-2612, 2 for Permit2 signature transfer.
 */
struct EIP2098Permit {
    uint256 amount;
    uint256 deadline;
    bytes32 r;
    bytes32 vs;
    uint256 version;
}

library ERC20Lib {

    using Address for address payable;
    using SafeERC20 for *;
    using SafeCast for *;

    IPermit2 private constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    error ZeroPayer();
    error ZeroDestination();
    error InvalidPermitVersion(uint256 version);
    error InsufficientNativeBalance(uint256 balance, uint256 amount);
    error InsufficientBalance(IERC20 token, uint256 balance, uint256 amount);

    event NativeTokenDeposited(uint256 amount, address to);
    event NativeTokenWithdrawn(uint256 amount, address to);

    function _validPayer(address payer) internal pure {
        if (payer == address(0)) revert ZeroPayer();
    }

    function _validDestination(address to) internal pure {
        if (to == address(0)) revert ZeroDestination();
    }

    function _validAmount(uint256 amount) internal pure returns (bool) {
        return amount > 0;
    }

    /**
     * @notice Deposits native token (ETH) into WETH and transfers it to the destination.
     * @dev Reuses the same transfer input validation as ERC20 transfers, with `msg.sender` as payer.
     * @param token The WETH contract.
     * @param amount The amount of native token to deposit.
     * @param to The destination address.
     * @return amountTransferred The amount of tokens deposited and transferred.
     */
    function depositNative(IWETH9 token, uint256 amount, address to) internal returns (uint256 amountTransferred) {
        if (_validateTransferOutInputs(msg.sender, to, amount)) return 0;
        uint256 balance = address(this).balance;
        require(balance >= amount, InsufficientNativeBalance(balance, amount));

        token.deposit{ value: amount }();
        _transferOut(token, address(this), to, amount);
        amountTransferred = amount;

        emit NativeTokenDeposited(amount, to);
    }

    /**
     * @notice Withdraws native token (ETH) from WETH and transfers it to the destination.
     * @dev Reuses the same transfer input validation as ERC20 transfers, with `msg.sender` as payer.
     * @param token The WETH contract.
     * @param to The destination address.
     * @param amount The amount of native token to withdraw.
     * @return amountTransferred The amount of tokens withdrawn and transferred.
     */
    function transferOutNative(IWETH9 token, address payable to, uint256 amount) internal returns (uint256 amountTransferred) {
        if (_validateTransferOutInputs(msg.sender, to, amount)) return 0;
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, InsufficientBalance(token, balance, amount));

        token.withdraw(amount);
        to.sendValue(amount);
        amountTransferred = amount;

        emit NativeTokenWithdrawn(amount, to);
    }

    /**
     * @notice Transfers tokens from a payer to a destination.
     * @dev Handles both `transfer` (if payer is this contract) and `transferFrom`.
     * @param token The ERC20 token to transfer.
     * @param payer The address to transfer tokens from.
     * @param to The destination address.
     * @param amount The amount of tokens to transfer.
     * @return amountTransferred The amount of tokens transferred.
     */
    function transferOut(IERC20 token, address payer, address to, uint256 amount) internal returns (uint256 amountTransferred) {
        (bool shouldReturn, uint256 validatedAmount) = _validateTransferOut(payer, to, amount);
        if (shouldReturn) return validatedAmount;
        return _transferOut(token, payer, to, amount);
    }

    /**
     * @notice Transfers token funds out to a recipient.
     * @param token The token to transfer.
     * @param to The transfer recipient.
     * @param amount The amount to transfer.
     */
    function _transferOut(IERC20 token, address payer, address to, uint256 amount) internal returns (uint256 amountTransferred) {
        payer == address(this) ? token.safeTransfer(to, amount) : token.safeTransferFrom(payer, to, amount);
        return amount;
    }

    /**
     * @notice Validates transfer inputs shared by all transfer-out entry points.
     * @dev Returns true when `amount == 0` so callers can preserve no-op semantics.
     */
    function _validateTransferOutInputs(address payer, address to, uint256 amount) private pure returns (bool shouldReturnZero) {
        if (!_validAmount(amount)) return true;
        _validPayer(payer);
        _validDestination(to);
        return false;
    }

    /**
     * @notice Validates transfer-out inputs and same-address no-op behavior.
     * @dev Builds on `_validateTransferOutInputs` and applies `payer == to` short-circuit used by ERC20 transfer paths.
     */
    function _validateTransferOut(address payer, address to, uint256 amount)
        private
        pure
        returns (bool shouldReturn, uint256 amountTransferred)
    {
        if (_validateTransferOutInputs(payer, to, amount)) return (true, 0);
        if (payer == to) return (true, amount);
        return (false, 0);
    }

    /**
     * @notice Returns the balance of the current contract for a given token.
     * @param token The ERC20 token.
     * @return The current contract's balance.
     */
    function myBalance(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Approves a spender to spend a specific amount of tokens.
     * @dev Uses `forceApprove` to handle tokens that require zeroing approval first (like USDT).
     * @param token The ERC20 token.
     * @param spender The address to approve.
     * @param amount The amount to approve.
     * @return The approved amount.
     */
    function forceApprove(IERC20 token, address spender, uint256 amount) internal returns (uint256) {
        token.forceApprove(spender, amount);
        return amount;
    }

    /**
     * @notice Applies a standard ERC-2612 permit to a token.
     * @dev Decompresses the EIP-2098 signature into V, R, S.
     * @param token The ERC20 token to call `permit` on.
     * @param permit The EIP-2098 permit data.
     * @param owner The owner of the tokens.
     * @param spender The address to be granted allowance.
     */
    function applyPermit(IERC20 token, EIP2098Permit memory permit, address owner, address spender) private {
        // Inspired by https://github.com/Uniswap/permit2/blob/main/src/libraries/SignatureVerification.sol
        IERC20Permit(address(token))
            .permit({
                owner: owner,
                spender: spender,
                value: permit.amount,
                deadline: permit.deadline,
                v: uint8(uint256(permit.vs >> 255)) + 27,
                r: permit.r,
                s: permit.vs & bytes32(uint256(type(int256).max))
            });
    }

    /**
     * @notice Pulls funds using the Permit2 `permitTransferFrom` function.
     * @dev Requires the owner to have approved Permit2.
     * @param token The ERC20 token to transfer.
     * @param permit The EIP-2098 permit data (version 2).
     * @param amount The amount to pull.
     * @param owner The owner of the tokens.
     * @param to The destination address.
     * @return The actual amount pulled.
     */
    function pullFunds(IERC20 token, EIP2098Permit memory permit, uint256 amount, address owner, address to) private returns (uint256) {
        PERMIT2.permitTransferFrom({
            permit: ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: token, amount: permit.amount }),
                nonce: uint256(keccak256(abi.encode(owner, token, permit.amount, permit.deadline))),
                deadline: permit.deadline
            }),
            transferDetails: ISignatureTransfer.SignatureTransferDetails({ to: to, requestedAmount: amount }),
            owner: owner,
            signature: abi.encodePacked(permit.r, permit.vs)
        });
        return amount;
    }

    /**
     * @notice Transfers tokens from a payer to a destination using an EIP-2098 permit.
     * @dev Supports both standard ERC20 Permit (v1) and Permit2 (v2).
     * @param token The ERC20 token to transfer.
     * @param from The address to transfer tokens from.
     * @param to The destination address.
     * @param amount The amount of tokens to transfer.
     * @param permit The EIP-2098 permit data.
     * @return amountTransferred The amount of tokens transferred.
     */
    function transferOut(IERC20 token, address from, address to, uint256 amount, EIP2098Permit memory permit)
        internal
        returns (uint256 amountTransferred)
    {
        (bool shouldReturn, uint256 validatedAmount) = _validateTransferOut(from, to, amount);
        if (shouldReturn) return validatedAmount;
        if (permit.version == 1) {
            applyPermit(token, permit, from, address(this));
            amountTransferred = transferOut(token, from, to, amount);
        } else if (permit.version == 2) {
            amountTransferred = pullFunds(token, permit, amount, from, to);
        } else {
            revert InvalidPermitVersion(permit.version);
        }
    }

    /**
     * @notice Transfers tokens from a payer to a destination, optionally using Permit2.
     * @dev Reuses shared transfer input validation before branching. When `usePermit2` is true, it uses Permit2 `transferFrom`.
     * @param token The ERC20 token to transfer.
     * @param from The address to transfer tokens from.
     * @param to The destination address.
     * @param amount The amount of tokens to transfer.
     * @param usePermit2 Whether to use Permit2 for the transfer.
     * @return amountTransferred The amount of tokens transferred.
     */
    function transferOut(IERC20 token, address from, address to, uint256 amount, bool usePermit2)
        internal
        returns (uint256 amountTransferred)
    {
        (bool shouldReturn, uint256 validatedAmount) = _validateTransferOut(from, to, amount);
        if (shouldReturn) return validatedAmount;
        if (usePermit2) {
            PERMIT2.transferFrom({ from: from, to: to, amount: amount.toUint160(), token: token });
            amountTransferred = amount;
        } else {
            amountTransferred = transferOut(token, from, to, amount);
        }
    }

    /**
     * @notice Returns the number of decimals for a given token.
     * @param token The ERC20 token.
     * @return The number of decimals.
     */
    function decimals(IERC20 token) internal view returns (uint8) {
        return IERC20Metadata(address(token)).decimals();
    }

    /**
     * @notice Returns one unit of a given token (10^decimals).
     * @param token The ERC20 token.
     * @return One unit of the token.
     */
    function unit(IERC20 token) internal view returns (uint256) {
        return 10 ** decimals(token);
    }

}
