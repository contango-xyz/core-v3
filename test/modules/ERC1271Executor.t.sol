//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "../BaseTest.t.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC7579Utils } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";
import {
    IERC7579Execution,
    MODULE_TYPE_EXECUTOR,
    Execution,
    IERC7579Validator
} from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { UnorderedNonce } from "../../src/modules/UnorderedNonce.sol";
import { ERC7579Executor } from "../../src/modules/base/ERC7579Executor.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";

contract ERC1271ExecutorTest is BaseTest {

    using MessageHashUtils for *;
    using ERC7579Lib for *;

    IERC7579Execution internal account;
    uint256 internal ownerKey;
    address internal owner;
    address internal caller;

    uint256 internal nonce = 1;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        (owner, ownerKey) = makeAddrAndKey("owner");
        caller = makeAddr("caller");

        // Create account with owner
        account = IERC7579Execution(newAccount(owner, "account"));
    }

    function test_ModuleType() public view {
        assertTrue(erc1271Executor.isModuleType(MODULE_TYPE_EXECUTOR));
        assertFalse(erc1271Executor.isModuleType(1));
    }

    function test_ExecuteSingle() public {
        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(0, abi.encodeCall(MockTarget.setValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.prank(caller);
        uint256 value = abi.decode(
            erc1271Executor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce), (uint256)
        );

        assertEq(value, 84);
        assertEq(target.getValue(), 42);
    }

    function test_ExecuteWithValue() public {
        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(0.4 ether, abi.encodeCall(MockTarget.setValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.deal(caller, 1 ether);
        vm.prank(caller);
        uint256 value = abi.decode(
            erc1271Executor.execute{ value: 0.4 ether }(
                account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce
            ),
            (uint256)
        );

        assertEq(value, 84);
        assertEq(target.getValue(), 42);
        assertEqDecimal(address(target).balance, 0.4 ether, 18);
    }

    function test_Delegate() public {
        MockDelegateTarget target = new MockDelegateTarget();

        bytes memory accountData = address(target).encodeDelegate(abi.encodeCall(MockDelegateTarget.setStorageValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.prank(caller);
        erc1271Executor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.setStorageValue, (42)), signature, nonce);

        assertEq(target.storageValue(), 0);

        accountData = address(target).encodeDelegate(abi.encodeCall(MockDelegateTarget.storageValue, ()));
        hash = erc1271Executor.digest(IERC7579Execution(account), accountData, ++nonce);
        (v, r, s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.prank(caller);
        uint256 value = abi.decode(
            erc1271Executor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.storageValue, ()), signature, nonce),
            (uint256)
        );
        assertEq(value, 42);
    }

    function test_DelegateWithValue() public {
        MockDelegateTarget target = new MockDelegateTarget();

        bytes memory accountData = address(target).encodeDelegate(abi.encodeCall(MockDelegateTarget.setStorageValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.deal(caller, 1 ether);
        vm.prank(caller);
        erc1271Executor.delegate{ value: 0.4 ether }(
            account, address(target), abi.encodeCall(MockDelegateTarget.setStorageValue, (42)), signature, nonce
        );

        assertEq(target.storageValue(), 0);

        accountData = address(target).encodeDelegate(abi.encodeCall(MockDelegateTarget.storageValue, ()));
        hash = erc1271Executor.digest(IERC7579Execution(account), accountData, ++nonce);
        (v, r, s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.prank(caller);
        uint256 value = abi.decode(
            erc1271Executor.delegate(account, address(target), abi.encodeCall(MockDelegateTarget.storageValue, ()), signature, nonce),
            (uint256)
        );
        assertEq(value, 42);
        uint256 accBalance = address(account).balance;
        assertEqDecimal(accBalance, 0.4 ether, 18);
    }

    function test_ExecuteBatch() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0, callData: abi.encodeCall(MockTarget.setValue, (42)) });
        calls[1] = Execution({ target: address(target2), value: 0, callData: abi.encodeCall(MockTarget.setValue, (24)) });

        bytes memory accountData = calls.encodeBatch();
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.prank(caller);
        bytes[] memory returnData = erc1271Executor.executeBatch(account, calls, signature, nonce);

        assertEq(abi.decode(returnData[0], (uint256)), 84);
        assertEq(abi.decode(returnData[1], (uint256)), 48);
        assertEq(target1.getValue(), 42);
        assertEq(target2.getValue(), 24);
    }

    function test_ExecuteBatchWithValues() public {
        MockTarget target1 = new MockTarget();
        MockTarget target2 = new MockTarget();

        Execution[] memory calls = new Execution[](2);
        calls[0] = Execution({ target: address(target1), value: 0.4 ether, callData: abi.encodeCall(MockTarget.setValue, (42)) });
        calls[1] = Execution({ target: address(target2), value: 0.2 ether, callData: abi.encodeCall(MockTarget.setValue, (24)) });

        bytes memory accountData = calls.encodeBatch();
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.deal(caller, 1 ether);
        vm.prank(caller);
        bytes[] memory returnData = erc1271Executor.executeBatch{ value: 1 ether }(account, calls, signature, nonce);

        assertEq(abi.decode(returnData[0], (uint256)), 84);
        assertEq(abi.decode(returnData[1], (uint256)), 48);
        assertEq(target1.getValue(), 42);
        assertEq(target2.getValue(), 24);
        assertEqDecimal(address(target1).balance, 0.4 ether, 18);
        assertEqDecimal(address(target2).balance, 0.2 ether, 18);
        assertEqDecimal(address(account).balance, 0.4 ether, 18);
    }

    function test_RevertWhen_ExecuteWithInvalidSignature() public {
        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(0, abi.encodeCall(MockTarget.setValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (, uint256 wrongKey) = makeAddrAndKey("wrong");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.prank(caller);
        vm.expectRevert(ERC1271Executor.InvalidSignature.selector);
        erc1271Executor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);
    }

    function test_RevertWhen_ExecuteWithInsufficientValue() public {
        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(1 ether, abi.encodeCall(MockTarget.setValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        vm.deal(caller, 0.5 ether);
        vm.prank(caller);
        vm.expectRevert();
        erc1271Executor.execute{ value: 0.5 ether }(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);
    }

    function test_RevertWhen_ExecuteWithWrongValidator() public {
        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(0, abi.encodeCall(MockTarget.setValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(address(0xdead), r, s, v); // Wrong validator

        vm.prank(caller);
        vm.expectRevert(); // Different wallets revert differently
        erc1271Executor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);
    }

    function test_RevertWhen_ExecuteWithSignatureFromDifferentAccount() public {
        // Create a second account with the same owner
        IERC7579Execution account2 = IERC7579Execution(newAccount(owner, "account2"));

        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(0, abi.encodeCall(MockTarget.setValue, (42)));

        // Sign for account1
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        // Try to use the signature on account2
        vm.prank(caller);
        vm.expectRevert(ERC1271Executor.InvalidSignature.selector);
        erc1271Executor.execute(account2, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);

        // Verify that the original signature still works with account1
        vm.prank(caller);
        erc1271Executor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);
        assertEq(target.getValue(), 42);
    }

    function test_RevertWhen_ExecuteWithReplayedSignature() public {
        MockTarget target = new MockTarget();
        bytes memory accountData = address(target).encodeSingle(0, abi.encodeCall(MockTarget.setValue, (42)));
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        // First execution should succeed
        vm.prank(caller);
        erc1271Executor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);
        assertEq(target.getValue(), 42);

        // Second execution with same signature should fail
        vm.prank(caller);
        vm.expectRevert(UnorderedNonce.InvalidNonce.selector);
        erc1271Executor.execute(account, address(target), abi.encodeCall(MockTarget.setValue, (42)), signature, nonce);
    }

}

// Helper contracts
contract MockTarget {

    uint256 private value;

    function setValue(uint256 _value) external payable returns (uint256) {
        value = _value;
        return value * 2;
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
