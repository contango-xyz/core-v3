//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { MODULE_TYPE_EXECUTOR, Execution, IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { ERC7579Utils, ModeSelector, ModePayload, Mode, CallType } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ActionExecutor } from "../ActionExecutor.sol";
import { ERC7579Module } from "./ERC7579Module.sol";
import { ERC7579Lib } from "./ERC7579Utils.sol";
import { PackedAction } from "../../types/Action.sol";

abstract contract ERC7579Executor is ERC7579Module {

    using Address for *;
    using ERC7579Lib for *;

    event ExecutionStarted(IERC7579Execution indexed account, bytes32 mode);
    event ExecutionFinished(IERC7579Execution indexed account, bytes32 mode);

    ActionExecutor public immutable ACTION_EXECUTOR;

    constructor(ActionExecutor _actionExecutor) {
        ACTION_EXECUTOR = _actionExecutor;
    }

    function actionExecutor() external view returns (ActionExecutor) {
        return ACTION_EXECUTOR;
    }

    function isModuleType(uint256 moduleTypeId) public pure virtual override returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    function _execute(IERC7579Execution account, address target, bytes memory data) internal returns (bytes memory returnData) {
        return _execute(account, target.encodeSingle(msg.value, data));
    }

    function _execute(IERC7579Execution account, bytes memory data) internal returns (bytes memory returnData) {
        _forwardValue(address(account));
        return _executeFromExecutor(account, _call(), data)[0];
    }

    function _delegate(IERC7579Execution account, address target, bytes memory data) internal returns (bytes memory returnData) {
        return _delegate(account, target.encodeDelegate(data));
    }

    function _delegate(IERC7579Execution account, bytes memory data) internal returns (bytes memory returnData) {
        _forwardValue(address(account));
        return _executeFromExecutor(account, _delegate(), data)[0];
    }

    function _executeBatch(IERC7579Execution account, Execution[] calldata calls) internal returns (bytes[] memory returnData) {
        return _executeBatch(account, calls.encodeBatch());
    }

    function _executeBatch(IERC7579Execution account, bytes memory data) internal returns (bytes[] memory returnData) {
        _forwardValue(address(account));
        return _executeFromExecutor(account, _batch(), data);
    }

    function _executeAction(IERC7579Execution account, PackedAction memory packedAction) internal returns (bytes memory returnData) {
        return _delegate(account, abi.encodePacked(ACTION_EXECUTOR, abi.encodeCall(ActionExecutor.executeSinglePacked, packedAction)));
    }

    function _executeActions(IERC7579Execution account, PackedAction[] memory packedActions) internal returns (bytes[] memory returnData) {
        return abi.decode(
            _delegate(account, abi.encodePacked(ACTION_EXECUTOR, abi.encodeCall(ActionExecutor.executeBatchPacked, packedActions))),
            (bytes[])
        );
    }

    function _encodeDefaultMode(CallType callType) internal pure returns (bytes32) {
        return
            Mode.unwrap(ERC7579Utils.encodeMode(callType, ERC7579Utils.EXECTYPE_DEFAULT, ModeSelector.wrap(0x00), ModePayload.wrap(0x00)));
    }

    function _call() internal pure returns (bytes32) {
        return _encodeDefaultMode(ERC7579Utils.CALLTYPE_SINGLE);
    }

    function _delegate() internal pure returns (bytes32) {
        return _encodeDefaultMode(ERC7579Utils.CALLTYPE_DELEGATECALL);
    }

    function _batch() internal pure returns (bytes32) {
        return _encodeDefaultMode(ERC7579Utils.CALLTYPE_BATCH);
    }

    // At the very least Safe7579 has non-payable executeFromExecutor, so we need to send the value manually
    function _forwardValue(address account) internal {
        if (msg.value > 0) payable(account).sendValue(msg.value);
    }

    function _executeFromExecutor(IERC7579Execution account, bytes32 mode, bytes memory data) internal returns (bytes[] memory returnData) {
        emit ExecutionStarted(account, mode);
        returnData = account.executeFromExecutor(mode, data);
        emit ExecutionFinished(account, mode);
    }

}
