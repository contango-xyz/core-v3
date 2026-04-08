//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {
    MODULE_TYPE_VALIDATOR,
    PackedUserOperation,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { ERC7579StatelessValidator } from "./base/ERC7579StatelessValidator.sol";
import { EIP_1271_VALIDATION_FAILED } from "../constants.sol";
import { TempStorage, TempStorageKey } from "../libraries/TempStorage.sol";

/// @custom:security-contact security@contango.xyz
contract PreSignedValidator is ERC7579StatelessValidator {

    event HashSigned(address indexed account, bytes32 indexed hash);
    event HashRevoked(address indexed account, bytes32 indexed hash);

    TempStorageKey private immutable IS_SIGNED = TempStorage.newKey("PreSignedValidator.isSigned");

    mapping(address account => mapping(bytes32 hash => bool isSigned)) private _isSigned;

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /**
     * @notice Approves a message hash for a given account.
     * @dev If `permanent` is set to true, the approval is stored in persistent state.
     * If `permanent` is set to false, it's stored in transient storage for the current transaction.
     * @param hash The hash to approve.
     * @param permanent Whether to store the approval permanently.
     * @return changed True if the signed state changed, false if it was already approved.
     */
    function approveHash(bytes32 hash, bool permanent) external returns (bool changed) {
        changed = _sign(msg.sender, hash, permanent, true);
        if (!changed) return false;
        emit HashSigned(msg.sender, hash);
        return true;
    }

    /**
     * @notice Revokes a previously approved hash.
     * @param hash The hash to revoke.
     * @param permanent Whether the revocation is for persistent or transient state.
     * @return changed True if the signed state changed, false if it was already revoked.
     */
    function revokeHash(bytes32 hash, bool permanent) external returns (bool changed) {
        changed = _sign(msg.sender, hash, permanent, false);
        if (!changed) return false;
        emit HashRevoked(msg.sender, hash);
        return true;
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external view override returns (uint256) {
        return _isHashSigned(userOp.sender, userOpHash) ? VALIDATION_SUCCESS : VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(address, bytes32 hash, bytes calldata) external view override returns (bytes4) {
        return _isHashSigned(msg.sender, hash) ? IERC1271.isValidSignature.selector : EIP_1271_VALIDATION_FAILED;
    }

    function validateSignatureWithData(bytes32 hash, bytes calldata, bytes calldata data) external view override returns (bool) {
        return _isHashSigned(abi.decode(data, (address)), hash);
    }

    /**
     * @notice Checks whether a hash has been approved for a given account.
     * @dev Considers both transient and persistent approval states.
     * @param account The account to check for.
     * @param hash The hash to check.
     * @return True if the hash is approved, false otherwise.
     */
    function isSigned(address account, bytes32 hash) external view returns (bool) {
        return _isHashSigned(account, hash);
    }

    function _isHashSigned(address account, bytes32 hash) private view returns (bool) {
        return IS_SIGNED.readAddressBytes32BoolMapping(account, hash) || _isSigned[account][hash];
    }

    /**
     * @notice Computes the pre-signed hash for an operation.
     * @param hash The operation hash to sign.
     * @param account The account authorizing the hash.
     * @return The digest used for signature validation.
     */
    function _sign(address account, bytes32 hash, bool permanent, bool signed) private returns (bool changed) {
        if (_isHashSigned(account, hash) == signed) return false;

        if (permanent) _isSigned[account][hash] = signed;
        else IS_SIGNED.writeAddressBytes32BoolMapping(account, hash, signed);
        return true;
    }

}
