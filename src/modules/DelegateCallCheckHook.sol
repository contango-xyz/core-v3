// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC7579Utils, CallType } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";
import { IERC7579Module } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { ADDRESS_SIZE, WORD_SIZE, SELECTOR_SIZE } from "../constants.sol";
import { IERC7484 } from "../dependencies/IERC7484.sol";
import { ERC7579Hook } from "./base/ERC7579Hook.sol";
import { ERC7579Module } from "./base/ERC7579Module.sol";

/// @title DelegateCallCheckHook
/// @notice Security hook to restrict Smart Account executions to trusted targets.
/// @dev Intercepts executions and validates the target address against an ERC-7484 Registry.
contract DelegateCallCheckHook is ERC7579Hook {

    IERC7484 public immutable REGISTRY;

    uint256 private constant MODE_SIZE = 32; // Mode is defined as bytes32
    // Arrays are have the lenght at the first word, so we need to skip it to get to the actual data pointer (the offset on the calldata).
    uint256 private constant EXEC_DATA_PTR_OFFSET = SELECTOR_SIZE + WORD_SIZE;
    uint256 private constant CALL_HEADER_SIZE = SELECTOR_SIZE + MODE_SIZE;

    /// @notice Tracks if an account allows delegatecalling to itself.
    mapping(address account => bool isSelfDelegationAllowed) public allowSelfDelegate;

    error SelfDelegateCallNotAllowed();

    constructor(IERC7484 registry_) {
        REGISTRY = registry_;
    }

    // ============================= MODULE LIFECYCLE FUNCTIONS ==============================

    function onInstall(bytes calldata data) external virtual override(ERC7579Module, IERC7579Module) {
        if (data.length == 1) allowSelfDelegate[msg.sender] = bytes1(data[0]) != 0;
        emit ModuleInstalled(msg.sender, data);
    }

    function onUninstall(bytes calldata data) external virtual override(ERC7579Module, IERC7579Module) {
        delete allowSelfDelegate[msg.sender];
        emit ModuleUninstalled(msg.sender, data);
    }

    function setSelfDelegationAllowed(bool allowed) external {
        allowSelfDelegate[msg.sender] = allowed;
    }

    // ============================= HOOK IMPLEMENTATION ==============================

    /// @notice Pre-check hook called by the smart account before execution.
    /// @param msgData The full raw calldata of the original execution.
    /// @return bytes Empty bytes, as this hook does not return context data.
    function preCheck(
        address, /* msgSender */
        uint256, /* msgValue */
        bytes calldata msgData
    )
        external
        view
        override
        returns (bytes memory)
    {
        // Extract the CallType from the Mode (first byte after the selector)
        CallType callType = CallType.wrap(bytes1(msgData[SELECTOR_SIZE:SELECTOR_SIZE + 1]));

        if (callType == ERC7579Utils.CALLTYPE_DELEGATECALL) {
            // Highly optimized calldata slicing to find the target address.
            // msgData[36:68] reads the relative pointer to the `executionCalldata`.
            // Adding 36 (CALL_HEADER_SIZE) converts this to an absolute memory offset,
            // skipping the array length slot and landing on the first byte of data.
            uint256 targetOffset = uint256(bytes32(msgData[EXEC_DATA_PTR_OFFSET:EXEC_DATA_PTR_OFFSET + WORD_SIZE])) + CALL_HEADER_SIZE;

            // Extract the 20-byte target address from the calldata payload
            address target = address(bytes20(msgData[targetOffset:targetOffset + ADDRESS_SIZE]));

            // Check for the self-delegation shortcut
            // (Checking msg.sender as well just in case the frontend passes the explicit address instead of 0)
            address msgSender = msg.sender;
            if (target == address(0) || target == msgSender) {
                if (!allowSelfDelegate[msgSender]) revert SelfDelegateCallNotAllowed();
            } else {
                // If it's a standard external target, verify it against the registry
                REGISTRY.checkForAccount(msgSender, target);
            }
        }

        return "";
    }

}
