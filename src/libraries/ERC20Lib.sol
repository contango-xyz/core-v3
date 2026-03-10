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

    function depositNative(IWETH9 token, uint256 amount, address to) internal returns (uint256 amountTransferred) {
        _validAmount(amount);
        _validDestination(to);
        uint256 balance = address(this).balance;
        require(balance >= amount, InsufficientNativeBalance(balance, amount));

        token.deposit{ value: amount }();
        _transferOut(token, address(this), to, amount);
        amountTransferred = amount;

        emit NativeTokenDeposited(amount, to);
    }

    function transferOutNative(IWETH9 token, address payable to, uint256 amount) internal returns (uint256 amountTransferred) {
        _validAmount(amount);
        _validDestination(to);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, InsufficientBalance(token, balance, amount));

        token.withdraw(amount);
        to.sendValue(amount);
        amountTransferred = amount;

        emit NativeTokenWithdrawn(amount, to);
    }

    function transferOut(IERC20 token, address payer, address to, uint256 amount) internal returns (uint256 amountTransferred) {
        if (!_validAmount(amount)) return 0;
        _validPayer(payer);
        _validDestination(to);
        if (payer == to) return amount;
        return _transferOut(token, payer, to, amount);
    }

    function _transferOut(IERC20 token, address payer, address to, uint256 amount) internal returns (uint256 amountTransferred) {
        payer == address(this) ? token.safeTransfer(to, amount) : token.safeTransferFrom(payer, to, amount);
        return amount;
    }

    function myBalance(IERC20 token) internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function forceApprove(IERC20 token, address spender, uint256 amount) internal returns (uint256) {
        token.forceApprove(spender, amount);
        return amount;
    }

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

    function transferOut(IERC20 token, address from, address to, uint256 amount, EIP2098Permit memory permit)
        internal
        returns (uint256 amountTransferred)
    {
        if (!_validAmount(amount)) return 0;
        _validPayer(from);
        _validDestination(to);
        if (from == to) return amount;
        if (permit.version == 1) {
            applyPermit(token, permit, from, address(this));
            amountTransferred = transferOut(token, from, to, amount);
        } else if (permit.version == 2) {
            amountTransferred = pullFunds(token, permit, amount, from, to);
        } else {
            revert InvalidPermitVersion(permit.version);
        }
    }

    function transferOut(IERC20 token, address from, address to, uint256 amount, bool usePermit2)
        internal
        returns (uint256 amountTransferred)
    {
        if (usePermit2) {
            PERMIT2.transferFrom({ from: from, to: to, amount: amount.toUint160(), token: token });
            amountTransferred = amount;
        } else {
            amountTransferred = transferOut(token, from, to, amount);
        }
    }

    function decimals(IERC20 token) internal view returns (uint8) {
        return IERC20Metadata(address(token)).decimals();
    }

    function unit(IERC20 token) internal view returns (uint256) {
        return 10 ** decimals(token);
    }

}
