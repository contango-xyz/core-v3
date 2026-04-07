//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC7579Execution, Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC7579Utils } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";

import { ERC7579Executor } from "./base/ERC7579Executor.sol";
import { ActionExecutor } from "./ActionExecutor.sol";
import { PackedAction } from "../types/Action.sol";

interface OwnableExecutorEvents {

    event OwnerAdded(IERC7579Execution account, address owner);
    event OwnerRemoved(IERC7579Execution account, address owner);

}

contract OwnableExecutor is ERC7579Executor, OwnableExecutorEvents {

    using EnumerableSet for EnumerableSet.AddressSet;
    using ERC7579Utils for *;

    uint256 private constant ADDR_SIZE = 20;

    error Unauthorized(IERC7579Execution account, address sender);
    error InvalidDataLength();
    error AtLeastOneOwner();
    error CannotRemoveLastOwner();
    error AlreadyInstalled();
    error NotInstalled();

    mapping(IERC7579Execution account => EnumerableSet.AddressSet owners) internal accountOwners;

    constructor(ActionExecutor _actionExecutor) ERC7579Executor(_actionExecutor) { }

    // ============================= ADMIN FUNCTIONS =============================

    modifier onlyOwner(IERC7579Execution account) {
        _onlyOwner(account);
        _;
    }

    function _onlyOwner(IERC7579Execution account) internal view {
        require(isOwner(account, msg.sender), Unauthorized(account, msg.sender));
    }

    /**
     * @notice Checks if an address is an owner of a given account.
     * @param account The account to check.
     * @param owner The address to check for ownership.
     * @return True if the address is an owner, false otherwise.
     */
    function isOwner(IERC7579Execution account, address owner) public view returns (bool) {
        return accountOwners[account].contains(owner);
    }

    /**
     * @notice Returns the list of owners for a given account.
     * @param account The account to query.
     * @return An array of owner addresses.
     */
    function getOwners(IERC7579Execution account) external view returns (address[] memory) {
        return accountOwners[account].values();
    }

    function _addOwner(IERC7579Execution account, address owner) internal {
        accountOwners[account].add(owner);
        emit OwnerAdded(account, owner);
    }

    function _removeOwner(IERC7579Execution account, address owner) internal {
        accountOwners[account].remove(owner);
        emit OwnerRemoved(account, owner);
    }

    /**
     * @notice Initializes the module for an account.
     * @dev Decodes initial owners from the provided data.
     * @param data Packed owner addresses (20 bytes each).
     */
    function onInstall(bytes calldata data) external override {
        IERC7579Execution account = IERC7579Execution(msg.sender);
        require(accountOwners[account].length() == 0, AlreadyInstalled());
        require(data.length >= ADDR_SIZE, AtLeastOneOwner());
        require(data.length % ADDR_SIZE == 0, InvalidDataLength());

        uint256 numAddresses = data.length / ADDR_SIZE;

        for (uint256 i = 0; i < numAddresses; i++) {
            uint256 from = i * ADDR_SIZE;
            uint256 to = from + ADDR_SIZE;
            address owner = address(uint160(bytes20(data[from:to])));
            _addOwner(account, owner);
        }
        emit ModuleInstalled(address(account), data);
    }

    /**
     * @notice Uninstalls the module for an account.
     * @dev Removes all owners associated with the account.
     * @param data Unused.
     */
    function onUninstall(bytes calldata data) external override {
        IERC7579Execution account = IERC7579Execution(msg.sender);
        require(accountOwners[account].length() > 0, NotInstalled());
        EnumerableSet.AddressSet storage addressSet = accountOwners[account];
        uint256 length = addressSet.length();
        for (uint256 i = length; i > 0; i--) {
            _removeOwner(account, addressSet.at(i - 1));
        }
        emit ModuleUninstalled(address(account), data);
    }

    function addOwner(address owner) external {
        _addOwner(IERC7579Execution(msg.sender), owner);
    }

    /**
     * @notice Adds a new owner to a specific account.
     * @dev Can only be called by an existing owner of the account.
     * @param account The account to modify.
     * @param owner The new owner address.
     */
    function addOwner(IERC7579Execution account, address owner) external onlyOwner(account) {
        _addOwner(account, owner);
    }

    function removeOwner(address owner) external {
        IERC7579Execution account = IERC7579Execution(msg.sender);
        _removeOwner(account, owner);
        require(accountOwners[account].length() > 0, CannotRemoveLastOwner());
    }

    // ============================= EXECUTION FUNCTIONS =============================

    /**
     * @notice Executes a single call on behalf of an account.
     * @dev See `OwnableExecutor.t.sol` for examples.
     * @param account The account to execute the call from.
     * @param target The target address of the call.
     * @param data The calldata to be executed.
     * @return returnData The return data from the execution.
     * @custom:example `execute(account, token, abi.encodeCall(IERC20.transfer, (to, amount)))`
     */
    function execute(IERC7579Execution account, address target, bytes calldata data)
        external
        payable
        onlyOwner(account)
        returns (bytes memory returnData)
    {
        return _execute(account, target, data);
    }

    /**
     * @notice Executes a single delegatecall on behalf of an account.
     * @dev See `OwnableExecutor.t.sol` for examples.
     * @param account The account to execute the delegatecall from.
     * @param target The target address of the delegatecall.
     * @param data The calldata to be executed.
     * @return returnData The return data from the execution.
     * @custom:example `delegate(account, lib, abi.encodeCall(Lib.foo, (arg)))`
     */
    function delegate(IERC7579Execution account, address target, bytes calldata data)
        external
        payable
        onlyOwner(account)
        returns (bytes memory returnData)
    {
        return _delegate(account, target, data);
    }

    /**
     * @notice Executes a batch of calls on behalf of an account.
     * @param account The account to execute the calls from.
     * @param calls The array of executions to perform.
     * @return returnData The array of return data from the executions.
     */
    function executeBatch(IERC7579Execution account, Execution[] calldata calls)
        external
        payable
        onlyOwner(account)
        returns (bytes[] memory returnData)
    {
        return _executeBatch(account, calls);
    }

    // ============================= ACTION EXECUTION FUNCTIONS =============================

    /**
     * @notice Executes a single packed action on behalf of an account.
     * @dev Uses delegatecall to the ActionExecutor.
     * @param account The account to execute the action from.
     * @param action The packed action data.
     * @return returnData The return data from the execution.
     */
    function executeAction(IERC7579Execution account, PackedAction calldata action)
        external
        payable
        onlyOwner(account)
        returns (bytes memory returnData)
    {
        return _executeAction(account, action);
    }

    /**
     * @notice Executes a batch of packed actions on behalf of an account.
     * @dev Uses delegatecall to the ActionExecutor.
     * @param account The account to execute the actions from.
     * @param actions The array of packed action data.
     * @return returnData The array of return data from the executions.
     */
    function executeActions(IERC7579Execution account, PackedAction[] calldata actions)
        external
        payable
        onlyOwner(account)
        returns (bytes[] memory returnData)
    {
        return _executeActions(account, actions);
    }

}
