//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { SUPPLIED_BALANCE } from "../../src/constants.sol";
import { MorphoMoneyMarket, IMorpho, MorphoMarketId, MarketParams, Market } from "../../src/moneymarkets/morpho/MorphoMoneyMarket.sol";

contract MorphoMoneyMarketTest is BaseTest {

    MorphoMarketId marketId = MorphoMarketId.wrap(0xb374528d44b6ab6e0cecc87e0481f45d892f38baec90c1d318851969ec14ea5f);
    IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    IERC20 sUSDS = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    MorphoMoneyMarket morphoMoneyMarket;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        morphoMoneyMarket = new MorphoMoneyMarket();
    }

    function test_supplyWithdrawLoan_partial() public {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        IERC20 loanToken = sUSDS;
        uint256 amount = 100e18;
        uint256 withdrawAmount = 10e18;

        deal(address(loanToken), address(morphoMoneyMarket), amount);
        morphoMoneyMarket.supplyLoan(amount, loanToken, marketId, morpho);

        uint256 loanBefore = morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho);
        assertApproxEqAbs(loanBefore, amount, 1, "loan supply failed");

        skipWithBlock(30 days);
        morpho.accrueInterest(marketParams);

        uint256 loanAfter = morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho);
        assertGt(loanAfter, loanBefore, "loan supply should accrue interest");

        morphoMoneyMarket.withdrawLoan(withdrawAmount, loanToken, address(this), marketId, morpho);

        assertApproxEqAbs(loanToken.balanceOf(address(this)), withdrawAmount, 1, "loan withdraw amount mismatch");
        assertLt(
            morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho),
            loanAfter,
            "loan position should decrease after withdraw"
        );
    }

    function test_supplyWithdrawLoan_full() public {
        sUSDS.balanceOf(address(morpho));
        morpho.market(marketId);
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        IERC20 loanToken = sUSDS;
        uint256 amount = 100e18;

        deal(address(loanToken), address(morphoMoneyMarket), amount);
        morphoMoneyMarket.supplyLoan(amount, loanToken, marketId, morpho);

        uint256 loanBefore = morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho);
        assertApproxEqAbs(loanBefore, amount, 1, "loan supply failed");

        skipWithBlock(30 days);
        morpho.accrueInterest(marketParams);

        uint256 loanAfter = morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho);
        assertGt(loanAfter, loanBefore, "loan supply should accrue interest");

        morphoMoneyMarket.withdrawLoan(SUPPLIED_BALANCE, loanToken, address(this), marketId, morpho);

        assertGt(loanToken.balanceOf(address(this)), amount, "full withdraw mismatch");
        assertEq(morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho), 0, "loan position should be empty");
    }

    function test_supplyWithdrawLoan_over() public {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        IERC20 loanToken = sUSDS;
        uint256 amount = 100e18;

        deal(address(loanToken), address(morphoMoneyMarket), amount);
        morphoMoneyMarket.supplyLoan(amount, loanToken, marketId, morpho);

        uint256 loanBefore = morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho);
        assertApproxEqAbs(loanBefore, amount, 1, "loan supply failed");

        skipWithBlock(30 days);
        morpho.accrueInterest(marketParams);

        uint256 loanAfter = morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho);
        assertGt(loanAfter, loanBefore, "loan supply should accrue interest");

        morphoMoneyMarket.withdrawLoan(amount + 1e18, loanToken, address(this), marketId, morpho);

        assertGt(loanToken.balanceOf(address(this)), amount, "over withdraw should cap to max withdrawable");
        assertEq(morphoMoneyMarket.loanBalance(address(morphoMoneyMarket), loanToken, marketId, morpho), 0, "loan position should be empty");
    }

}
