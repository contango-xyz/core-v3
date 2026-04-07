//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";

import { ActionExecutor } from "../../src/modules/ActionExecutor.sol";
import { Action, ActionResult } from "../../src/types/Action.sol";

contract ActionExecutorTest is Test {

    ActionExecutor internal actionExecutor;

    function setUp() public {
        actionExecutor = new ActionExecutor();
    }

    function test_RevertWhen_DelegateCallWithValue() public {
        Action memory action = Action({
            target: address(new MockTarget()),
            value: 1,
            data: abi.encodeCall(MockTarget.getValue, ()),
            delegateCall: true,
            allowFailure: false
        });

        vm.expectRevert(ActionExecutor.DelegateCallWithValue.selector);
        actionExecutor.executeSingle(action);
    }

    function test_RevertWhen_InsufficientBalance() public {
        Action memory action = Action({
            target: address(new MockTarget()),
            value: 1 ether,
            data: abi.encodeCall(MockTarget.setValue, (42)),
            delegateCall: false,
            allowFailure: false
        });

        vm.expectRevert(ActionExecutor.InsufficientBalance.selector);
        actionExecutor.executeSingle(action);
    }

    function test_RevertWhen_ActionFailsAndFailureNotAllowed() public {
        Action memory action = Action({
            target: address(new MockReverter()),
            value: 0,
            data: abi.encodeCall(MockReverter.fail, ()),
            delegateCall: false,
            allowFailure: false
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                ActionExecutor.ActionFailed.selector, action, abi.encodeWithSelector(MockReverter.ExpectedFailure.selector)
            )
        );
        actionExecutor.executeSingle(action);
    }

    function test_ExecuteSingleReturnsFailedResultWhenFailureAllowed() public {
        Action memory action = Action({
            target: address(new MockReverter()),
            value: 0,
            data: abi.encodeCall(MockReverter.fail, ()),
            delegateCall: false,
            allowFailure: true
        });

        ActionResult memory result = actionExecutor.executeSingle(action);
        assertFalse(result.success);
        assertGe(result.data.length, 4);
    }

}

contract MockTarget {

    uint256 private value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

}

contract MockReverter {

    error ExpectedFailure();

    function fail() external pure {
        revert ExpectedFailure();
    }

}
