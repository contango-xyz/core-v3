//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest, console } from "../BaseTest.t.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { TokenAction } from "../../src/actions/TokenAction.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";

import { PortoAccountWithPk, KeyType } from "../dependencies/Porto.sol";

contract AccountHierarchyTest is BaseTest {

    using MessageHashUtils for *;
    using ERC7579Lib for *;

    IERC20 internal constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);

    bytes32 internal constant _ERC7821_BATCH_EXECUTION_MODE = 0x0100000000007821000100000000000000000000000000000000000000000000;

    PortoAccountWithPk internal parent;
    address internal child;
    address internal grandChild;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_592_882);
        super.setUp();

        parent = newPortoAccount("parent");
        child = newAccount(parent.addr, "Child");
        grandChild = newAccount(child, "GrandChild");

        deal(address(usdc), address(child), 10_000e6);
        deal(address(usds), address(grandChild), 10_000e18);
    }

    function test_executeOnChildThruTheParent_OwnableExecutor() public {
        parent.execute({
            to: address(ownableExecutor),
            data: abi.encodeCall(
                ownableExecutor.delegate,
                (IERC7579Execution(child), address(tokenAction), abi.encodeCall(TokenAction.push, (usdc, 4000e6, parent.addr)))
            )
        });

        assertEqDecimal(usdc.balanceOf(parent.addr), 4000e6, 6, "parent balance");
        assertEqDecimal(usdc.balanceOf(child), 6000e6, 6, "child balance");
    }

    function test_executeOnChildAskingParentForPermission() public {
        address target = address(tokenAction);
        bytes memory data = abi.encodeCall(TokenAction.push, (usdc, 4000e6, parent.addr));

        bytes memory accountData = target.encodeDelegate(data);
        uint256 nonce = 0;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(child), accountData, ERC1271Executor.delegate.selector, nonce);

        bytes memory parentSignature = parent.sign(digest);

        bytes memory childSignature = abi.encodePacked(
            ownableValidator,
            abi.encodePacked(uint256(uint160(parent.addr)), uint256(65), uint8(0), parentSignature.length, parentSignature)
        );

        erc1271Executor.delegate({ account: IERC7579Execution(child), target: target, data: data, signature: childSignature, nonce: nonce });

        assertEqDecimal(usdc.balanceOf(parent.addr), 4000e6, 6, "parent balance");
        assertEqDecimal(usdc.balanceOf(child), 6000e6, 6, "child balance");
    }

    function test_executeOnChildAskingGrandParentForPermission() public {
        address target = address(tokenAction);
        bytes memory data = abi.encodeCall(TokenAction.push, (usds, 4000e18, parent.addr));

        bytes memory accountData = target.encodeDelegate(data);
        uint256 nonce = 0;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(grandChild), accountData, ERC1271Executor.delegate.selector, nonce);

        bytes memory grandParentSignature = parent.sign(digest.toEthSignedMessageHash());

        bytes memory parentSignature = abi.encodePacked(
            ownableValidator,
            abi.encodePacked(uint256(uint160(parent.addr)), uint256(65), uint8(0), grandParentSignature.length, grandParentSignature)
        );

        bytes memory grandChildSignature = abi.encodePacked(
            ownableValidator, abi.encodePacked(uint256(uint160(child)), uint256(65), uint8(0), parentSignature.length, parentSignature)
        );

        erc1271Executor.delegate({
            account: IERC7579Execution(grandChild), target: target, data: data, signature: grandChildSignature, nonce: nonce
        });

        assertEqDecimal(usds.balanceOf(parent.addr), 4000e18, 18, "owner balance");
        assertEqDecimal(usds.balanceOf(grandChild), 6000e18, 18, "grandChild balance");
        assertEqDecimal(usdc.balanceOf(child), 10_000e6, 6, "child balance");
    }

}
