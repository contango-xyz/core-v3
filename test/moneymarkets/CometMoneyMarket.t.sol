//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { SUPPLIED_BALANCE } from "../../src/constants.sol";
import { CometMoneyMarket, IComet } from "../../src/moneymarkets/comet/CometMoneyMarket.sol";

contract CometMoneyMarketTest is BaseTest {

    IComet comet = IComet(0x5D409e56D886231aDAf00c8775665AD0f9897b56);
    IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    CometMoneyMarket cometMoneyMarket;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        cometMoneyMarket = new CometMoneyMarket();
    }

    function test_supplyWithdrawLoan_partial() public {
        IERC20 loanToken = usds;
        uint256 amount = 100e18;
        uint256 withdrawAmount = 10e18;

        deal(address(loanToken), address(cometMoneyMarket), amount);
        cometMoneyMarket.supplyLoan(amount, loanToken, comet);

        uint256 loanBefore = cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet);
        assertApproxEqAbs(loanBefore, amount, 1, "loan supply failed");

        skipWithBlock(30 days);
        comet.accrueAccount(address(cometMoneyMarket));

        uint256 loanAfter = cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet);
        assertGt(loanAfter, loanBefore, "loan supply should accrue interest");

        cometMoneyMarket.withdrawLoan(withdrawAmount, loanToken, address(this), comet);

        assertApproxEqAbs(loanToken.balanceOf(address(this)), withdrawAmount, 1, "loan withdraw amount mismatch");
        assertLt(cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet), loanAfter, "loan position should decrease");
    }

    function test_supplyWithdrawLoan_full() public {
        IERC20 loanToken = usds;
        uint256 amount = 100e18;

        deal(address(loanToken), address(cometMoneyMarket), amount);
        cometMoneyMarket.supplyLoan(amount, loanToken, comet);

        uint256 loanBefore = cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet);
        assertApproxEqAbs(loanBefore, amount, 1, "loan supply failed");

        skipWithBlock(30 days);
        comet.accrueAccount(address(cometMoneyMarket));

        uint256 loanAfter = cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet);
        assertGt(loanAfter, loanBefore, "loan supply should accrue interest");

        cometMoneyMarket.withdrawLoan(SUPPLIED_BALANCE, loanToken, address(this), comet);

        assertGt(loanToken.balanceOf(address(this)), amount, "full withdraw mismatch");
        assertEq(cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet), 0, "loan position should be empty");
    }

    function test_supplyWithdrawLoan_over() public {
        IERC20 loanToken = usds;
        uint256 amount = 100e18;

        deal(address(loanToken), address(cometMoneyMarket), amount);
        cometMoneyMarket.supplyLoan(amount, loanToken, comet);

        uint256 loanBefore = cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet);
        assertApproxEqAbs(loanBefore, amount, 1, "loan supply failed");

        skipWithBlock(30 days);
        comet.accrueAccount(address(cometMoneyMarket));

        uint256 loanAfter = cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet);
        assertGt(loanAfter, loanBefore, "loan supply should accrue interest");

        cometMoneyMarket.withdrawLoan(amount + 1e18, loanToken, address(this), comet);

        assertGt(loanToken.balanceOf(address(this)), amount, "over withdraw should cap to max withdrawable");
        assertEq(cometMoneyMarket.loanBalance(address(cometMoneyMarket), loanToken, comet), 0, "loan position should be empty");
    }

}
