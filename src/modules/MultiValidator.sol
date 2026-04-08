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

struct MultiSignature {
    bytes32[] intents;
    bytes signature;
}

/// @custom:security-contact security@contango.xyz
contract MultiValidator is ERC7579StatelessValidator {

    uint256 public constant MAX_INTENTS = 10;

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /**
     * @notice Validates a user operation using a multi-intent signature.
     * @dev Decodes `userOp.signature` as `MultiSignature` and checks if the `userOpHash` is among the approved intents.
     * @param userOp The ERC-4337 user operation.
     * @param userOpHash The hash of the user operation.
     * @return VALIDATION_SUCCESS if the signature is valid and the intent is included, VALIDATION_FAILED otherwise.
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external view override returns (uint256) {
        return _validate(userOp.sender, userOpHash, userOp.signature) ? VALIDATION_SUCCESS : VALIDATION_FAILED;
    }

    /**
     * @notice Validates a message hash for ERC-1271 using a multi-intent signature.
     * @param hash The hash of the data to be signed.
     * @param signature The multi-intent signature.
     * @return result The ERC-1271 magic value if valid, or a failure selector.
     */
    function isValidSignatureWithSender(address, bytes32 hash, bytes calldata signature) external view returns (bytes4 result) {
        return _validate(msg.sender, hash, signature) ? IERC1271.isValidSignature.selector : EIP_1271_VALIDATION_FAILED;
    }

    function validateSignatureWithData(bytes32 hash, bytes calldata signature, bytes calldata data) external view override returns (bool) {
        return _validate(abi.decode(data, (address)), hash, signature);
    }

    /**
     * @notice Internal validation logic for multi-intent signatures.
     * @dev Validates that the account signature matches the root hash of the intents,
     * and that the target hash is one of the intents.
     * @param account The account to validate for.
     * @param hash The specific intent hash to verify.
     * @param signature The `MultiSignature` encoded signature.
     * @return True if valid, false otherwise.
     */
    function _validate(address account, bytes32 hash, bytes calldata signature) internal view returns (bool) {
        MultiSignature memory multiSignature = abi.decode(signature, (MultiSignature));

        uint256 length = multiSignature.intents.length;
        if (length == 0 || length > MAX_INTENTS) return false;

        bytes32 metaHash = keccak256(abi.encode(multiSignature.intents));

        bytes32 _result = IERC1271(account).isValidSignature(metaHash, multiSignature.signature);
        if (_result != IERC1271.isValidSignature.selector) return false;

        for (uint256 i = 0; i < length; i++) {
            if (multiSignature.intents[i] == hash) return true;
        }

        return false;
    }

}
