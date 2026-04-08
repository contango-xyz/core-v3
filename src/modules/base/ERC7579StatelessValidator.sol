//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC7579Validator, MODULE_TYPE_VALIDATOR } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { ERC7579Module } from "./ERC7579Module.sol";
import { MODULE_TYPE_STATELESS_VALIDATOR } from "../../constants.sol";

interface IERC7579StatelessValidator is IERC7579Validator {

    /**
     * Validates a signature with the data (stateless validation)
     *
     * @param hash bytes32 hash of the data
     * @param signature bytes data containing the signatures
     * @param data bytes data containing the data
     *
     * @return bool true if the signature is valid, false otherwise
     */
    function validateSignatureWithData(bytes32 hash, bytes calldata signature, bytes calldata data) external view returns (bool);

}

/// @custom:security-contact security@contango.xyz
abstract contract ERC7579StatelessValidator is ERC7579Module, IERC7579StatelessValidator {

    function isModuleType(uint256 moduleTypeId) external pure virtual override returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_STATELESS_VALIDATOR;
    }

}
