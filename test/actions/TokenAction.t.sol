//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

import { IAllowanceTransfer } from "../../src/dependencies/permit2/IPermit2.sol";

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import { IWETH9 } from "../../src/dependencies/IWETH9.sol";
import { TokenAction } from "../../src/actions/TokenAction.sol";
import { ERC20Mock } from "../ERC20Mock.sol";
import { DumbWallet } from "../DumbWallet.sol";
import { ACCOUNT_BALANCE } from "../../src/constants.sol";
import { PermitSigner } from "../PermitUtils.t.sol";
import { ERC20Lib, EIP2098Permit } from "../../src/libraries/ERC20Lib.sol";

contract TokenActionTest is Test, PermitSigner {

    TokenAction private tokenAction;
    ERC20Mock private mockToken;
    IWETH9 private weth;
    DumbWallet private wallet;

    address private user1;
    uint256 private user1Pk;
    address private user2;
    uint256 private user2Pk;
    address private spender;

    function setUp() public {
        vm.createSelectFork("mainnet", 22_895_431);

        // Deploy WETH9 mock or use real WETH address
        weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        tokenAction = new TokenAction(weth);
        wallet = new DumbWallet();

        // Deploy mock ERC20 token
        mockToken = new ERC20Mock("Mock Token", "MTK");

        // Setup test addresses (EOAs)
        (user1, user1Pk) = makeAddrAndKey("user1");
        (user2, user2Pk) = makeAddrAndKey("user2");
        spender = makeAddr("spender");

        // Give tokens to the wallet (smart wallet holds the tokens)
        mockToken.mint(address(wallet), 1000e18);

        // Give some ETH to the wallet
        vm.deal(address(wallet), 100 ether);
    }

    // ========== CONSTRUCTOR TESTS ==========

    function test_constructor_setsNativeToken() public view {
        assertEq(address(tokenAction.NATIVE_TOKEN()), address(weth));
    }

    // ========== PULL TESTS ==========

    function test_pull_specificAmount() public {
        uint256 amount = 100e18;
        uint256 initialBalance = mockToken.balanceOf(address(wallet));

        // User1 approves the wallet to spend their tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        mockToken.approve(address(wallet), amount);
        vm.stopPrank();

        // Wallet delegates the pull action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, amount, user1, false)));

        assertEq(mockToken.balanceOf(address(wallet)), initialBalance + amount);
        assertEq(mockToken.balanceOf(user1), 0);
    }

    function test_pull_accountBalance() public {
        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, 500e18);
        uint256 userBalance = mockToken.balanceOf(user1);
        mockToken.approve(address(wallet), userBalance);
        vm.stopPrank();

        uint256 initialBalance = mockToken.balanceOf(address(wallet));

        // Wallet delegates the pull action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, ACCOUNT_BALANCE, user1, false)));

        assertEq(mockToken.balanceOf(address(wallet)), initialBalance + userBalance);
        assertEq(mockToken.balanceOf(user1), 0);
    }

    function test_pull_withPermit2() public {
        uint256 amount = 100e18;

        (IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) =
            signPermit2PermitSingle(mockToken, user1, user1Pk, amount, address(wallet));

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        mockToken.approve(address(permit2), type(uint256).max);
        permit2.permit(user1, permitSingle, signature);
        vm.stopPrank();

        uint256 initialBalance = mockToken.balanceOf(address(wallet));

        // Wallet delegates the pull action with permit2
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, amount, user1, true)));

        assertEq(mockToken.balanceOf(address(wallet)), initialBalance + amount);
        assertEq(mockToken.balanceOf(user1), 0);
    }

    // ========== PULL WITH PERMIT TESTS ==========

    function test_pullWithPermit_version1() public {
        uint256 amount = 100e18;

        // Create permit signature for version 1
        EIP2098Permit memory permit = signPermit(mockToken, user1, user1Pk, amount, address(wallet));

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        vm.stopPrank();

        uint256 initialBalance = mockToken.balanceOf(address(wallet));

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pullWithPermit, (mockToken, amount, user1, permit)));

        assertEq(mockToken.balanceOf(address(wallet)), initialBalance + amount);
        assertEq(mockToken.balanceOf(user1), 0);
    }

    function test_pullWithPermit_version2() public {
        uint256 amount = 100e18;

        // Create permit signature for version 2
        EIP2098Permit memory permit = signPermit2SignatureTransfer(mockToken, user1, user1Pk, amount, address(wallet));

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        mockToken.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        uint256 initialBalance = mockToken.balanceOf(address(wallet));

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pullWithPermit, (mockToken, amount, user1, permit)));

        assertEq(mockToken.balanceOf(address(wallet)), initialBalance + amount);
        assertEq(mockToken.balanceOf(user1), 0);
    }

    // ========== PUSH TESTS ==========

    function test_push_specificAmount() public {
        uint256 amount = 50e18;
        uint256 initialBalance = mockToken.balanceOf(user2);

        // Wallet delegates the push action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.push, (mockToken, amount, user2)));

        assertEq(mockToken.balanceOf(user2), initialBalance + amount);
        assertEq(mockToken.balanceOf(address(wallet)), 950e18);
    }

    function test_push_accountBalance() public {
        uint256 walletBalance = mockToken.balanceOf(address(wallet));
        uint256 initialBalance = mockToken.balanceOf(user2);

        // Wallet delegates the push action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.push, (mockToken, ACCOUNT_BALANCE, user2)));

        assertEq(mockToken.balanceOf(user2), initialBalance + walletBalance);
        assertEq(mockToken.balanceOf(address(wallet)), 0);
    }

    // ========== TRANSFER TESTS ==========

    function test_transfer_specificAmount() public {
        uint256 amount = 100e18;

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        mockToken.approve(address(wallet), amount);
        vm.stopPrank();

        uint256 initialBalance1 = mockToken.balanceOf(user1);
        uint256 initialBalance2 = mockToken.balanceOf(user2);

        // Wallet delegates the transfer action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transfer, (mockToken, amount, user1, user2)));

        assertEq(mockToken.balanceOf(user1), initialBalance1 - amount);
        assertEq(mockToken.balanceOf(user2), initialBalance2 + amount);
    }

    function test_transfer_accountBalance() public {
        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, 500e18);
        uint256 userBalance = mockToken.balanceOf(user1);
        mockToken.approve(address(wallet), userBalance);
        vm.stopPrank();

        uint256 initialBalance2 = mockToken.balanceOf(user2);

        // Wallet delegates the transfer action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transfer, (mockToken, ACCOUNT_BALANCE, user1, user2)));

        assertEq(mockToken.balanceOf(user1), 0);
        assertEq(mockToken.balanceOf(user2), initialBalance2 + userBalance);
    }

    // ========== APPROVE TESTS ==========

    function test_approve_specificAmount() public {
        uint256 amount = 100e18;

        // Wallet delegates the approve action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.approve, (mockToken, amount, spender)));

        assertEq(mockToken.allowance(address(wallet), spender), amount);
    }

    function test_approve_accountBalance() public {
        uint256 walletBalance = mockToken.balanceOf(address(wallet));

        // Wallet delegates the approve action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.approve, (mockToken, ACCOUNT_BALANCE, spender)));

        assertEq(mockToken.allowance(address(wallet), spender), walletBalance);
    }

    // ========== INFINITE APPROVE TESTS ==========

    function test_infiniteApprove() public {
        // Wallet delegates the infiniteApprove action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.infiniteApprove, (mockToken, spender)));

        assertEq(mockToken.allowance(address(wallet), spender), type(uint256).max);
    }

    // ========== DEPOSIT NATIVE TESTS ==========

    function test_depositNative_specificAmount() public {
        uint256 amount = 10 ether;
        uint256 initialBalance = weth.balanceOf(user1);

        // Wallet delegates the depositNative action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (amount, user1)));

        assertEq(weth.balanceOf(user1), initialBalance + amount);
        assertEq(address(wallet).balance, 90 ether); // 100 - 10
    }

    function test_depositNative_accountBalance() public {
        uint256 walletBalance = address(wallet).balance;
        uint256 initialBalance = weth.balanceOf(user1);

        // Wallet delegates the depositNative action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (ACCOUNT_BALANCE, user1)));

        assertEq(weth.balanceOf(user1), initialBalance + walletBalance);
        assertEq(address(wallet).balance, 0);
    }

    // ========== WITHDRAW NATIVE TESTS ==========

    function test_withdrawNative_specificAmount() public {
        // First deposit some WETH to the wallet
        wallet.delegate{ value: 10 ether }(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (10 ether, address(wallet))));

        uint256 amount = 5 ether;
        uint256 initialBalance = user1.balance;

        // Wallet delegates the withdrawNative action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.withdrawNative, (amount, payable(user1))));

        assertEq(user1.balance, initialBalance + amount);
        assertEq(weth.balanceOf(address(wallet)), 5 ether);
    }

    function test_withdrawNative_accountBalance() public {
        uint256 wethBalance = weth.balanceOf(address(wallet));
        uint256 initialBalance = user1.balance;

        // Wallet delegates the withdrawNative action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.withdrawNative, (ACCOUNT_BALANCE, payable(user1))));

        assertEq(user1.balance, initialBalance + wethBalance);
        assertEq(weth.balanceOf(address(wallet)), 0);
    }

    // ========== TRANSFER NATIVE TESTS ==========

    function test_transferNative_specificAmount() public {
        uint256 amount = 5 ether;
        uint256 initialBalance = user1.balance;
        uint256 initialWalletBalance = address(wallet).balance;

        vm.expectEmit(true, false, false, true);
        emit TokenAction.NativeTransfer(user1, amount);

        // Wallet delegates the transferNative action
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (amount, payable(user1))));

        assertEq(user1.balance, initialBalance + amount);
        assertEq(address(wallet).balance, initialWalletBalance - amount);
    }

    function test_transferNative_accountBalance() public {
        uint256 walletBalance = address(wallet).balance;
        uint256 initialBalance = user1.balance;

        vm.expectEmit(true, false, false, true);
        emit TokenAction.NativeTransfer(user1, walletBalance);

        // Wallet delegates the transferNative action with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (ACCOUNT_BALANCE, payable(user1))));

        assertEq(user1.balance, initialBalance + walletBalance);
        assertEq(address(wallet).balance, 0);
    }

    // ========== EDGE CASES ==========

    function test_pull_zeroAmount() public {
        vm.startPrank(user1);
        mockToken.mint(user1, 0);
        mockToken.approve(address(wallet), 0);
        vm.stopPrank();

        uint256 initialBalance = mockToken.balanceOf(address(wallet));

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, 0, user1, false)));

        assertEq(mockToken.balanceOf(address(wallet)), initialBalance);
    }

    function test_push_zeroAmount() public {
        uint256 initialBalance = mockToken.balanceOf(user2);

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.push, (mockToken, 0, user2)));

        assertEq(mockToken.balanceOf(user2), initialBalance);
    }

    function test_transfer_sameAddress() public {
        uint256 amount = 100e18;

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        mockToken.approve(address(wallet), amount);
        uint256 initialBalance = mockToken.balanceOf(user1);
        vm.stopPrank();

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transfer, (mockToken, amount, user1, user1)));

        assertEq(mockToken.balanceOf(user1), initialBalance); // No change
    }

    function test_depositNative_zeroAmount() public {
        uint256 initialBalance = weth.balanceOf(user1);

        wallet.delegate{ value: 0 }(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (0, user1)));

        assertEq(weth.balanceOf(user1), initialBalance);
    }

    function test_withdrawNative_zeroAmount() public {
        uint256 initialBalance = user1.balance;

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.withdrawNative, (0, payable(user1))));

        assertEq(user1.balance, initialBalance);
    }

    // ========== REVERT TESTS ==========

    function test_pull_insufficientAllowance() public {
        vm.startPrank(user1);
        mockToken.mint(user1, 100e18);
        mockToken.approve(address(wallet), 50e18); // Less than requested
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(wallet), 50e18, 100e18));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, 100e18, user1, false)));
    }

    function test_pull_insufficientBalance() public {
        vm.startPrank(user1);
        mockToken.mint(user1, 50e18);
        mockToken.approve(address(wallet), 100e18);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user1, 50e18, 100e18));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, 100e18, user1, false)));
    }

    function test_push_insufficientBalance() public {
        // Wallet has 1000e18 tokens, try to push more
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, wallet, 1000e18, 2000e18));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.push, (mockToken, 2000e18, user2)));
    }

    function test_transfer_insufficientAllowance() public {
        vm.startPrank(user1);
        mockToken.mint(user1, 100e18);
        mockToken.approve(address(wallet), 50e18); // Less than requested
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(wallet), 50e18, 100e18));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transfer, (mockToken, 100e18, user1, user2)));
    }

    function test_depositNative_insufficientValue() public {
        uint256 walletBalance = address(wallet).balance;

        vm.expectRevert(
            abi.encodeWithSelector(ERC20Lib.InsufficientNativeBalance.selector, walletBalance + 5 ether, walletBalance + 10 ether)
        );
        wallet.delegate{ value: 5 ether }(
            address(tokenAction), abi.encodeCall(TokenAction.depositNative, (walletBalance + 10 ether, user1))
        );
    }

    function test_withdrawNative_insufficientWethBalance() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20Lib.InsufficientBalance.selector, weth, 0, 10 ether));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.withdrawNative, (10 ether, payable(user1))));
    }

    function test_transferNative_insufficientBalance() public {
        uint256 walletBalance = address(wallet).balance;
        vm.expectRevert(abi.encodeWithSelector(ERC20Lib.InsufficientNativeBalance.selector, walletBalance, 200 ether));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (200 ether, payable(user1))));
    }

    // ========== EVENT TESTS ==========

    function test_transferNative_emitsEvent() public {
        uint256 amount = 5 ether;

        vm.expectEmit(true, false, false, true);
        emit TokenAction.NativeTransfer(user1, amount);

        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (amount, payable(user1))));
    }

    // ========== ADDITIONAL EDGE CASES ==========

    function test_pullWithPermit_invalidVersion() public {
        uint256 amount = 100e18;

        // Create permit with invalid version
        EIP2098Permit memory permit = EIP2098Permit({
            amount: amount,
            deadline: block.timestamp + 1 hours,
            r: bytes32(0),
            vs: bytes32(0),
            version: 3 // Invalid version
        });

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ERC20Lib.InvalidPermitVersion.selector, 3));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pullWithPermit, (mockToken, amount, user1, permit)));
    }

    function test_transfer_toZeroAddress() public {
        uint256 amount = 100e18;

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        mockToken.approve(address(wallet), amount);
        vm.stopPrank();

        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transfer, (mockToken, amount, user1, address(0))));
    }

    function test_push_toZeroAddress() public {
        uint256 amount = 50e18;

        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.push, (mockToken, amount, address(0))));
    }

    function test_approve_zeroSpender() public {
        uint256 amount = 100e18;

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.approve, (mockToken, amount, address(0))));
    }

    function test_infiniteApprove_zeroSpender() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.infiniteApprove, (mockToken, address(0))));
    }

    function test_depositNative_toZeroAddress() public {
        uint256 amount = 10 ether;

        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        wallet.delegate{ value: amount }(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (amount, address(0))));
    }

    function test_withdrawNative_toZeroAddress() public {
        // First deposit some WETH to the wallet
        wallet.delegate{ value: 10 ether }(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (10 ether, address(wallet))));

        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.withdrawNative, (5 ether, payable(address(0)))));
    }

    function test_transferNative_toZeroAddress() public {
        uint256 amount = 5 ether;

        vm.expectRevert(ERC20Lib.ZeroDestination.selector);
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (amount, payable(address(0)))));
    }

    function test_pull_fromZeroAddress() public {
        uint256 amount = 100e18;

        vm.expectRevert(ERC20Lib.ZeroPayer.selector);
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pull, (mockToken, amount, address(0), false)));
    }

    function test_transfer_fromZeroAddress() public {
        uint256 amount = 100e18;

        vm.expectRevert(ERC20Lib.ZeroPayer.selector);
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transfer, (mockToken, amount, address(0), user2)));
    }

    function test_pullWithPermit_expiredDeadline() public {
        uint256 amount = 100e18;

        // Create permit with expired deadline
        EIP2098Permit memory permit = signPermit(mockToken, user1, user1Pk, amount, address(wallet));
        vm.warp(permit.deadline + 1);

        // User1 gets some tokens
        vm.startPrank(user1);
        mockToken.mint(user1, amount);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, permit.deadline));
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.pullWithPermit, (mockToken, amount, user1, permit)));
    }

    function test_approve_accountBalance_whenWalletHasNoTokens() public {
        // Wallet has no tokens initially
        uint256 walletBalance = mockToken.balanceOf(address(wallet));
        assertEq(walletBalance, 1000e18); // From setUp

        // Approve with ACCOUNT_BALANCE
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.approve, (mockToken, ACCOUNT_BALANCE, spender)));

        assertEq(mockToken.allowance(address(wallet), spender), walletBalance);
    }

    function test_depositNative_accountBalance_whenWalletHasNoEth() public {
        // Drain wallet's ETH
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (100 ether, payable(user1))));
        assertEq(address(wallet).balance, 0);

        uint256 initialBalance = weth.balanceOf(user1);

        // Try to deposit with ACCOUNT_BALANCE when wallet has no ETH
        wallet.delegate{ value: 0 }(address(tokenAction), abi.encodeCall(TokenAction.depositNative, (ACCOUNT_BALANCE, user1)));

        assertEq(weth.balanceOf(user1), initialBalance);
    }

    function test_withdrawNative_accountBalance_whenWalletHasNoWeth() public {
        // Wallet has no WETH initially
        uint256 wethBalance = weth.balanceOf(address(wallet));
        assertEq(wethBalance, 0);

        uint256 initialBalance = user1.balance;

        // Try to withdraw with ACCOUNT_BALANCE when wallet has no WETH
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.withdrawNative, (ACCOUNT_BALANCE, payable(user1))));

        assertEq(user1.balance, initialBalance);
    }

    function test_transferNative_accountBalance_whenWalletHasNoEth() public {
        // Drain wallet's ETH
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (100 ether, payable(user1))));
        assertEq(address(wallet).balance, 0);

        uint256 initialBalance = user1.balance;

        // Try to transfer with ACCOUNT_BALANCE when wallet has no ETH
        wallet.delegate(address(tokenAction), abi.encodeCall(TokenAction.transferNative, (ACCOUNT_BALANCE, payable(user1))));

        assertEq(user1.balance, initialBalance);
    }

}
