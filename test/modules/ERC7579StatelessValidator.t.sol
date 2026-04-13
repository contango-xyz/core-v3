//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { MODULE_TYPE_VALIDATOR, PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import { ERC7579StatelessValidator } from "../../src/modules/base/ERC7579StatelessValidator.sol";
import { MODULE_TYPE_STATELESS_VALIDATOR, EIP_1271_VALIDATION_FAILED } from "../../src/constants.sol";

contract ERC7579StatelessValidatorTest is Test {

    MockStatelessValidator internal validator;

    function setUp() public {
        validator = new MockStatelessValidator();
    }

    function test_ModuleType_ReturnsTrueForValidatorType() public view {
        assertTrue(validator.isModuleType(MODULE_TYPE_VALIDATOR));
    }

    function test_ModuleType_ReturnsTrueForStatelessValidatorType() public view {
        assertTrue(validator.isModuleType(MODULE_TYPE_STATELESS_VALIDATOR));
    }

    function test_ModuleType_ReturnsFalseForUnsupportedType() public view {
        assertFalse(validator.isModuleType(type(uint256).max));
    }

}

contract MockStatelessValidator is ERC7579StatelessValidator {

    function validateUserOp(PackedUserOperation calldata, bytes32) external pure override returns (uint256) {
        return 0;
    }

    function isValidSignatureWithSender(address, bytes32, bytes calldata) external pure override returns (bytes4) {
        return EIP_1271_VALIDATION_FAILED;
    }

    function validateSignatureWithData(bytes32, bytes calldata, bytes calldata) external pure override returns (bool) {
        return false;
    }

}
