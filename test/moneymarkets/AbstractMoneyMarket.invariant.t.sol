//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { BaseTest } from "../BaseTest.t.sol";
import { BytesLib } from "../../src/libraries/BytesLib.sol";
import { console3 } from "../console3.sol";
import { ACCOUNT_BALANCE, DEBT_BALANCE, COLLATERAL_BALANCE, RAY } from "../../src/constants.sol";
import { ActionExecutor } from "../../src/modules/ActionExecutor.sol";
import { OwnableExecutor } from "../../src/modules/OwnableExecutor.sol";
import { Action } from "../../src/types/Action.sol";
import { MathLib } from "../../src/libraries/MathLib.sol";

struct MoneyMarket {
    address instance;
    function() external returns (uint256) collateralBalance;
    function() external returns (uint256) debtBalance;
    function(uint256) external returns (Action memory) supply;
    function(uint256) external returns (Action memory) borrow;
    function(uint256) external returns (Action memory) repay;
    function(uint256) external returns (Action memory) withdraw;
    function() external returns (uint256, uint256, uint256) prices;
    function() external returns (uint256, uint256) thresholds;
    function(uint256, uint256) external returns (uint256, uint256) unscaleAmounts;
    function(Vm.Log[] memory, uint256, uint256) external returns (uint256, uint256) logAccounting;
    function(address) external enableCollateral;
    function(address) external enableDebt;
    function() external returns (uint256) borrowLiquidity;
}

struct MoneyMarketHandlerParams {
    address owner;
    uint256 ownerPk;
    address account;
    ActionExecutor actionExecutor;
    OwnableExecutor ownableExecutor;
    MoneyMarket moneyMarket;
    IERC20 base;
    uint256 baseDecimals;
    IERC20 quote;
    uint256 quoteDecimals;
    uint256 minWithdrawal;
    uint256 minDeposit;
    uint256 minBorrowing;
    uint256 minRepay;
    uint256 minDebt;
    function(address, address, Action[] memory) external executeActions;
}

library MoneyMarketLib {

    using Address for address;

    function callUint(function() external returns (Action memory) fn) internal returns (uint256) {
        Action memory call = fn();
        return abi.decode(call.target.functionCall(call.data), (uint256));
    }

    function callUintTuple(function() external returns (Action memory) fn) internal returns (uint256, uint256) {
        Action memory call = fn();
        return abi.decode(call.target.functionCall(call.data), (uint256, uint256));
    }

    function callUintTuple3(function() external returns (Action memory) fn) internal returns (uint256, uint256, uint256) {
        Action memory call = fn();
        return abi.decode(call.target.functionCall(call.data), (uint256, uint256, uint256));
    }

    function delegateAction(function(uint256) external returns (Action memory) fn, uint256 amount) internal {
        Action memory call = fn(amount);
        require(call.delegateCall, "Not a delegate call");
        call.target.functionDelegateCall(call.data);
    }

}

abstract contract AbstractMoneyMarketInvariantTest is BaseTest {

    using Address for address;
    using MoneyMarketLib for *;
    using SafeCast for uint256;

    address internal owner;
    uint256 internal ownerPk;
    IERC20 internal base;
    uint256 internal baseDecimals;
    IERC20 internal quote;
    uint256 internal quoteDecimals;
    uint256 internal baseAmount = 10 ether;
    uint256 internal quoteAmount;
    uint256 internal toleranceUnit = 1;
    uint256 internal minWithdrawal = 0;
    uint256 internal minDeposit = 0;
    uint256 internal minBorrowing = 0;
    uint256 internal minRepay = 0;
    uint256 internal minDebt = 0;
    address internal account;
    uint256 internal indexScale = RAY;

    MoneyMarketHandler private handler;
    MoneyMarket private moneyMarket;

    bool public useSharesForDebt = true;

    bytes4[] private selectors;

    enum LotType {
        Collateral,
        Debt
    }

    struct Lot {
        LotType lotType;
        uint256 amount;
        uint256 shares;
        uint256 index;
        uint256 unrealisedPnL;
        uint256 realisedPnL;
    }

    Lot[] public lots;

    function setUp(IERC20 _base, IERC20 _quote, MoneyMarket memory _moneyMarket) internal {
        base = _base;
        baseDecimals = IERC20Metadata(address(base)).decimals();
        quote = _quote;
        quoteDecimals = IERC20Metadata(address(quote)).decimals();
        quoteAmount = 1000 * 10 ** quoteDecimals;

        (owner, ownerPk) = makeAddrAndKey("owner");
        account = newAccount(owner);
        vm.label(account, "Account");

        moneyMarket = _moneyMarket;

        deal(address(base), account, baseAmount);
        deal(address(quote), account, quoteAmount);

        handler = new MoneyMarketHandler(
            MoneyMarketHandlerParams({
                owner: owner,
                ownerPk: ownerPk,
                account: account,
                actionExecutor: actionExecutor,
                ownableExecutor: ownableExecutor,
                moneyMarket: moneyMarket,
                base: base,
                baseDecimals: baseDecimals,
                quote: quote,
                quoteDecimals: quoteDecimals,
                minWithdrawal: minWithdrawal,
                minDeposit: minDeposit,
                minBorrowing: minBorrowing,
                minRepay: minRepay,
                minDebt: minDebt,
                executeActions: this._executeActions
            })
        );

        targetSender(owner);
        targetContract(address(handler));
        selectors.push(handler.deposit.selector);
        selectors.push(handler.withdraw.selector);
        selectors.push(handler.borrow.selector);
        selectors.push(handler.repay.selector);
        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariant_accounting() public {
        uint256 collateralRealisedPnl = 0;
        uint256 debtRealisedPnl = 0;
        uint256 debtTrackedUnrealisedPnl = 0;
        uint256 outstandingPrincipal = 0;
        uint256 outstandingDebt = 0;
        for (uint256 i = 0; i < lots.length; i++) {
            Lot memory lot = lots[i];

            if (lot.lotType == LotType.Collateral) {
                outstandingPrincipal += Math.mulDiv(lot.shares, lot.index, indexScale);
                collateralRealisedPnl += lot.realisedPnL;
            } else if (lot.lotType == LotType.Debt) {
                outstandingDebt += useSharesForDebt ? Math.mulDiv(lot.shares, lot.index, indexScale) : lot.shares;
                debtRealisedPnl += lot.realisedPnL;
                debtTrackedUnrealisedPnl += lot.unrealisedPnL;
            }
        }
        uint256 collateralBalance = moneyMarket.collateralBalance();
        uint256 debtBalance = moneyMarket.debtBalance();

        // ================================ Totals Accounting ================================

        (uint256 loggedCollateral, uint256 loggedDebt) = moneyMarket.unscaleAmounts(handler.collateralShares(), handler.debtShares());

        // Ignore small collaterals as rounding errors look huge
        if (collateralBalance > 0.0001e18) {
            assertApproxEqRelDecimal(loggedCollateral, collateralBalance, 0.00001e18, baseDecimals, "unscaled collateral differs");
        }

        // Ignore small debts as rounding errors look huge
        if (debtBalance > 10e18) assertApproxEqRelDecimal(loggedDebt, debtBalance, 0.00001e18, quoteDecimals, "unscaled debt differs");

        // ================================ Lots Accounting ================================

        uint256 collateralUnrealisedPnl = collateralBalance > outstandingPrincipal ? collateralBalance - outstandingPrincipal : 0; // Deal with rounding/dust
        uint256 totalCollateralPnl = collateralRealisedPnl + collateralUnrealisedPnl;
        uint256 debtComputedUnrealisedPnl = debtBalance > outstandingDebt ? debtBalance - outstandingDebt : 0; // Deal with rounding/dust
        uint256 totalDebtPnl = debtRealisedPnl + debtComputedUnrealisedPnl + debtTrackedUnrealisedPnl;

        uint256 totalCollateralBalance = collateralBalance + base.balanceOf(account);
        uint256 collateralDiffPnl = totalCollateralBalance > baseAmount ? totalCollateralBalance - baseAmount : 0; // Deal with rounding/dust
        uint256 debtDiffPnl = MathLib.abs(quote.balanceOf(account).toInt256() - debtBalance.toInt256() - quoteAmount.toInt256());

        if (collateralDiffPnl > 0.0001 ether) {
            assertApproxEqRelDecimal(totalCollateralPnl, collateralDiffPnl, 0.00001e18, baseDecimals, "collateral pnl differs");
        }
        if (debtDiffPnl > 0.1e18) assertApproxEqRelDecimal(totalDebtPnl, debtDiffPnl, 0.00001e18, quoteDecimals, "debt pnl differs");

        // ================================ Call Summary ================================

        handler.callSummary();
    }

    function _closeShares(LotType target, uint256 shares, uint256 index) internal {
        uint256 totalSharesToClose = shares;

        for (uint256 i = 0; i < lots.length; i++) {
            Lot storage lot = lots[i];
            if (lot.lotType == target) {
                if (lot.shares == 0) continue;

                uint256 sharesToClose = Math.min(totalSharesToClose, lot.shares);
                totalSharesToClose -= sharesToClose;
                lot.shares -= sharesToClose;

                uint256 presentValueOfClose = Math.mulDiv(sharesToClose, index, indexScale);
                uint256 pastValueOfClose = Math.mulDiv(sharesToClose, lot.index, indexScale);
                uint256 realisedPnL = presentValueOfClose > pastValueOfClose ? presentValueOfClose - pastValueOfClose : 0; // rounding issues
                lot.realisedPnL += realisedPnL;

                if (totalSharesToClose == 0) break;
            }
        }
    }

    function _closeDebt(uint256 amount, uint256 index) internal {
        uint256 totalDebtToClose = amount;

        for (uint256 i = 0; i < lots.length; i++) {
            Lot storage lot = lots[i];
            if (lot.lotType == LotType.Debt) {
                if (lot.shares == 0) continue;

                uint256 unrealisedPnl = Math.mulDiv(lot.shares, index, lot.index, Math.Rounding.Ceil) - lot.shares;
                lot.shares += unrealisedPnl;
                lot.index = index;

                if (totalDebtToClose > 0) {
                    uint256 sharesToClose = Math.min(totalDebtToClose, lot.shares);
                    totalDebtToClose -= sharesToClose;

                    uint256 repaymentRatio = sharesToClose * 1e18 / lot.shares;
                    uint256 realisedPnL = unrealisedPnl * repaymentRatio / 1e18;

                    lot.realisedPnL += realisedPnL;
                    lot.shares -= sharesToClose;
                    lot.unrealisedPnL += unrealisedPnl - realisedPnL;
                } else {
                    lot.unrealisedPnL += unrealisedPnl;
                }
            }
        }
    }

}

contract MoneyMarketHandler is StdCheats, StdUtils {

    using Address for address;
    using BytesLib for bytes;
    using MoneyMarketLib for *;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IERC20 internal immutable base;
    uint256 internal immutable baseUnit;
    uint256 internal immutable baseDecimals;
    IERC20 internal immutable quote;
    uint256 internal immutable quoteUnit;
    uint256 internal immutable quoteDecimals;
    uint256 internal immutable minWithdrawal;
    uint256 internal immutable minDeposit;
    uint256 internal immutable minBorrowing;
    uint256 internal immutable minRepay;
    uint256 internal immutable minDebt;

    address internal owner;
    uint256 internal ownerPk;
    address internal account;
    ActionExecutor internal actionExecutor;
    OwnableExecutor internal ownableExecutor;
    MoneyMarket internal moneyMarket;
    function(address, address, Action[] memory) external executeActions;

    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalBorrowed;
    uint256 public ghost_totalRepaid;

    uint256 public ghost_advancedTime;

    uint256 public ghost_zeroDeposits;
    uint256 public ghost_zeroWithdrawals;
    uint256 public ghost_zeroBorrowed;
    uint256 public ghost_zeroRepaid;
    uint256 public ghost_overRepaid;
    uint256 public ghost_maxBorrowed;
    Action[] internal calls;
    mapping(bytes32 => uint256) public callCounter;

    uint256 public collateralShares;
    uint256 public debtShares;

    constructor(MoneyMarketHandlerParams memory params) {
        owner = params.owner;
        ownerPk = params.ownerPk;
        account = params.account;
        actionExecutor = params.actionExecutor;
        ownableExecutor = params.ownableExecutor;
        moneyMarket = params.moneyMarket;
        executeActions = params.executeActions;

        base = params.base;
        quote = params.quote;
        baseUnit = 10 ** params.baseDecimals;
        quoteUnit = 10 ** params.quoteDecimals;
        baseDecimals = params.baseDecimals;
        quoteDecimals = params.quoteDecimals;
        minWithdrawal = params.minWithdrawal;
        minDeposit = params.minDeposit;
        minRepay = params.minRepay;
        minDebt = params.minDebt;
        minBorrowing = params.minBorrowing;
    }

    modifier countCall(bytes32 key) {
        callCounter[key]++;
        _;
    }

    modifier inTime(uint256 s) {
        _;
        if (s > 0) {
            s = _bound(s, 1 minutes, 1 days);
            advanceTime(s);
        }
    }

    function advanceTime(uint256 s) public {
        skip(s);
        vm.roll(block.number + s / 12);
        ghost_advancedTime += s;
    }

    function _execute() internal {
        vm.recordLogs();

        executeActions(account, owner, calls);
        delete calls;

        (collateralShares, debtShares) = moneyMarket.logAccounting(vm.getRecordedLogs(), collateralShares, debtShares);
    }

    function _collateralBalance() internal returns (uint256) {
        return moneyMarket.collateralBalance();
    }

    function _debtBalance() internal returns (uint256) {
        return moneyMarket.debtBalance();
    }

    function _prices() internal returns (uint256 collateral, uint256 debt, uint256 unit) {
        (collateral, debt, unit) = moneyMarket.prices();
    }

    function _thresholds() internal returns (uint256 ltv, uint256 liquidationThreshold) {
        (ltv, liquidationThreshold) = moneyMarket.thresholds();
    }

    function deposit(uint256 amount, uint256 ts) external countCall("deposit") inTime(ts) {
        uint256 balance = base.balanceOf(account);
        amount = baseUnit > balance ? ACCOUNT_BALANCE : _bound(amount, baseUnit, balance);

        if (amount == 0) ghost_zeroDeposits++;
        if (minDeposit > 0 && amount < minDeposit) {
            ghost_zeroDeposits++;
            return;
        }
        if (amount == ACCOUNT_BALANCE && balance < minDeposit) {
            ghost_zeroDeposits++;
            return;
        }

        uint256 collateralBalance = _collateralBalance();

        calls.push(moneyMarket.supply(amount));
        _execute();
        ghost_totalDeposited += _collateralBalance() - collateralBalance;
        // TODO: Should we check that the amount is the same as the amount deposited? or maybe greater or equal?

        if (callCounter["deposit"] == 1) moneyMarket.enableCollateral(account);
    }

    function _ltv() internal returns (uint256) {
        (uint256 ltv, uint256 liquidationThreshold) = _thresholds();
        if (ltv == liquidationThreshold) return ltv * 0.975e18 / 1e18;
        return ltv * 0.9975e18 / 1e18;
    }

    function withdraw(uint256 amount, uint256 ts) external countCall("withdraw") inTime(ts) {
        uint256 collateralBalance = _collateralBalance();
        uint256 debtBalance = _debtBalance();
        {
            if (collateralBalance == 0) {
                ghost_zeroWithdrawals++;
                return;
            }

            (uint256 collateral, uint256 debt,) = _prices();

            uint256 debtValue_priceUnit = debtBalance * debt / quoteUnit;
            uint256 requiredCollateralValue_priceUnit = debtValue_priceUnit * 1e18 / _ltv();
            uint256 requiredCollateralBaseUnit = requiredCollateralValue_priceUnit * baseUnit / collateral + 1;

            uint256 available = collateralBalance > requiredCollateralBaseUnit ? collateralBalance - requiredCollateralBaseUnit : 0;

            amount = baseUnit > available ? available : _bound(amount, baseUnit, available);
            if (amount < minWithdrawal) {
                ghost_zeroWithdrawals++;
                return;
            }
        }

        if (amount == 0) ghost_zeroWithdrawals++;

        calls.push(moneyMarket.withdraw(amount));
        _execute();

        ghost_totalWithdrawn += collateralBalance - _collateralBalance();
    }

    function borrow(uint256 amount, uint256 ts) external countCall("borrow") inTime(ts) {
        if (callCounter["borrow"] == 1) moneyMarket.enableDebt(account);

        uint256 collateralBalance = _collateralBalance();
        uint256 debtBalance = _debtBalance();
        {
            if (collateralBalance == 0) {
                ghost_zeroBorrowed++;
                return;
            }
            (uint256 collateral, uint256 debt, uint256 unit) = _prices();

            uint256 collateralValue_priceUnit = collateralBalance * collateral / baseUnit;
            uint256 maxDebtValue_priceUnit = collateralValue_priceUnit * _ltv() / 1e18;
            uint256 maxDebtAmount_priceUnit = maxDebtValue_priceUnit * unit / debt;
            // TODO check if this works with 18 decimals too
            uint256 maxDebtAmount_quoteUnit = maxDebtAmount_priceUnit * quoteUnit / unit;

            uint256 available = maxDebtAmount_quoteUnit > debtBalance ? maxDebtAmount_quoteUnit - debtBalance : 0;
            {
                uint256 liquidity = moneyMarket.borrowLiquidity();
                if (available > liquidity) available = liquidity;
            }

            // console.log("collateralValue_priceUnit %s, maxDebtValue_priceUnit %s, maxDebtAmount_priceUnit %s", collateralValue_priceUnit, maxDebtValue_priceUnit, maxDebtAmount_priceUnit);
            // console.log("maxDebtAmount_quoteUnit %s, debtBalance %s, available %s", maxDebtAmount_quoteUnit, debtBalance, available);

            if (available < minBorrowing) {
                ghost_zeroBorrowed++;
                return;
            }
            amount = quoteUnit > available ? available : _bound(amount, quoteUnit, available);
            if (amount + debtBalance < minBorrowing) {
                amount = minBorrowing - debtBalance;
                if (amount > maxDebtAmount_quoteUnit) {
                    ghost_zeroBorrowed++;
                    return;
                }
            }

            if (amount > 1 && amount + debtBalance == maxDebtAmount_quoteUnit) {
                ghost_maxBorrowed++;
                // Some markets have rounding errors, so we need to subtract 1 to make sure their debt ratio invariant is not violated
                amount--;
            }
        }

        if (amount == 0) ghost_zeroBorrowed++;

        calls.push(moneyMarket.borrow(amount));
        _execute();
        ghost_totalBorrowed += _debtBalance() - debtBalance;
    }

    function repay(uint256 amount, uint256 ts) external countCall("repay") inTime(ts) {
        amount = _bound(amount, 0, quote.balanceOf(account));
        uint256 debtBalance = _debtBalance();

        if (amount == 0) ghost_zeroRepaid++;
        if (amount > debtBalance && amount % 2 == 0) amount = DEBT_BALANCE;
        if (minRepay > 0 && amount < minRepay) {
            ghost_zeroRepaid++;
            return;
        }
        if (minDebt > 0 && amount < debtBalance && debtBalance - amount < minDebt) {
            ghost_zeroRepaid++;
            return;
        }

        calls.push(moneyMarket.repay(amount));
        _execute();
        ghost_totalRepaid += debtBalance - _debtBalance();
    }

    function callSummary() external {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposits", callCounter["deposit"]);
        console.log("withdrawals", callCounter["withdraw"]);
        console.log("borrows", callCounter["borrow"]);
        console.log("repays", callCounter["repay"]);
        console.log("-------------------");
        console3.logDecimal("totalDeposited", ghost_totalDeposited, baseDecimals);
        console3.logDecimal("totalWithdrawn", ghost_totalWithdrawn, baseDecimals);
        console3.logDecimal("totalBorrowed", ghost_totalBorrowed, quoteDecimals);
        console3.logDecimal("totalRepaid", ghost_totalRepaid, quoteDecimals);
        console.log("-------------------");
        console.log("Zero deposits:", ghost_zeroDeposits);
        console.log("Zero withdrawals:", ghost_zeroWithdrawals);
        console.log("Zero borrows:", ghost_zeroBorrowed);
        console.log("Zero repays:", ghost_zeroRepaid);
        console.log("Over repays:", ghost_overRepaid);
        console.log("Max borrowed:", ghost_maxBorrowed);
        console.log("Advanced time:", ghost_advancedTime);
    }

}
