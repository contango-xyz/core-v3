// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import { Vm } from "forge-std/Vm.sol";

import { IPermit2, IAllowanceTransfer, ISignatureTransfer } from "../src/dependencies/permit2/IPermit2.sol";
import { PermitHash } from "./dependencies/PermitHash.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { EIP2098Permit } from "../src/libraries/ERC20Lib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract PermitUtils {

    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline));
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }

}

abstract contract PermitSigner {

    using PermitHash for *;
    using SafeCast for uint256;

    IPermit2 internal constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function signPermit(IERC20 _token, address owner, uint256 ownerPk, uint256 value, address spender)
        internal
        returns (EIP2098Permit memory signedPermit)
    {
        IERC20Permit permitToken = IERC20Permit(address(_token));

        PermitUtils.Permit memory permit = PermitUtils.Permit({
            owner: owner, spender: spender, value: value, nonce: permitToken.nonces(owner), deadline: type(uint32).max
        });

        PermitUtils sigUtils = new PermitUtils(permitToken.DOMAIN_SEPARATOR());
        (signedPermit.r, signedPermit.vs) = vm.signCompact(ownerPk, sigUtils.getTypedDataHash(permit));

        signedPermit.amount = value;
        signedPermit.deadline = permit.deadline;
        signedPermit.version = 1;
    }

    function encodePermitApplication(IERC20 token, EIP2098Permit memory permit, address owner, address spender)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IERC20Permit(address(token)).permit,
            (
                owner,
                spender,
                permit.amount,
                permit.deadline,
                uint8(uint256(permit.vs >> 255)) + 27,
                permit.r,
                permit.vs & bytes32(uint256(type(int256).max))
            )
        );
    }

    function signPermit2SignatureTransfer(IERC20 _token, address owner, uint256 ownerPk, uint256 amount, address spender)
        public
        view
        virtual
        returns (EIP2098Permit memory signedPermit)
    {
        signedPermit.deadline = type(uint32).max;
        signedPermit.amount = amount;

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: _token, amount: signedPermit.amount }),
            nonce: uint256(keccak256(abi.encode(owner, _token, signedPermit.amount, signedPermit.deadline))),
            deadline: signedPermit.deadline
        });

        (signedPermit.r, signedPermit.vs) = vm.signCompact(ownerPk, _permit2HashTypedData(permit.hash(spender)));
        signedPermit.version = 2;
    }

    function signPermit2PermitSingle(IERC20 _token, address owner, uint256 ownerPk, uint256 amount, address spender)
        public
        view
        returns (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature)
    {
        permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: _token,
                amount: amount.toUint160(),
                expiration: type(uint48).max,
                nonce: permit2.allowance(owner, _token, spender).nonce
            }),
            spender: spender,
            sigDeadline: type(uint48).max
        });

        (bytes32 r, bytes32 vs) = vm.signCompact(ownerPk, _permit2HashTypedData(permitSingle.hash()));
        signature = abi.encodePacked(r, vs);
    }

    function _permit2HashTypedData(bytes32 dataHash) private view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), dataHash));
    }

}
