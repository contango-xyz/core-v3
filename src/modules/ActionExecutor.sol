//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Action, PackedAction } from "../types/Action.sol";

contract ActionExecutor {

    error DelegateCallWithValue();
    error InsufficientBalance();
    error ActionFailed(Action action, bytes reason);

    /**
     * @notice Executes a single action (call or delegatecall).
     * @param action The action struct containing target, value, data, and flags.
     * @return result The return data from the execution.
     */
    function executeSingle(Action memory action) public returns (bytes memory result) {
        bool success;
        if (action.delegateCall) {
            require(action.value == 0, DelegateCallWithValue());
            (success, result) = action.target.delegatecall(action.data);
        } else {
            require(action.value == 0 || address(this).balance >= action.value, InsufficientBalance());
            (success, result) = action.target.call{ value: action.value }(action.data);
        }

        require(success || action.allowFailure, ActionFailed(action, result));
    }

    /**
     * @notice Executes a single packed action (call or delegatecall).
     * @param packedAction The packed action data.
     * @return result The return data from the execution.
     */
    function executeSinglePacked(PackedAction calldata packedAction) public returns (bytes memory result) {
        return executeSingle(packedAction.unpack());
    }

    /**
     * @notice Executes a batch of actions sequentially.
     * @param actions The array of action structs.
     * @return results The array of return data from the executions.
     */
    function executeBatch(Action[] calldata actions) public returns (bytes[] memory results) {
        results = new bytes[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            results[i] = executeSingle(actions[i]);
        }
    }

    /**
     * @notice Executes a batch of packed actions sequentially.
     * @param packedActions The array of packed action data.
     * @return results The array of return data from the executions.
     */
    function executeBatchPacked(PackedAction[] calldata packedActions) public returns (bytes[] memory results) {
        results = new bytes[](packedActions.length);

        for (uint256 i = 0; i < packedActions.length; i++) {
            results[i] = executeSinglePacked(packedActions[i]);
        }
    }

}
