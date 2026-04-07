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
     */
    function approveHash(bytes32 hash, bool permanent) external {
        _sign(msg.sender, hash, permanent, true);
        emit HashSigned(msg.sender, hash);
    }

    /**
     * @notice Revokes a previously approved hash.
     * @param hash The hash to revoke.
     * @param permanent Whether the revocation is for persistent or transient state.
     */
    function revokeHash(bytes32 hash, bool permanent) external {
        _sign(msg.sender, hash, permanent, false);
        emit HashRevoked(msg.sender, hash);
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external view override returns (uint256) {
        return isSigned(userOp.sender, userOpHash) ? VALIDATION_SUCCESS : VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(address, bytes32 hash, bytes calldata) external view override returns (bytes4) {
        return isSigned(msg.sender, hash) ? IERC1271.isValidSignature.selector : EIP_1271_VALIDATION_FAILED;
    }

    function validateSignatureWithData(bytes32 hash, bytes calldata, bytes calldata data) external view override returns (bool) {
        return isSigned(abi.decode(data, (address)), hash);
    }

    /**
     * @notice Checks whether a hash has been approved for a given account.
     * @dev Considers both transient and persistent approval states.
     * @param account The account to check for.
     * @param hash The hash to check.
     * @return True if the hash is approved, false otherwise.
     */
    function isSigned(address account, bytes32 hash) public view returns (bool) {
        return IS_SIGNED.readAddressBytes32BoolMapping(account, hash) || _isSigned[account][hash];
    }

    function _sign(address account, bytes32 hash, bool permanent, bool signed) internal {
        if (permanent) _isSigned[account][hash] = signed;
        else IS_SIGNED.writeAddressBytes32BoolMapping(account, hash, signed);
    }

}
