//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { BaseTest } from "../BaseTest.t.sol";
import { SpotMarket } from "../SpotMarket.sol";

import { FlashLoanProvider } from "../FlashLoanProvider.t.sol";

import { ACCOUNT_BALANCE, DEBT_BALANCE, COLLATERAL_BALANCE } from "../../src/constants.sol";

import { FlashLoanAction } from "../../src/flashloan/FlashLoanAction.sol";
import { TokenAction } from "../../src/actions/TokenAction.sol";
import { SwapAction } from "../../src/actions/SwapAction.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { OwnableExecutor } from "../../src/modules/OwnableExecutor.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";
import { Action, PackedAction } from "../../src/types/Action.sol";
import { ActionLib } from "../ActionLib.sol";

/// @dev scenario implementation for https://docs.google.com/spreadsheets/d/1uLRNJOn3uy2PR5H2QJ-X8unBRVCu1Ra51ojMjylPH90/edit#gid=0
abstract contract AbstractPositionLifecycleTest is BaseTest {

    using Address for address;
    using ERC7579Lib for *;
    using ActionLib for *;
    using MessageHashUtils for *;
    using SafeERC20 for IERC20;

    IERC20 internal base = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal quote = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    address internal owner;
    uint256 internal ownerPk;
    address internal treasury = makeAddr("treasury");

    bool internal supportsFlashBorrow = false;
    bool internal supportsFlashWithdraw = false;

    FlashLoanProvider internal flashLoanProvider;
    address internal rootAccount;
    address internal holdingAccount;

    Action[] internal rootActions;
    Action[] internal holdingActions;

    function setUp() public virtual override {
        super.setUp();
        flashLoanProvider = new FlashLoanProvider();

        (owner, ownerPk) = makeAddrAndKey("owner");

        vm.label(address(base), "base");
        vm.label(address(quote), "quote");

        deal(address(base), address(treasury), type(uint128).max);
        deal(address(quote), address(treasury), type(uint128).max);

        vm.startPrank(treasury);
        base.safeTransfer(address(spotMarket), type(uint96).max);
        quote.safeTransfer(address(spotMarket), type(uint96).max);
        base.safeTransfer(address(flashLoanProvider), type(uint96).max);
        quote.safeTransfer(address(flashLoanProvider), type(uint96).max);
        vm.stopPrank();

        rootAccount = newAccount(owner, "RootAccount");
        holdingAccount = newAccount(rootAccount, "HoldingAccount");
    }

    // Borrow 6k, Sell 6k for ~6 ETH
    function testScenario01_FlashLoanQuote() public {
        _fund(base, 4e18);
        _swap(quote, 6000e18, base, 6e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 6000e18);
        } else {
            _borrow(6000e18);
            _flashLoan(quote, 6000e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 6000e18 });
    }

    function testScenario01_FlashLoanBase() public {
        _fund(base, 4e18);
        _supply(ACCOUNT_BALANCE);
        _borrow(6000e18);
        _swap(quote, 6000e18, base, 6e18);
        _flashLoan(base, 6e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 6000e18 });
    }

    // Borrow 6k, Sell 10k for ~10 ETH
    function testScenario02_FlashLoanQuote() public {
        _fund(quote, 4000e18);
        _swap(quote, 10_000e18, base, 10e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 6000e18);
        } else {
            _borrow(6000e18);
            _flashLoan(quote, 6000e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 6000e18 });
    }

    function testScenario02_FlashLoanBase() public {
        _fund(quote, 4000e18);
        _supply(10e18);
        _borrow(6000e18);
        _swap(quote, 10_000e18, base, 10e18);
        _flashLoan(base, 10e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 6000e18 });
    }

    // Borrow 4k, Sell 4k for ~4 ETH
    function testScenario03() public {
        _initialPosition();

        _borrow(4000e18);
        _swap(quote, 4000e18, base, 4e18);
        _supply(ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 10_000e18 });
    }

    // Sell 1k for ~1 ETH
    function testScenario04_FlashLoanQuote() public {
        _initialPosition();

        _swap(quote, 1000e18, base, 1e18);
        _fund(base, 3e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 1000e18);
        } else {
            _borrow(1000e18);
            _flashLoan(quote, 1000e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 7000e18 });
    }

    function testScenario04_FlashLoanBase() public {
        _initialPosition();

        _fund(base, 3e18);
        _supply(4e18); // Prob a tad less to account for slippage
        _borrow(1000e18);
        _swap(quote, 1000e18, base, 1e18);
        _flashLoan(base, 1e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 7000e18 });
    }

    // Just lend 4 ETH, no spot trade needed
    function testScenario05() public {
        _initialPosition();

        _fund(base, 4e18);
        _supply(4e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 6000e18 });
    }

    // Lend 4 ETH & Sell 2 ETH, repay debt with the proceeds
    function testScenario06() public {
        _initialPosition();

        _fund(base, 6e18);
        _swap(base, 2e18, quote, 2000e18);
        _supply(4e18);
        _repay(ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 4000e18 });
    }

    // Sell 2 ETH for ~2k, repay debt with the proceeds
    function testScenario07() public {
        _initialPosition();

        _fund(base, 2e18);
        _swap(base, 2e18, quote, 2000e18);
        _repay(ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 4000e18 });
    }

    // Sell 4k for ~4 ETH but only borrow what the trader's not paying for (borrow 1k)
    function testScenario08_FlashLoanQuote() public {
        _initialPosition();

        _fund(quote, 3000e18);
        _swap(quote, 4000e18, base, 4e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 1000e18);
        } else {
            _borrow(1000e18);
            _flashLoan(quote, 1000e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 7000e18 });
    }

    function testScenario08_FlashLoanBase() public {
        _initialPosition();

        _fund(quote, 3000e18);
        _supply(4e18); // Prob a tad less to account for slippage
        _borrow(1000e18);
        _swap(quote, 4000e18, base, 4e18);
        _flashLoan(base, 4e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 7000e18 });
    }

    // Sell 4k for ~4 ETH, no changes on debt
    function testScenario09() public {
        _initialPosition();

        _fund(quote, 4000e18);
        _swap(quote, 4000e18, base, 4e18);
        _supply(ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 6000e18 });
    }

    // Sell 4k for ~4 ETH & repay debt with 2k excess cashflow
    function testScenario10() public {
        _initialPosition();

        _fund(quote, 6000e18);
        _swap(quote, 4000e18, base, 4e18);
        _supply(ACCOUNT_BALANCE);
        _repay(2000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 4000e18 });
    }

    // Repay debt with cashflow
    function testScenario11() public {
        _initialPosition();

        _fund(quote, 2000e18);
        _repay(2000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 4000e18 });
    }

    // Sell 4.1k for ~4.1 ETH, Withdraw 0.1, Lend ~4 (take 4.1k new debt)
    function testScenario12_FlashLoanQuote() public {
        _initialPosition();

        _swap(quote, 4100e18, base, 4.1e18);
        _push(base, 0.1e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 4100e18);
        } else {
            _borrow(4100e18);
            _flashLoan(quote, 4100e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 10_100e18 });
        _assertOwnerBalances({ wethBalance: 0.1e18, daiBalance: 0 });
    }

    function testScenario12_FlashLoanBase() public {
        _initialPosition();

        _supply(4e18); // Prob a tad less to account for slippage
        _borrow(4100e18);
        _swap(quote, 4100e18, base, 4.1e18);
        _push(base, 0.1e18);
        _flashLoan(base, 4.1e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 10_100e18 });
        _assertOwnerBalances({ wethBalance: 0.1e18, daiBalance: 0 });
    }

    // Sell 2.1k for ~2.1 ETH, Withdraw 1.1, Lend ~1 (take 2.1k new debt)
    function testScenario13_FlashLoanQuote() public {
        _initialPosition();

        _swap(quote, 2100e18, base, 2.1e18);
        _push(base, 1.1e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 2100e18);
        } else {
            _borrow(2100e18);
            _flashLoan(quote, 2100e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 11e18, expectedDebt: 8100e18 });
        _assertOwnerBalances({ wethBalance: 1.1e18, daiBalance: 0 });
    }

    function testScenario13_FlashLoanBase() public {
        _initialPosition();

        _push(base, 1.1e18);
        _supply(ACCOUNT_BALANCE);
        _borrow(2100e18);
        _swap(quote, 2100e18, base, 2.1e18);
        _flashLoan(base, 2.1e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 11e18, expectedDebt: 8100e18 });
        _assertOwnerBalances({ wethBalance: 1.1e18, daiBalance: 0 });
    }

    // Sell 4k for ~4 ETH, Withdraw 100 (take 4.1k new debt)
    function testScenario14_FlashLoanQuote() public {
        _initialPosition();

        _swap(quote, 4000e18, base, 4e18);
        _push(quote, 100e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 4100e18);
        } else {
            _borrow(4100e18);
            _flashLoan(quote, 4100e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 10_100e18 });
    }

    function testScenario14_FlashLoanBase() public {
        _initialPosition();

        _supply(4e18); // Prob a tad less to account for slippage
        _borrow(4100e18);
        _swap(quote, 4000e18, base, 4e18);
        _push(quote, 100e18);
        _flashLoan(base, 4e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 14e18, expectedDebt: 10_100e18 });
    }

    // Sell 1k for ~1 ETH, Withdraw 1.1k (take 2.1k new debt)
    function testScenario15_FlashLoanQuote() public {
        _initialPosition();

        _swap(quote, 1000e18, base, 1e18);
        _push(quote, 1200e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 2200e18);
        } else {
            _borrow(2200e18);
            _flashLoan(quote, 2200e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 11e18, expectedDebt: 8200e18 });
    }

    function testScenario15_FlashLoanBase() public {
        _initialPosition();

        _supply(1e18); // Prob a tad less to account for slippage
        _borrow(2200e18);
        _swap(quote, 1000e18, base, 1e18);
        _push(quote, 1200e18);
        _flashLoan(base, 2.2e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 11e18, expectedDebt: 8200e18 });
    }

    // Sell 4 ETH for ~4k, repay debt with proceeds
    function testScenario16_FlashLoanQuote() public {
        _initialPosition();

        _repay(4000e18);
        _withdraw(4e18);
        _swap(base, 4e18, quote, 4000e18);
        _flashLoan(quote, 4000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 2000e18 });
    }

    function testScenario16_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 4e18, quote, 4000e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 2000e18 });
    }

    // Sell 5 ETH for ~5k, repay debt with proceeds
    function testScenario17_FlashLoanQuote() public {
        _initialPosition();

        _fund(base, 1e18);
        _repay(5000e18);
        _withdraw(4e18);
        _swap(base, 5e18, quote, 5000e18);
        _flashLoan(quote, 5000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 1000e18 });
    }

    function testScenario17_FlashLoanBase() public {
        _initialPosition();

        _fund(base, 1e18);
        _swap(base, 5e18, quote, 5000e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 1000e18 });
    }

    // Sell 4 ETH for ~4k, repay debt worth ~5k
    function testScenario18_FlashLoanQuote() public {
        _initialPosition();

        _fund(quote, 1000e18);
        _repay(5000e18);
        _withdraw(4e18);
        _swap(base, 4e18, quote, 4000e18);
        _flashLoan(quote, 4000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 1000e18 });
    }

    function testScenario18_FlashLoanBase() public {
        _initialPosition();

        _fund(quote, 1000e18);
        _swap(base, 4e18, quote, 4000e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 1000e18 });
    }

    // Sell 2.5 ETH for ~2.5k, withdraw 1.5 ETH, repay ~2.5k
    function testScenario19_FlashLoanQuote() public {
        _initialPosition();

        _repay(2500e18);
        _withdraw(4e18);
        _push(base, 1.5e18);
        _swap(base, 2.5e18, quote, 2500e18);
        _flashLoan(quote, 2500e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3500e18 });
    }

    function testScenario19_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 2.5e18, quote, 2500e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _push(base, 1.5e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3500e18 });
    }

    // Borrow 200, Sell 200 for ~0.2 ETH, withdraw ~1.2 ETH
    function testScenario20() public {
        _initialPosition();

        _withdraw(1e18);
        _borrow(200e18);
        _swap(quote, 200e18, base, 0.2e18);
        _push(base, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 9e18, expectedDebt: 6200e18 });
        _assertOwnerBalances({ wethBalance: 1.2e18, daiBalance: 0 });
    }

    // Sell 4 ETH for ~4k, repay ~2.5k debt, withdraw 1.5k
    function testScenario21_FlashLoanQuote() public {
        _initialPosition();

        _push(quote, 1500e18);
        _repay(ACCOUNT_BALANCE);
        _withdraw(4e18);
        _swap(base, 4e18, quote, 4000e18);
        _flashLoan(quote, 4000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3500e18 });
    }

    function testScenario21_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 4e18, quote, 4000e18);
        _push(quote, 1500e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3500e18 });
    }

    // Sell 1 ETH for ~1k, take 200 debt, withdraw ~1.2k
    function testScenario22() public {
        _initialPosition();

        _withdraw(1e18);
        _swap(base, 1e18, quote, 1000e18);
        _borrow(200e18);
        _push(quote, 1200e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 9e18, expectedDebt: 6200e18 });
        _assertOwnerBalances({ wethBalance: 0, daiBalance: 1200e18 });
    }

    // Sell 6 ETH for ~6k, repay ~6k, withdraw 4 ETH
    function testScenario23_FlashLoanQuote() public {
        _initialPosition();

        _repay(DEBT_BALANCE);
        _withdraw(COLLATERAL_BALANCE);
        _swap(base, 6.06e18, quote, 6006e18);
        _flashLoan(quote, 6006e18);
        _push(base, ACCOUNT_BALANCE);
        _push(quote, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 0, expectedDebt: 0 });
        _assertOwnerBalances({ wethBalance: 3.94e18, daiBalance: 6e18 });
    }

    function testScenario23_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 6.06e18, quote, 6006e18);
        _repay(DEBT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, COLLATERAL_BALANCE);
        } else {
            _withdraw(COLLATERAL_BALANCE);
            _flashLoan(base, 6.06e18);
        }
        _push(base, ACCOUNT_BALANCE);
        _push(quote, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 0, expectedDebt: 0 });
        _assertOwnerBalances({ wethBalance: 3.94e18, daiBalance: 6e18 });
    }

    // Sell 10 ETH for ~10k, repay 6k, withdraw ~4k
    function testScenario24_FlashLoanQuote() public {
        _initialPosition();

        _repay(DEBT_BALANCE);
        _withdraw(COLLATERAL_BALANCE);
        _swap(base, 9.9999e18, quote, 10_000e18);
        _flashLoan(quote, 6010e18);
        _push(quote, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 0, expectedDebt: 0 });
        _assertOwnerBalances({ wethBalance: 0, daiBalance: 4000e18 });
    }

    function testScenario24_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 9.9999e18, quote, 10_000e18);
        _repay(DEBT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, COLLATERAL_BALANCE);
        } else {
            _withdraw(COLLATERAL_BALANCE);
            _flashLoan(base, 9.9999e18);
        }
        _push(base, ACCOUNT_BALANCE);
        _push(quote, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 0, expectedDebt: 0 });
        _assertOwnerBalances({ wethBalance: 0, daiBalance: 4000e18 });
    }

    // Borrow 1k, Sell 1k for ~1 ETH, withdraw ~1 ETH
    function testScenario25() public {
        _initialPosition();

        _borrow(1000e18);
        _swap(quote, 1000e18, base, 1e18);
        _push(base, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 7000e18 });
        _assertOwnerBalances({ wethBalance: 1e18, daiBalance: 0 });
    }

    // Borrow 1k, withdraw 1k
    function testScenario26() public {
        _initialPosition();

        _borrow(1000e18);
        _push(quote, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 10e18, expectedDebt: 7000e18 });
        _assertOwnerBalances({ wethBalance: 0, daiBalance: 1000e18 });
    }

    // Just withdraw 1 ETH, no spot trade needed
    function testScenario27() public {
        _initialPosition();

        _withdraw(1e18);
        _push(base, ACCOUNT_BALANCE);
        _execute();

        _assertPositionBalances({ expectedCollateral: 9e18, expectedDebt: 6000e18 });
        _assertOwnerBalances({ wethBalance: 1e18, daiBalance: 0 });
    }

    // Sell 4k for ~4 ETH, deposit ~5 ETH, borrow ~4k
    function testScenario28_FlashLoanQuote() public {
        _initialPosition();

        _fund(base, 1e18);
        _swap(quote, 4000e18, base, 4e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 4000e18);
        } else {
            _borrow(4000e18);
            _flashLoan(quote, 4000e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 15e18, expectedDebt: 10_000e18 });
    }

    function testScenario28_FlashLoanBase() public {
        _initialPosition();

        _fund(base, 1e18);
        _supply(5e18); // Prob a tad less to account for slippage
        _borrow(4000e18);
        _swap(quote, 4000e18, base, 4e18);
        _flashLoan(base, 4e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 15e18, expectedDebt: 10_000e18 });
    }

    // Sell 5k for ~5 ETH but only borrow what the trader's not paying for (borrow 4k)
    function testScenario29_FlashLoanQuote() public {
        _initialPosition();

        _fund(quote, 1000e18);
        _swap(quote, 5000e18, base, 5e18);
        _supply(ACCOUNT_BALANCE);
        if (supportsFlashBorrow) {
            _flashBorrow(quote, 4000e18);
        } else {
            _borrow(4000e18);
            _flashLoan(quote, 4000e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 15e18, expectedDebt: 10_000e18 });
    }

    function testScenario29_FlashLoanBase() public {
        _initialPosition();

        _fund(quote, 1000e18);
        _supply(5e18); // Prob a tad less to account for slippage
        _borrow(4000e18);
        _swap(quote, 5000e18, base, 5e18);
        _flashLoan(base, 5e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 15e18, expectedDebt: 10_000e18 });
    }

    // Sell 3 ETH for ~3k, withdraw 1 ETH, repay ~3k
    function testScenario30_FlashLoanQuote() public {
        _initialPosition();

        _repay(3000e18);
        _withdraw(4e18);
        _swap(base, 3e18, quote, 3000e18);
        _push(base, 1e18);
        _flashLoan(quote, 3000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3000e18 });
        _assertOwnerBalances({ wethBalance: 1e18, daiBalance: 0 });
    }

    function testScenario30_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 3e18, quote, 3000e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _push(base, 1e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3000e18 });
        _assertOwnerBalances({ wethBalance: 1e18, daiBalance: 0 });
    }

    // Sell 4 ETH for ~4k, repay ~3k debt, withdraw 1k
    function testScenario31_FlashLoanQuote() public {
        _initialPosition();

        _push(quote, 1000e18);
        _repay(ACCOUNT_BALANCE);
        _withdraw(4e18);
        _swap(base, 4e18, quote, 4000e18);
        _flashLoan(quote, 4000e18);
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3000e18 });
        _assertOwnerBalances({ wethBalance: 0, daiBalance: 1000e18 });
    }

    function testScenario31_FlashLoanBase() public {
        _initialPosition();

        _swap(base, 4e18, quote, 4000e18);
        _push(quote, 1000e18);
        _repay(ACCOUNT_BALANCE);
        if (supportsFlashWithdraw) {
            _flashWithdraw(base, 4e18);
        } else {
            _withdraw(4e18);
            _flashLoan(base, 4e18);
        }
        _execute();

        _assertPositionBalances({ expectedCollateral: 6e18, expectedDebt: 3000e18 });
        _assertOwnerBalances({ wethBalance: 0, daiBalance: 1000e18 });
    }

    function _fund(IERC20 token, uint256 amount) internal {
        vm.prank(treasury);
        token.safeTransfer(rootAccount, amount);

        rootActions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (token, amount, holdingAccount))));
    }

    function _push(IERC20 token, uint256 amount) internal {
        holdingActions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (token, amount, owner))));
    }

    function _supply(uint256 amount) internal {
        _supplyToMarket(holdingActions, amount);
    }

    function _borrow(uint256 amount) internal {
        _borrowFromMarket(holdingActions, amount);
    }

    function _repay(uint256 amount) internal {
        _repayToMarket(holdingActions, amount);
    }

    function _withdraw(uint256 amount) internal {
        _withdrawFromMarket(holdingActions, amount);
    }

    function _supplyToMarket(Action[] storage actions, uint256 amount) internal virtual;

    function _borrowFromMarket(Action[] storage actions, uint256 amount) internal virtual;

    function _repayToMarket(Action[] storage actions, uint256 amount) internal virtual;

    function _withdrawFromMarket(Action[] storage actions, uint256 amount) internal virtual;

    function _swap(IERC20 tokenToSell, uint256 amountIn, IERC20 tokenToBuy, uint256 minAmountOut) internal {
        holdingActions.push(
            address(swapAction)
                .delegateAction(
                    abi.encodeCall(
                        SwapAction.executeSwap,
                        (SwapAction.Swap({
                                tokenToSell: tokenToSell,
                                amountIn: amountIn,
                                tokenToBuy: tokenToBuy,
                                minAmountOut: minAmountOut,
                                router: address(spotMarket),
                                spender: address(spotMarket),
                                swapBytes: abi.encodeCall(SpotMarket.swap, (tokenToSell, amountIn, tokenToBuy, minAmountOut)),
                                spotMarketName: "Test Spot Market",
                                offsets: new uint256[](0)
                            }))
                    )
                )
        );
    }

    function _execute() internal {
        rootActions.push(
            address(ownableExecutor)
                .action(abi.encodeCall(OwnableExecutor.executeActions, (IERC7579Execution(holdingAccount), holdingActions.pack())))
        );
        delete holdingActions;

        _executeActions(rootAccount, owner, rootActions);
        delete rootActions;
    }

    function _flashLoan(IERC20 token, uint256 amount) internal {
        holdingActions.push(
            address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (token, amount, address(flashLoanProvider))))
        );

        PackedAction[] memory packedCalls = holdingActions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(holdingAccount), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete holdingActions;
        holdingActions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        holdingActions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanERC7399,
                        (
                            flashLoanProvider,
                            token,
                            amount,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(holdingAccount), packedCalls, signature, innerNonce)
                                )
                            ),
                            holdingAccount
                        )
                    )
                )
        );
    }

    function _flashBorrow(IERC20, uint256) internal virtual {
        revert("Flash borrowing not supported");
    }

    function _flashWithdraw(IERC20, uint256) internal virtual {
        revert("Flash withdrawing not supported");
    }

    function _initialPosition() internal {
        _fund(quote, 4000e18);
        _swap(quote, 10_000e18, base, 10e18);
        _supply(ACCOUNT_BALANCE);
        _borrow(6000e18);
        _flashLoan(quote, 6000e18);
        _execute();
    }

    function _assertPositionBalances(uint256 expectedCollateral, uint256 expectedDebt) internal {
        (address to, bytes memory data) = _collateralOnMarket();
        uint256 collateralOnMarket = abi.decode(to.functionCall(data), (uint256));
        if (collateralOnMarket < 0.000000001e18) collateralOnMarket = 0;
        assertApproxEqRelDecimal(collateralOnMarket, expectedCollateral, 0.000001e18, 18, "Incorrect collateral balance");

        (to, data) = _debtOnMarket();
        uint256 debtOnMarket = abi.decode(to.functionCall(data), (uint256));
        if (debtOnMarket < 0.000000001e18) debtOnMarket = 0;
        assertApproxEqRelDecimal(debtOnMarket, expectedDebt, 0.000001e18, 18, "Incorrect debt balance");
    }

    function _assertOwnerBalances(uint256 wethBalance, uint256 daiBalance) internal view {
        uint256 baseBalance = base.balanceOf(owner);
        if (baseBalance <= 0.0001e18) baseBalance = 0;
        assertApproxEqRelDecimal(baseBalance, wethBalance, 0.00001e18, 18, "Incorrect owner WETH balance");

        uint256 quoteBalance = quote.balanceOf(owner);
        if (quoteBalance <= 0.0001e18) quoteBalance = 0;
        assertApproxEqRelDecimal(quoteBalance, daiBalance, 0.00001e18, 18, "Incorrect owner DAI balance");
    }

    function _collateralOnMarket() internal virtual returns (address, bytes memory);

    function _debtOnMarket() internal virtual returns (address, bytes memory);

}
