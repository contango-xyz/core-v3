//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC7579Execution, Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import { ActionExecutor } from "./ActionExecutor.sol";
import { UnorderedNonce } from "./UnorderedNonce.sol";
import { ERC7579Executor } from "./base/ERC7579Executor.sol";
import { ERC7579Lib } from "./base/ERC7579Utils.sol";
import { ActionResult, PackedAction } from "../types/Action.sol";

contract ERC1271Executor is EIP712, ERC7579Executor, UnorderedNonce {

    using Address for *;
    using ERC7579Lib for *;

    error InvalidSignature();

    bytes32 public constant EXECUTION_TYPEHASH = keccak256("Execution(address account,bytes accountData,uint256 nonce)");

    constructor(ActionExecutor _actionExecutor) ERC7579Executor(_actionExecutor) EIP712("ERC1271Executor", "1") { }

    // ============================= EXECUTION FUNCTIONS =============================

    /**
     * @notice Executes a single call on behalf of an account using a signature.
     * @dev See `ERC1271Executor.t.sol` for examples.
     * @param account The account to execute the call from.
     * @param target The target address of the call.
     * @param data The calldata to be executed.
     * @param signature The ERC-1271 signature for validation.
     * @param nonce The unordered nonce for replay protection.
     * @return returnData The execution result.
     * @custom:example `execute(account, token, abi.encodeCall(IERC20.transfer, (...)), signature, nonce)`
     */
    function execute(IERC7579Execution account, address target, bytes calldata data, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes memory returnData)
    {
        bytes memory callData = target.encodeSingle(msg.value, data);
        _validateSignature(account, callData, signature, nonce);
        return _execute(account, callData);
    }

    /**
     * @notice Executes a single delegatecall on behalf of an account using a signature.
     * @dev See `ERC1271Executor.t.sol` for examples.
     * @param account The account to execute the delegatecall from.
     * @param target The target address of the delegatecall.
     * @param data The calldata to be executed.
     * @param signature The ERC-1271 signature for validation.
     * @param nonce The unordered nonce for replay protection.
     * @return returnData The return data from the execution.
     * @custom:example `delegate(account, lib, abi.encodeCall(Lib.foo, (...)), signature, nonce)`
     */
    function delegate(IERC7579Execution account, address target, bytes calldata data, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes memory returnData)
    {
        bytes memory callData = target.encodeDelegate(data);
        _validateSignature(account, callData, signature, nonce);
        return _delegate(account, callData);
    }

    /**
     * @notice Executes a batch of calls on behalf of an account using a signature.
     * @param account The account to execute the calls from.
     * @param calls The array of executions to perform.
     * @param signature The ERC-1271 signature for validation.
     * @param nonce The unordered nonce for replay protection.
     * @return returnData The array of return data from the executions.
     */
    function executeBatch(IERC7579Execution account, Execution[] calldata calls, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes[] memory returnData)
    {
        bytes memory callData = calls.encodeBatch();
        _validateSignature(account, callData, signature, nonce);
        return _executeBatch(account, callData);
    }

    // ============================= ACTION EXECUTION FUNCTIONS =============================

    /**
     * @notice Executes a single packed action on behalf of an account using a signature.
     * @param account The account to execute the action from.
     * @param action The packed action data.
     * @param signature The ERC-1271 signature for validation.
     * @param nonce The unordered nonce for replay protection.
     * @return returnData The return data from the execution.
     */
    function executeAction(IERC7579Execution account, PackedAction calldata action, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (ActionResult memory returnData)
    {
        _validateSignature(account, action.data, signature, nonce);
        return _executeAction(account, action);
    }

    /**
     * @notice Executes a batch of packed actions on behalf of an account using a signature.
     * @param account The account to execute the actions from.
     * @param actions The array of packed action data.
     * @param signature The ERC-1271 signature for validation.
     * @param nonce The unordered nonce for replay protection.
     * @return returnData The array of execution results from the actions.
     */
    function executeActions(IERC7579Execution account, PackedAction[] calldata actions, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (ActionResult[] memory returnData)
    {
        _validateSignature(account, abi.encode(actions), signature, nonce);
        return _executeActions(account, actions);
    }

    // ============================= HELPER FUNCTIONS =============================

    /**
     * @notice Calculates the EIP-712 digest for an execution.
     * @param account The account that will execute the call.
     * @param accountData The encoded call data.
     * @param nonce The unordered nonce.
     * @return The 32-byte EIP-712 digest.
     */
    function digest(IERC7579Execution account, bytes memory accountData, uint256 nonce) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(EXECUTION_TYPEHASH, account, keccak256(accountData), nonce)));
    }

    /**
     * @notice Validates an ERC-1271 signature for a given account and execution data.
     * @dev Also spends the unordered nonce to prevent replay attacks.
     * @param account The account to validate for.
     * @param accountData The encoded call data.
     * @param signature The signature to validate.
     * @param nonce The unordered nonce.
     */
    function _validateSignature(IERC7579Execution account, bytes memory accountData, bytes calldata signature, uint256 nonce) internal {
        _useUnorderedNonce(address(account), nonce);

        bytes32 _digest = digest(account, accountData, nonce);

        require(IERC1271(address(account)).isValidSignature(_digest, signature) == IERC1271.isValidSignature.selector, InvalidSignature());
    }

}
