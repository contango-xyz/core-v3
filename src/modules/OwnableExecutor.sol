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

    function isOwner(IERC7579Execution account, address owner) public view returns (bool) {
        return accountOwners[account].contains(owner);
    }

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

    function addOwner(IERC7579Execution account, address owner) external onlyOwner(account) {
        _addOwner(account, owner);
    }

    function removeOwner(address owner) external {
        IERC7579Execution account = IERC7579Execution(msg.sender);
        _removeOwner(account, owner);
        require(accountOwners[account].length() > 0, CannotRemoveLastOwner());
    }

    // ============================= EXECUTION FUNCTIONS =============================

    function execute(IERC7579Execution account, address target, bytes calldata data)
        external
        payable
        onlyOwner(account)
        returns (bytes memory returnData)
    {
        return _execute(account, target, data);
    }

    function delegate(IERC7579Execution account, address target, bytes calldata data)
        external
        payable
        onlyOwner(account)
        returns (bytes memory returnData)
    {
        return _delegate(account, target, data);
    }

    function executeBatch(IERC7579Execution account, Execution[] calldata calls)
        external
        payable
        onlyOwner(account)
        returns (bytes[] memory returnData)
    {
        return _executeBatch(account, calls);
    }

    // ============================= ACTION EXECUTION FUNCTIONS =============================

    function executeAction(IERC7579Execution account, PackedAction calldata action)
        external
        payable
        onlyOwner(account)
        returns (bytes memory returnData)
    {
        return _executeAction(account, action);
    }

    function executeActions(IERC7579Execution account, PackedAction[] calldata actions)
        external
        payable
        onlyOwner(account)
        returns (bytes[] memory returnData)
    {
        return _executeActions(account, actions);
    }

}
