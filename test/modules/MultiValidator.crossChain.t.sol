//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest, console } from "../BaseTest.t.sol";

import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { MultiValidator, MultiSignature } from "../../src/modules/MultiValidator.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";
import { UnorderedNonce } from "../../src/modules/UnorderedNonce.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";

contract MultiValidatorCrossChainTest is BaseTest {

    using MessageHashUtils for *;
    using ERC7579Lib for *;

    uint256 internal ethereumFork;
    uint256 internal baseFork;

    address internal owner;
    uint256 internal ownerKey;
    address internal caller;

    MockTarget internal targetEthereum;
    MockTarget internal targetBase;

    MultiValidator internal multiValidator;

    address internal rootAccountEthereum;
    address internal subAccountEthereum;
    address internal rootAccountBase;
    address internal subAccountBase;

    uint256 internal nonce = 0;

    function setUp() public override {
        (owner, ownerKey) = makeAddrAndKey("owner");
        caller = makeAddr("caller");

        ethereumFork = vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        rootAccountEthereum = newAccount(owner, "Root Account");
        subAccountEthereum = newAccount(rootAccountEthereum, "Sub Account");

        multiValidator = new MultiValidator{ salt: "test" }();
        installModule(rootAccountEthereum, owner, address(multiValidator), "");

        targetEthereum = new MockTarget();

        baseFork = vm.createSelectFork("base", 43_181_672);
        super.setUp();

        rootAccountBase = newAccount(owner, "Root Account");
        subAccountBase = newAccount(rootAccountBase, "Sub Account");

        multiValidator = new MultiValidator{ salt: "test" }();
        installModule(rootAccountBase, owner, address(multiValidator), "");

        targetBase = new MockTarget();
    }

    function test_ExecuteAcrossMultipleChains() public {
        bytes memory signature;

        bytes memory callData1 = abi.encodeCall(MockTarget.setValue, (42));
        bytes memory callData2 = abi.encodeCall(MockTarget.setValue, (84));
        {
            vm.selectFork(ethereumFork);
            bytes memory accountData1 = address(targetEthereum).encodeSingle(0, callData1);
            bytes32 digest1 = erc1271Executor.digest(IERC7579Execution(rootAccountEthereum), accountData1, nonce + 1);

            vm.selectFork(baseFork);
            bytes memory accountData2 = address(targetBase).encodeSingle(0, callData2);
            bytes32 digest2 = erc1271Executor.digest(IERC7579Execution(rootAccountBase), accountData2, nonce + 2);

            // Signing from a third chain for the sake of it
            vm.createSelectFork("arbitrum", 440_349_333);

            bytes32[] memory intents = new bytes32[](2);
            intents[0] = digest1;
            intents[1] = digest2;

            bytes32 metaHash = keccak256(abi.encode(intents));

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, metaHash.toEthSignedMessageHash());
            MultiSignature memory multiSignature =
                MultiSignature({ intents: intents, signature: abi.encodePacked(ownableValidator, r, s, v) });

            signature = abi.encodePacked(multiValidator, abi.encode(multiSignature));
        }

        vm.selectFork(ethereumFork);

        vm.prank(caller);
        uint256 value = abi.decode(
            erc1271Executor.execute(IERC7579Execution(rootAccountEthereum), address(targetEthereum), callData1, signature, nonce + 1),
            (uint256)
        );

        assertEq(value, 84);
        assertEq(targetEthereum.getValue(), 42);

        vm.expectRevert(ERC1271Executor.InvalidSignature.selector);
        erc1271Executor.execute(IERC7579Execution(rootAccountBase), address(targetBase), callData2, signature, nonce + 2);

        vm.selectFork(baseFork);

        vm.expectRevert(ERC1271Executor.InvalidSignature.selector);
        erc1271Executor.execute(IERC7579Execution(rootAccountEthereum), address(targetEthereum), callData1, signature, nonce + 1);

        vm.prank(caller);
        value = abi.decode(
            erc1271Executor.execute(IERC7579Execution(rootAccountBase), address(targetBase), callData2, signature, nonce + 2), (uint256)
        );

        assertEq(value, 168);
        assertEq(targetBase.getValue(), 84);
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
