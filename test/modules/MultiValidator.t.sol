//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "../BaseTest.t.sol";

import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { MultiValidator, MultiSignature } from "../../src/modules/MultiValidator.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";
import { UnorderedNonce } from "../../src/modules/UnorderedNonce.sol";

contract MultiValidatorTest is BaseTest {

    using MessageHashUtils for *;
    using ERC7579Lib for *;

    MultiValidator internal multiValidator;

    address internal owner;
    uint256 internal ownerKey;
    address internal caller;

    address internal rootAccount;
    address internal subAccount;

    uint256 internal nonce = 0;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        (owner, ownerKey) = makeAddrAndKey("owner");
        caller = makeAddr("caller");

        rootAccount = newAccount(owner);
        subAccount = newAccount(rootAccount);

        multiValidator = new MultiValidator();
        installModule(rootAccount, owner, address(multiValidator), "");
    }

    function test_ExecuteSingle() public {
        MockTarget target = new MockTarget();
        bytes memory callData = abi.encodeCall(MockTarget.setValue, (42));
        bytes memory accountData = address(target).encodeSingle(0, callData);
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(rootAccount), accountData, nonce);

        bytes32[] memory intents = new bytes32[](1);
        intents[0] = digest;

        bytes32 metaHash = keccak256(abi.encode(intents));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, metaHash.toEthSignedMessageHash());

        MultiSignature memory multiSignature = MultiSignature({ intents: intents, signature: abi.encodePacked(ownableValidator, r, s, v) });

        bytes memory signature = abi.encodePacked(multiValidator, abi.encode(multiSignature));

        vm.prank(caller);
        uint256 value =
            abi.decode(erc1271Executor.execute(IERC7579Execution(rootAccount), address(target), callData, signature, nonce), (uint256));

        assertEq(value, 84);
        assertEq(target.getValue(), 42);

        vm.prank(caller);
        vm.expectRevert(UnorderedNonce.InvalidNonce.selector);
        erc1271Executor.execute(IERC7579Execution(rootAccount), address(target), callData, signature, nonce);
    }

    function test_ExecuteMultiple() public {
        MockTarget target = new MockTarget();
        bytes memory signature;

        bytes memory callData1 = abi.encodeCall(MockTarget.setValue, (42));
        bytes memory callData2 = abi.encodeCall(MockTarget.setValue, (84));
        {
            bytes memory accountData1 = address(target).encodeSingle(0, callData1);
            bytes32 digest1 = erc1271Executor.digest(IERC7579Execution(rootAccount), accountData1, nonce + 1);

            bytes memory accountData2 = address(target).encodeSingle(0, callData2);
            bytes32 digest2 = erc1271Executor.digest(IERC7579Execution(rootAccount), accountData2, nonce + 2);

            bytes32[] memory intents = new bytes32[](2);
            intents[0] = digest1;
            intents[1] = digest2;

            bytes32 metaHash = keccak256(abi.encode(intents));

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, metaHash.toEthSignedMessageHash());
            MultiSignature memory multiSignature =
                MultiSignature({ intents: intents, signature: abi.encodePacked(ownableValidator, r, s, v) });

            signature = abi.encodePacked(multiValidator, abi.encode(multiSignature));
        }

        vm.prank(caller);
        uint256 value = abi.decode(
            erc1271Executor.execute(IERC7579Execution(rootAccount), address(target), callData1, signature, nonce + 1), (uint256)
        );

        assertEq(value, 84);
        assertEq(target.getValue(), 42);

        skip(30 minutes);

        vm.prank(caller);
        vm.expectRevert(UnorderedNonce.InvalidNonce.selector);
        erc1271Executor.execute(IERC7579Execution(rootAccount), address(target), callData1, signature, nonce + 1);

        vm.prank(caller);
        value = abi.decode(
            erc1271Executor.execute(IERC7579Execution(rootAccount), address(target), callData2, signature, nonce + 2), (uint256)
        );

        assertEq(value, 168);
        assertEq(target.getValue(), 84);

        vm.prank(caller);
        vm.expectRevert(UnorderedNonce.InvalidNonce.selector);
        erc1271Executor.execute(IERC7579Execution(rootAccount), address(target), callData2, signature, nonce + 2);
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
