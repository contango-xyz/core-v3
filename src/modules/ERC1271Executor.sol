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
import { PackedAction } from "../types/Action.sol";

contract ERC1271Executor is EIP712, ERC7579Executor, UnorderedNonce {

    using Address for *;
    using ERC7579Lib for *;

    error InvalidSignature();

    bytes32 public constant EXECUTION_TYPEHASH = keccak256("Execution(address account,bytes accountData,uint256 nonce)");

    constructor(ActionExecutor _actionExecutor) ERC7579Executor(_actionExecutor) EIP712("ERC1271Executor", "1") { }

    // ============================= EXECUTION FUNCTIONS =============================

    function execute(IERC7579Execution account, address target, bytes calldata data, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes memory returnData)
    {
        bytes memory callData = target.encodeSingle(msg.value, data);
        _validateSignature(account, callData, signature, nonce);
        return _execute(account, callData);
    }

    function delegate(IERC7579Execution account, address target, bytes calldata data, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes memory returnData)
    {
        bytes memory callData = target.encodeDelegate(data);
        _validateSignature(account, callData, signature, nonce);
        return _delegate(account, callData);
    }

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

    function executeAction(IERC7579Execution account, PackedAction calldata action, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes memory returnData)
    {
        _validateSignature(account, action.data, signature, nonce);
        return _executeAction(account, action);
    }

    function executeActions(IERC7579Execution account, PackedAction[] calldata actions, bytes calldata signature, uint256 nonce)
        external
        payable
        returns (bytes[] memory returnData)
    {
        _validateSignature(account, abi.encode(actions), signature, nonce);
        return _executeActions(account, actions);
    }

    // ============================= HELPER FUNCTIONS =============================

    function digest(IERC7579Execution account, bytes memory accountData, uint256 nonce) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(EXECUTION_TYPEHASH, account, keccak256(accountData), nonce)));
    }

    function _validateSignature(IERC7579Execution account, bytes memory accountData, bytes calldata signature, uint256 nonce) internal {
        _useUnorderedNonce(address(account), nonce);

        bytes32 _digest = digest(account, accountData, nonce);

        require(IERC1271(address(account)).isValidSignature(_digest, signature) == IERC1271.isValidSignature.selector, InvalidSignature());
    }

}
