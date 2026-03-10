//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest, AccountFactory } from "../BaseTest.t.sol";
import { IERC7579Execution, MODULE_TYPE_HOOK } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { DelegateCallCheckHook, IERC7484 } from "../../src/modules/DelegateCallCheckHook.sol";
import { ISafe7579 } from "../../src/dependencies/safe/ISafe7579.sol";

contract DelegateCallCheckHookTest is BaseTest {

    DelegateCallCheckHook internal hook;

    address internal account;
    address internal owner;

    MockTarget internal target;
    MockDelegateTarget internal delegateTarget;

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
        super.setUp();
        hook = delegateCallCheckHook;

        target = new MockTarget();
        delegateTarget = new MockDelegateTarget();

        owner = makeAddr("owner");
        account = newAccount(owner);

        installModule(account, owner, MODULE_TYPE_HOOK, address(hook), "");
    }

    function test_Installation_SetsStateCorrectly() public {
        // setUp installed it without self-delegation allowed, so this should be false
        assertFalse(hook.allowSelfDelegate(address(account)));

        // Uninstall
        uninstallModule(account, owner, MODULE_TYPE_HOOK, address(hook), "");
        assertFalse(hook.allowSelfDelegate(address(account)));

        // Reinstall with self-delegation enabled
        installModule(account, owner, MODULE_TYPE_HOOK, address(hook), hex"01");
        assertTrue(hook.allowSelfDelegate(address(account)));
    }

    function test_StandardCallBypassesHook() public {
        // Mock registry to revert if called. If standard calls trigger it, the test fails. (mock both calls for belt and braces)
        vm.mockCallRevert(address(registry), abi.encodeWithSignature("checkForAccount(address,address)"), "Registry should not be called");

        vm.prank(owner);
        ownableExecutor.execute(IERC7579Execution(account), address(target), abi.encodeCall(MockTarget.setValue, (42)));

        assertEq(target.getValue(), 42);
    }

    function test_RevertWhen_UnattestedDelegateCall() public {
        // Mock registry to revert (simulate unattested module)
        vm.mockCallRevert(address(registry), abi.encodeWithSignature("checkForAccount(address,address)"), "Module Not Attested");

        vm.prank(owner);
        if (walletType() == AccountFactory.WalletType.SAFE) vm.expectRevert(ISafe7579.ExecutionFailed.selector);
        else vm.expectRevert("Module Not Attested");
        ownableExecutor.delegate(
            IERC7579Execution(account), address(delegateTarget), abi.encodeCall(MockDelegateTarget.setStorageValue, (42))
        );
    }

    function test_AttestedDelegateCallSucceeds() public {
        // Mock registry to succeed
        vm.mockCall(address(registry), abi.encodeWithSignature("checkForAccount(address,address)", account, delegateTarget), "");

        vm.prank(owner);
        ownableExecutor.delegate(
            IERC7579Execution(account), address(delegateTarget), abi.encodeCall(MockDelegateTarget.setStorageValue, (42))
        );

        // Prove the delegatecall worked in the account's context by reading it back
        vm.prank(owner);
        bytes memory returnData = ownableExecutor.delegate(
            IERC7579Execution(account), address(delegateTarget), abi.encodeCall(MockDelegateTarget.storageValue, ())
        );
        assertEq(abi.decode(returnData, (uint256)), 42);
    }

    function test_RevertWhen_SelfDelegateDisallowed() public {
        // Hook was installed with hex"00" (false) in setUp()
        vm.prank(owner);
        if (walletType() == AccountFactory.WalletType.SAFE) vm.expectRevert(ISafe7579.ExecutionFailed.selector);
        else vm.expectRevert(DelegateCallCheckHook.SelfDelegateCallNotAllowed.selector);
        ownableExecutor.delegate(IERC7579Execution(account), address(0), "");

        vm.prank(owner);
        if (walletType() == AccountFactory.WalletType.SAFE) vm.expectRevert(ISafe7579.ExecutionFailed.selector);
        else vm.expectRevert(DelegateCallCheckHook.SelfDelegateCallNotAllowed.selector);
        ownableExecutor.delegate(IERC7579Execution(account), address(account), "");
    }

    function test_SelfDelegateAllowedSucceeds() public {
        // Explicitly opt-in the account to self-delegation
        vm.prank(account);
        hook.setSelfDelegationAllowed(true);

        // These should now pass without hitting the registry
        vm.mockCallRevert(address(registry), abi.encodeWithSignature("checkForAccount(address,address)"), "Boom");

        vm.prank(owner);
        ownableExecutor.delegate(IERC7579Execution(account), address(0), "");

        vm.prank(owner);
        ownableExecutor.delegate(IERC7579Execution(account), address(account), "");
    }

}

// Helper contracts
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
