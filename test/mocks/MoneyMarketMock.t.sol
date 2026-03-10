// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { MoneyMarketMock } from "./MoneyMarketMock.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MoneyMarketMockTest is Test {

    MoneyMarketMock moneyMarket;
    ERC20Mock token;

    address user = address(0xdead);
    uint256 constant INITIAL_BALANCE = 100e18;

    function setUp() public {
        moneyMarket = new MoneyMarketMock(3.2e18); // 3.2% APY

        token = new ERC20Mock();

        // Setup user with initial balance
        token.mint(user, INITIAL_BALANCE);
        vm.startPrank(user);
        token.approve(address(moneyMarket), type(uint256).max);
        vm.stopPrank();
    }

    function testSupplyAndWithdraw() public {
        vm.startPrank(user);

        // Supply tokens
        moneyMarket.supply(token, 50e18);
        assertEq(token.balanceOf(address(moneyMarket)), 50e18, "Market should have received tokens");
        assertEq(token.balanceOf(user), 50e18, "User balance should have decreased");

        // Withdraw tokens immediately (no interest accrued)
        moneyMarket.withdraw(token, 50e18, user);
        assertEq(token.balanceOf(user), INITIAL_BALANCE, "User should have received tokens back");
        assertEq(token.balanceOf(address(moneyMarket)), 0, "Market should have zero balance");

        vm.stopPrank();
    }

    function testInterestAccrual() public {
        vm.startPrank(user);
        moneyMarket.supply(token, 100e18);

        // Move forward 1 year (approximately)
        vm.warp(block.timestamp + 365 days);

        // Check balance with accrued interest (~3.2% APY)
        uint256 balance = moneyMarket.collateralBalance(user, token);
        assertApproxEqRel(
            balance,
            103.2e18, // Expected balance after 1 year
            0.001e18 // 0.1% tolerance
        );

        // Withdraw accrued balance
        moneyMarket.withdraw(token, balance, user);
        assertApproxEqRel(token.balanceOf(user), 103.2e18, 0.001e18);

        vm.stopPrank();
    }

    function testMultipleSuppliesWithInterest() public {
        vm.startPrank(user);

        // First supply
        moneyMarket.supply(token, 50e18);

        // Wait 6 months
        vm.warp(block.timestamp + 182 days);

        // Second supply
        moneyMarket.supply(token, 50e18);

        // Wait another 6 months
        vm.warp(block.timestamp + 182 days);

        uint256 balance = moneyMarket.collateralBalance(user, token);
        // First 50e18 should accrue interest for 1 year (~1.6e18)
        // Second 50e18 should accrue interest for 6 months (~0.8e18)
        assertApproxEqRel(
            balance,
            102.4e18, // Expected: 100e18 + 1.6e18 + 0.8e18
            0.001e18
        );

        vm.stopPrank();
    }

    function testZeroBalanceRemovesToken() public {
        vm.startPrank(user);

        moneyMarket.supply(token, 100e18);
        vm.warp(block.timestamp + 365 days);

        uint256 balance = moneyMarket.collateralBalance(user, token);
        moneyMarket.withdraw(token, balance, user);

        // Supply again to verify tracking works after removal
        vm.warp(block.timestamp + 365 days);
        moneyMarket.supply(token, 50e18);

        assertApproxEqRel(moneyMarket.collateralBalance(user, token), 50e18, 0.001e18);

        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawingMoreThanBalance() public {
        vm.startPrank(user);
        moneyMarket.supply(token, 100e18);

        vm.expectRevert("Insufficient balance");
        moneyMarket.withdraw(token, 101e18, user);
        vm.stopPrank();
    }

    function testAPYCalculation() public {
        // Test with different APY values
        uint256[] memory apys = new uint256[](3);
        apys[0] = 3.2e18; // 3.2%
        apys[1] = 10e18; // 10%
        apys[2] = 20e18; // 20%

        for (uint256 i = 0; i < apys.length; i++) {
            uint256 apy = apys[i];
            moneyMarket.setAPY(apy);

            vm.startPrank(user);
            moneyMarket.supply(token, 100e18);

            // Move forward 1 year
            vm.warp(block.timestamp + 365 days);

            uint256 balance = moneyMarket.collateralBalance(user, token);
            uint256 expectedBalance = 100e18 + (100e18 * apy / 100e18);

            console.log("APY: %, Expected: %, Actual: %", apy / 1e16, expectedBalance / 1e18, balance / 1e18);

            assertApproxEqRel(
                balance,
                expectedBalance,
                0.005e18, // 0.5% tolerance - slightly higher due to compound interest effects
                string.concat("APY calculation failed for ", vm.toString(apy / 1e16), "%")
            );

            // Clean up for next test
            moneyMarket.withdraw(token, balance, user);
            vm.stopPrank();
            vm.warp(block.timestamp + 1); // Reset time
        }
    }

}
