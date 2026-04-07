//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { ERC20Lib } from "../../src/libraries/ERC20Lib.sol";
import { IWETH9 } from "../../src/dependencies/IWETH9.sol";
import { ERC20Mock } from "../ERC20Mock.sol";

contract WETH9Mock is ERC20, IWETH9 {

    constructor() ERC20("Wrapped Ether", "WETH") { }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);
        (bool success,) = payable(msg.sender).call{ value: wad }("");
        require(success);
    }

}

contract ERC20LibHarness {

    using ERC20Lib for IERC20;
    using ERC20Lib for IWETH9;

    receive() external payable { }

    function transferOutWithPermit2(IERC20 token, address from, address to, uint256 amount, bool usePermit2)
        external
        returns (uint256 amountTransferred)
    {
        return token.transferOut(from, to, amount, usePermit2);
    }

    function depositNativeTo(IWETH9 token, uint256 amount, address to) external payable returns (uint256 amountTransferred) {
        return token.depositNative(amount, to);
    }

    function mintWeth(IWETH9 token) external payable {
        token.deposit{ value: msg.value }();
    }

    function transferOutNativeTo(IWETH9 token, address payable to, uint256 amount) external returns (uint256 amountTransferred) {
        return token.transferOutNative(to, amount);
    }

}

contract ERC20LibTest is Test {

    ERC20LibHarness private harness;
    ERC20Mock private token;
    WETH9Mock private weth;

    address private payer;
    address private destination;

    function setUp() public {
        harness = new ERC20LibHarness();
        token = new ERC20Mock("Mock Token", "MTK");
        weth = new WETH9Mock();

        payer = makeAddr("payer");
        destination = makeAddr("destination");
    }

    function test_transferOut_usePermit2_zeroAmount_returnsZero() public {
        uint256 amountTransferred = harness.transferOutWithPermit2(token, payer, destination, 0, true);
        assertEq(amountTransferred, 0);
    }

    function test_transferOut_usePermit2_zeroPayer_reverts() public {
        vm.expectRevert(ERC20Lib.ZeroPayer.selector);
        harness.transferOutWithPermit2(token, address(0), destination, 1, true);
    }

    function test_transferOut_usePermit2_zeroDestination_reverts() public {
        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        harness.transferOutWithPermit2(token, payer, address(0), 1, true);
    }

    function test_transferOut_usePermit2_sameAddress_returnsAmount() public {
        uint256 amountTransferred = harness.transferOutWithPermit2(token, payer, payer, 1e18, true);
        assertEq(amountTransferred, 1e18);
    }

    function test_depositNative_zeroAmount_returnsZero() public {
        uint256 amountTransferred = harness.depositNativeTo{ value: 0 }(weth, 0, destination);
        assertEq(amountTransferred, 0);
    }

    function test_depositNative_zeroDestination_reverts() public {
        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        harness.depositNativeTo{ value: 1 }(weth, 1, address(0));
    }

    function test_transferOutNative_zeroAmount_returnsZero() public {
        uint256 amountTransferred = harness.transferOutNativeTo(weth, payable(destination), 0);
        assertEq(amountTransferred, 0);
    }

    function test_transferOutNative_zeroDestination_reverts() public {
        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        harness.transferOutNativeTo(weth, payable(address(0)), 1);
    }

    function test_transferOutNative_transfersEth() public {
        harness.mintWeth{ value: 1 ether }(weth);
        uint256 balanceBefore = destination.balance;

        uint256 amountTransferred = harness.transferOutNativeTo(weth, payable(destination), 0.4 ether);

        assertEq(amountTransferred, 0.4 ether);
        assertEq(destination.balance, balanceBefore + 0.4 ether);
        assertEq(weth.balanceOf(address(harness)), 0.6 ether);
    }

}
