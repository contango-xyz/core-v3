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

contract MultiValidator is ERC7579StatelessValidator {

    uint256 public constant MAX_INTENTS = 10;

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external view override returns (uint256) {
        return _validate(userOp.sender, userOpHash, userOp.signature) ? VALIDATION_SUCCESS : VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(address, bytes32 hash, bytes calldata signature) external view returns (bytes4 result) {
        return _validate(msg.sender, hash, signature) ? IERC1271.isValidSignature.selector : EIP_1271_VALIDATION_FAILED;
    }

    function validateSignatureWithData(bytes32 hash, bytes calldata signature, bytes calldata) external view override returns (bool) { }

    function _validate(address account, bytes32 hash, bytes calldata signature) internal view returns (bool) {
        MultiSignature memory multiSignature = abi.decode(signature, (MultiSignature));

        uint256 length = multiSignature.intents.length;
        if (length == 0 || length > MAX_INTENTS) return false;

        bytes32 metaHash = keccak256(abi.encode(multiSignature.intents));

        bytes32 _result = IERC1271(account).isValidSignature(metaHash, multiSignature.signature);
        if (_result != IERC1271.isValidSignature.selector) return false;

        for (uint256 i = 0; i < multiSignature.intents.length; i++) {
            if (multiSignature.intents[i] == hash) return true;
        }

        return false;
    }

}
