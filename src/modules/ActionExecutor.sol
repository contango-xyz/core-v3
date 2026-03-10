//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC7484 } from "../dependencies/IERC7484.sol";
import { Action, PackedAction } from "../types/Action.sol";

contract ActionExecutor {

    error DelegateCallWithValue();
    error InsufficientBalance();
    error ActionFailed(Action action, bytes reason);

    IERC7484 public immutable REGISTRY;

    constructor(IERC7484 _registry) {
        REGISTRY = _registry;
    }

    function registry() external view returns (IERC7484) {
        return REGISTRY;
    }

    function executeSingle(Action memory action) public returns (bytes memory result) {
        bool success;
        if (action.delegateCall) {
            require(action.value == 0, DelegateCallWithValue());
            REGISTRY.check(action.target);

            (success, result) = action.target.delegatecall(action.data);
        } else {
            require(action.value == 0 || address(this).balance >= action.value, InsufficientBalance());
            (success, result) = action.target.call{ value: action.value }(action.data);
        }

        require(success || action.allowFailure, ActionFailed(action, result));
    }

    function executeSinglePacked(PackedAction calldata packedAction) public returns (bytes memory result) {
        return executeSingle(packedAction.unpack());
    }

    function executeBatch(Action[] calldata actions) public returns (bytes[] memory results) {
        results = new bytes[](actions.length);

        for (uint256 i = 0; i < actions.length; i++) {
            results[i] = executeSingle(actions[i]);
        }
    }

    function executeBatchPacked(PackedAction[] calldata packedActions) public returns (bytes[] memory results) {
        results = new bytes[](packedActions.length);

        for (uint256 i = 0; i < packedActions.length; i++) {
            results[i] = executeSinglePacked(packedActions[i]);
        }
    }

}
