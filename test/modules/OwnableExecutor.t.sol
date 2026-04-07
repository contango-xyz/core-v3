//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "../BaseTest.t.sol";
import { Vm } from "forge-std/Vm.sol";
import { ERC7579Utils, ModeSelector, ModePayload } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";
import { IERC7579Execution, MODULE_TYPE_EXECUTOR, Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { OwnableExecutor, OwnableExecutorEvents } from "../../src/modules/OwnableExecutor.sol";
import { ActionExecutor } from "../../src/modules/ActionExecutor.sol";
import { ActionResult, PackedAction } from "../../src/types/Action.sol";

contract OwnableExecutorTest is BaseTest, OwnableExecutorEvents {

    IERC7579Execution internal account;
    address internal owner;
    address internal otherOwner;
    OwnableExecutor internal freshExecutor;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        owner = makeAddr("owner");
        otherOwner = makeAddr("otherOwner");
        freshExecutor = new OwnableExecutor(actionExecutor);

        account = IERC7579Execution(newAccount(owner));
        vm.label(address(account), "account");
    }

    function test_ModuleType() public view {
        assertTrue(ownableExecutor.isModuleType(MODULE_TYPE_EXECUTOR));
        assertFalse(ownableExecutor.isModuleType(1));
    }

    function test_Installation() public {
        bytes memory data = abi.encodePacked(owner);
        vm.prank(address(account));
        freshExecutor.onInstall(data);

        assertTrue(freshExecutor.isOwner(account, owner));
        assertEq(freshExecutor.getOwners(account).length, 1);
        assertEq(freshExecutor.getOwners(account)[0], owner);
    }

    function test_InstallMultipleOwners() public {
        bytes memory data = abi.encodePacked(owner, otherOwner);
        vm.prank(address(account));
        freshExecutor.onInstall(data);

        assertTrue(freshExecutor.isOwner(account, owner));
        assertTrue(freshExecutor.isOwner(account, otherOwner));
        assertEq(freshExecutor.getOwners(account).length, 2);
        assertEq(freshExecutor.getOwners(account)[0], owner);
        assertEq(freshExecutor.getOwners(account)[1], otherOwner);
    }

    function test_RevertWhen_InstallWithInvalidLength() public {
        bytes memory data = abi.encodePacked(owner, hex"1234"); // Invalid length
        vm.prank(address(account));
        vm.expectRevert(OwnableExecutor.InvalidDataLength.selector);
        freshExecutor.onInstall(data);
    }

    function test_RevertWhen_ReinstallAttempted() public {
        bytes memory data = abi.encodePacked(owner);
        vm.prank(address(account));
        vm.expectRevert(OwnableExecutor.AlreadyInstalled.selector);
        ownableExecutor.onInstall(data);
    }

    function test_AddOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit OwnerAdded(account, otherOwner);
        ownableExecutor.addOwner(account, otherOwner);

        assertTrue(ownableExecutor.isOwner(account, otherOwner));
        assertEq(ownableExecutor.getOwners(account).length, 2);
        assertEq(ownableExecutor.getOwners(account)[0], owner);
        assertEq(ownableExecutor.getOwners(account)[1], otherOwner);
    }

    function test_RevertWhen_AddOwnerBeforeInstall() public {
        vm.prank(address(account));
        vm.expectRevert(OwnableExecutor.NotInstalled.selector);
        freshExecutor.addOwner(otherOwner);
    }

    function test_AddOwner_DuplicateNoop() public {
        vm.prank(owner);
        ownableExecutor.addOwner(account, otherOwner);
        uint256 ownersBefore = ownableExecutor.getOwners(account).length;

        vm.recordLogs();
        vm.prank(owner);
        ownableExecutor.addOwner(account, otherOwner);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 ownerAddedSig = keccak256("OwnerAdded(address,address)");
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(entries[i].topics[0] != ownerAddedSig, "unexpected OwnerAdded");
        }
        assertEq(ownableExecutor.getOwners(account).length, ownersBefore);
    }

    function test_RevertWhen_NonOwnerAddsOwner() public {
        vm.prank(otherOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableExecutor.Unauthorized.selector, account, otherOwner));
        ownableExecutor.addOwner(account, otherOwner);
    }

    function test_RemoveOwner() public {
        // First add a second owner
        vm.prank(owner);
        ownableExecutor.addOwner(account, otherOwner);

        vm.prank(address(account));
        vm.expectEmit(true, true, true, true);
        emit OwnerRemoved(account, otherOwner);
        ownableExecutor.removeOwner(otherOwner);

        assertFalse(ownableExecutor.isOwner(account, otherOwner));
    }

    function test_RemoveOwner_NonExistentNoop() public {
        vm.recordLogs();
        vm.prank(address(account));
        ownableExecutor.removeOwner(otherOwner);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 ownerRemovedSig = keccak256("OwnerRemoved(address,address)");
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(entries[i].topics[0] != ownerRemovedSig, "unexpected OwnerRemoved");
        }
        assertEq(ownableExecutor.getOwners(account).length, 1);
        assertTrue(ownableExecutor.isOwner(account, owner));
    }

    function test_RevertWhen_RemovingLastOwner() public {
        vm.prank(address(account));
        vm.expectRevert(OwnableExecutor.CannotRemoveLastOwner.selector);
        ownableExecutor.removeOwner(owner);
    }

    function test_Uninstall() public {
        vm.prank(address(account));
        ownableExecutor.onUninstall("");

        assertEq(ownableExecutor.getOwners(account).length, 0);
    }

    function test_RevertWhen_UninstallNotInstalled() public {
        vm.prank(address(account));
        ownableExecutor.onUninstall("");

        vm.expectRevert(OwnableExecutor.NotInstalled.selector);
        vm.prank(address(account));
        ownableExecutor.onUninstall("");
    }

    // Integration tests for execution methods

    function test_Execute() public {
        // Setup a mock contract to call
        MockTarget target = new MockTarget();

        vm.prank(owner);
        ownableExecutor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)));

        assertEq(target.getValue(), 42);
    }

    function test_ExecuteWithValue() public {
        // Setup a mock contract to call
        MockTarget target = new MockTarget();

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        ownableExecutor.execute{ value: 0.4 ether }(account, address(target), abi.encodeCall(MockTarget.setValue, (42)));

        assertEq(target.getValue(), 42);
        assertEqDecimal(address(target).balance, 0.4 ether, 18);
    }

    function test_Delegate() public {
        // Setup a mock contract to delegate to
        MockDelegateTarget target = new MockDelegateTarget();

        vm.prank(owner);
        ownableExecutor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.setStorageValue, (42)));

        // Storage slot should be set in the account's context
        assertEq(target.storageValue(), 0);

        vm.prank(owner);
        uint256 value =
            abi.decode(ownableExecutor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.storageValue, ())), (uint256));

        // Storage slot should be set in the account's context
        assertEq(value, 42);
    }

    function test_DelegateWithValue() public {
        // Setup a mock contract to delegate to
        MockDelegateTarget target = new MockDelegateTarget();

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        ownableExecutor.delegate{ value: 0.4 ether }(account, address(target), abi.encodeCall(MockDelegateTarget.setStorageValue, (42)));

        // Storage slot should be set in the account's context
        assertEq(target.storageValue(), 0);

        vm.prank(owner);
        uint256 value =
            abi.decode(ownableExecutor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.storageValue, ())), (uint256));

        // Storage slot should be set in the account's context
        assertEq(value, 42);
        uint256 accBalance = address(account).balance;
        assertEqDecimal(accBalance, 0.4 ether, 18);
    }

    function test_ExecuteBatch() public {
        // Setup multiple calls
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0, callData: abi.encodeCall(MockTarget.setValue, (42)) });
        calls[1] = Execution({ target: address(target2), value: 0, callData: abi.encodeCall(MockTarget.setValue, (24)) });

        vm.prank(owner);
        ownableExecutor.executeBatch(account, calls);

        assertEq(target1.getValue(), 42);
        assertEq(target2.getValue(), 24);
    }

    function test_ExecuteBatchWithValues() public {
        // Setup multiple calls
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0.4 ether, callData: abi.encodeCall(MockTarget.setValue, (42)) });
        calls[1] = Execution({ target: address(target2), value: 0.2 ether, callData: abi.encodeCall(MockTarget.setValue, (24)) });

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        ownableExecutor.executeBatch{ value: 1 ether }(account, calls);

        assertEq(target1.getValue(), 42);
        assertEq(target2.getValue(), 24);
        assertEqDecimal(address(target1).balance, 0.4 ether, 18);
        assertEqDecimal(address(target2).balance, 0.2 ether, 18);
        assertEqDecimal(address(account).balance, 0.4 ether, 18);
    }

    function test_RevertWhen_ExecuteBatchWithInsufficientValue() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0.4 ether, callData: abi.encodeCall(MockTarget.setValue, (42)) });
        calls[1] = Execution({ target: address(target2), value: 0.7 ether, callData: abi.encodeCall(MockTarget.setValue, (24)) });

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        vm.expectRevert();
        ownableExecutor.executeBatch{ value: 1 ether }(account, calls);
    }

    function test_RevertWhen_NonOwnerExecutes() public {
        MockTarget target = new MockTarget();

        vm.prank(otherOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableExecutor.Unauthorized.selector, account, otherOwner));
        ownableExecutor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)));
    }

    function test_RevertWhen_NonOwnerDelegates() public {
        MockDelegateTarget target = new MockDelegateTarget();

        vm.prank(otherOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableExecutor.Unauthorized.selector, account, otherOwner));
        ownableExecutor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.setStorageValue, (42)));
    }

    function test_RevertWhen_NonOwnerExecutesBatch() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0, callData: abi.encodeCall(MockTarget.setValue, (42)) });
        calls[1] = Execution({ target: address(target2), value: 0, callData: abi.encodeCall(MockTarget.setValue, (24)) });

        vm.prank(otherOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableExecutor.Unauthorized.selector, account, otherOwner));
        ownableExecutor.executeBatch(account, calls);
    }

    function test_ExecuteReturnsData() public {
        MockTarget target = new MockTarget();
        vm.prank(owner);
        bytes memory returnData = ownableExecutor.execute(account, address(target), abi.encodeCall(MockTarget.getValue, ()));
        assertEq(abi.decode(returnData, (uint256)), 0);
    }

    function test_DelegateReturnsData() public {
        MockDelegateTarget target = new MockDelegateTarget();

        vm.prank(owner);
        ownableExecutor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.setStorageValue, (42)));

        vm.prank(owner);
        bytes memory returnData = ownableExecutor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.storageValue, ()));
        assertEq(abi.decode(returnData, (uint256)), 42);
    }

    function test_ExecuteBatchReturnsData() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        vm.prank(owner);
        ownableExecutor.execute(account, address(target1), abi.encodeCall(MockTarget.setValue, (42)));
        vm.prank(owner);
        ownableExecutor.execute(account, address(target2), abi.encodeCall(MockTarget.setValue, (24)));

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0, callData: abi.encodeCall(MockTarget.getValue, ()) });
        calls[1] = Execution({ target: address(target2), value: 0, callData: abi.encodeCall(MockTarget.getValue, ()) });

        vm.prank(owner);
        bytes[] memory returnData = ownableExecutor.executeBatch(account, calls);
        assertEq(abi.decode(returnData[0], (uint256)), 42);
        assertEq(abi.decode(returnData[1], (uint256)), 24);
    }

    function test_ExecuteActionsReturnsSuccessFlags() public {
        MockTarget target = new MockTarget();
        MockReverter reverter = new MockReverter();

        PackedAction[] memory actions = new PackedAction[](2);
        actions[0] = PackedAction({
            data: abi.encodePacked(address(target), uint96(0), bytes1(0x00), bytes1(0x00), abi.encodeCall(MockTarget.getValue, ()))
        });
        actions[1] = PackedAction({
            data: abi.encodePacked(address(reverter), uint96(0), bytes1(0x00), bytes1(0x01), abi.encodeCall(MockReverter.fail, ()))
        });

        vm.prank(owner);
        ActionResult[] memory returnData = ownableExecutor.executeActions(account, actions);

        assertEq(returnData.length, 2);
        assertTrue(returnData[0].success);
        assertEq(abi.decode(returnData[0].data, (uint256)), 0);
        assertFalse(returnData[1].success);
        bytes memory failureData = returnData[1].data;
        assertGe(failureData.length, 4);
        bytes4 selector;
        assembly {
            selector := mload(add(failureData, 32))
        }
        assertEq(selector, MockReverter.ExpectedFailure.selector);
    }

}

// Helper contracts for testing execution methods
contract MockTarget {

    uint256 private value;

    function setValue(uint256 _value) external payable {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

}

contract MockDelegateTarget {

    uint256[100_000] private pushStorageSlot;
    uint256 private _storageValue;

    function setStorageValue(uint256 _value) external {
        _storageValue = _value;
    }

    function storageValue() external view returns (uint256) {
        return _storageValue;
    }

}

contract MockReverter {

    error ExpectedFailure();

    function fail() external pure {
        revert ExpectedFailure();
    }

}
