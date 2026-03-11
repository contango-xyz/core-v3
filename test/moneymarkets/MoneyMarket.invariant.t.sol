//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Solarray } from "solarray/Solarray.sol";

import { BaseTest } from "../BaseTest.t.sol";
import { AbstractMoneyMarketInvariantTest, MoneyMarket } from "./AbstractMoneyMarket.invariant.t.sol";

import { IWETH9 } from "../../src/dependencies/IWETH9.sol";
import { AaveMoneyMarket } from "../../src/moneymarkets/aave/AaveMoneyMarket.sol";
import { IPoolAddressesProvider } from "../../src/moneymarkets/aave/dependencies/IPoolAddressesProvider.sol";
import { IPool } from "../../src/moneymarkets/aave/dependencies/IPool.sol";
import { IPoolDataProvider } from "../../src/moneymarkets/aave/dependencies/IPoolDataProvider.sol";
import { IAaveOracle } from "../../src/moneymarkets/aave/dependencies/IAaveOracle.sol";
import {
    MorphoMoneyMarket,
    IMorpho,
    MorphoMarketId,
    MarketParams,
    Market,
    Position,
    SharesMathLib
} from "../../src/moneymarkets/morpho/MorphoMoneyMarket.sol";
import { CometMoneyMarket, IComet } from "../../src/moneymarkets/comet/CometMoneyMarket.sol";
import { EulerMoneyMarket, IEulerVault, IEthereumVaultConnector } from "../../src/moneymarkets/euler/EulerMoneyMarket.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { PackedAction, Action } from "../../src/types/Action.sol";
import { ActionLib } from "../ActionLib.sol";
import { RAY, WAD } from "../../src/constants.sol";
import { ERC20Lib } from "../../src/libraries/ERC20Lib.sol";

uint256 constant AMOUNT = 0;

using ERC20Lib for IERC20;
using Address for address;
using Solarray for address;

contract AaveMoneyMarketInvariantTest is AbstractMoneyMarketInvariantTest {

    using ActionLib for *;

    IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IPool pool;
    IAaveOracle oracle;
    IPoolDataProvider poolDataProvider;
    address aaveMoneyMarket;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        // Seems Aave added some checks for 0 amounts
        minWithdrawal = 10;
        minDeposit = 10;
        minBorrowing = 10;
        minRepay = 10;
        minDebt = 10;
        super.setUp();

        IERC20 wETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        quoteAmount = 1000e18;

        pool = poolAddressesProvider.getPool();
        oracle = poolAddressesProvider.getPriceOracle();
        poolDataProvider = poolAddressesProvider.getPoolDataProvider();

        aaveMoneyMarket = address(new AaveMoneyMarket());

        MoneyMarket memory moneyMarket = MoneyMarket({
            instance: aaveMoneyMarket,
            collateralBalance: this.collateralBalance,
            debtBalance: this.debtBalance,
            supply: this.supply,
            borrow: this.borrow,
            repay: this.repay,
            withdraw: this.withdraw,
            prices: this.prices,
            thresholds: this.thresholds,
            unscaleAmounts: this.unscaleAmounts,
            logAccounting: this.logAccounting,
            enableCollateral: this.enableCollateral,
            enableDebt: this.enableDebt,
            borrowLiquidity: this.borrowLiquidity
        });

        super.setUp(wETH, usds, moneyMarket);
    }

    function supply(uint256 amount) external view returns (Action memory) {
        return aaveMoneyMarket.delegateAction(abi.encodeCall(AaveMoneyMarket.supply, (amount, base, pool)));
    }

    function borrow(uint256 amount) external view returns (Action memory) {
        return aaveMoneyMarket.delegateAction(abi.encodeCall(AaveMoneyMarket.borrow, (amount, quote, account, pool)));
    }

    function repay(uint256 amount) external view returns (Action memory) {
        return aaveMoneyMarket.delegateAction(abi.encodeCall(AaveMoneyMarket.repay, (amount, quote, pool)));
    }

    function withdraw(uint256 amount) external view returns (Action memory) {
        return aaveMoneyMarket.delegateAction(abi.encodeCall(AaveMoneyMarket.withdraw, (amount, base, account, pool)));
    }

    function collateralBalance() external view returns (uint256) {
        return AaveMoneyMarket(aaveMoneyMarket).collateralBalance(account, base, pool);
    }

    function debtBalance() external view returns (uint256) {
        return AaveMoneyMarket(aaveMoneyMarket).debtBalance(account, quote, pool);
    }

    function prices() external view returns (uint256 collateral, uint256 debt, uint256 unit) {
        collateral = AaveMoneyMarket(aaveMoneyMarket).oraclePrice(base, oracle);
        debt = AaveMoneyMarket(aaveMoneyMarket).oraclePrice(quote, oracle);
        unit = AaveMoneyMarket(aaveMoneyMarket).oracleUnit(oracle);
    }

    function thresholds() external view returns (uint256 ltv, uint256 liquidationThreshold) {
        (, ltv, liquidationThreshold,,,,,,,) = poolDataProvider.getReserveConfigurationData(base);
        ltv *= 1e14;
        liquidationThreshold *= 1e14;
    }

    function enableCollateral(address) external {
        // Not needed for Aave
    }

    function enableDebt(address) external {
        // Not needed for Aave
    }

    function borrowLiquidity() external view returns (uint256) {
        (uint256 borrowCap,) = poolDataProvider.getReserveCaps(quote);
        borrowCap = borrowCap * 10 ** quote.decimals();
        uint256 totalDebt = poolDataProvider.getTotalDebt(quote);

        uint256 maxBorrowable = borrowCap > totalDebt ? borrowCap - totalDebt : 0;
        (address aTokenAddress,,) = poolDataProvider.getReserveTokensAddresses(quote);
        uint256 available = quote.balanceOf(aTokenAddress);

        return borrowCap == 0 ? available : Math.min(maxBorrowable, available);
    }

    function unscaleAmounts(uint256 scaledCollateral, uint256 scaledDebt) external view returns (uint256 collateral, uint256 debt) {
        collateral = Math.mulDiv(scaledCollateral, pool.getReserveNormalizedIncome(base), RAY);
        debt = Math.mulDiv(scaledDebt, pool.getReserveNormalizedVariableDebt(quote), RAY);
    }

    function logAccounting(Vm.Log[] memory logs, uint256 _collateralShares, uint256 _debtShares)
        external
        returns (uint256 collateralShares, uint256 debtShares)
    {
        collateralShares = _collateralShares;
        debtShares = _debtShares;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("AaveSupply(address,address,uint256,uint256,uint256)")) {
                (uint256 amount, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                collateralShares += shares;
                lots.push(
                    Lot({ lotType: LotType.Collateral, amount: amount, shares: shares, index: index, unrealisedPnL: 0, realisedPnL: 0 })
                );
            }
            if (logs[i].topics[0] == keccak256("AaveBorrow(address,address,uint256,uint256,uint256,address)")) {
                (uint256 amount, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                debtShares += shares;
                lots.push(Lot({ lotType: LotType.Debt, amount: amount, shares: shares, index: index, unrealisedPnL: 0, realisedPnL: 0 }));
            }
            if (logs[i].topics[0] == keccak256("AaveRepay(address,address,uint256,uint256,uint256)")) {
                (, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                debtShares -= shares;
                _closeShares(LotType.Debt, shares, index);
            }
            if (logs[i].topics[0] == keccak256("AaveWithdraw(address,address,uint256,uint256,uint256,address)")) {
                (, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                collateralShares -= shares;
                _closeShares(LotType.Collateral, shares, index);
            }
        }
    }

}

contract MorphoMoneyMarketInvariantTest is AbstractMoneyMarketInvariantTest {

    using ActionLib for *;
    using SharesMathLib for *;

    MorphoMarketId marketId = MorphoMarketId.wrap(0x6029eea874791e01e2f3ce361f2e08839cd18b1e26eea6243fa3e43fe8f6fa23);
    IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    address morphoMoneyMarket;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        IERC20 eUSD = IERC20(0xA0d69E286B938e21CBf7E51D71F6A4c8918f482F);
        quoteAmount = 1000e18;

        morphoMoneyMarket = address(new MorphoMoneyMarket());

        MoneyMarket memory moneyMarket = MoneyMarket({
            instance: morphoMoneyMarket,
            collateralBalance: this.collateralBalance,
            debtBalance: this.debtBalance,
            supply: this.supply,
            borrow: this.borrow,
            repay: this.repay,
            withdraw: this.withdraw,
            prices: this.prices,
            thresholds: this.thresholds,
            unscaleAmounts: this.unscaleAmounts,
            logAccounting: this.logAccounting,
            enableCollateral: this.enableCollateral,
            enableDebt: this.enableDebt,
            borrowLiquidity: this.borrowLiquidity
        });

        super.setUp(wstETH, eUSD, moneyMarket);
    }

    function supply(uint256 amount) external view returns (Action memory) {
        return morphoMoneyMarket.delegateAction(abi.encodeCall(MorphoMoneyMarket.supply, (amount, base, marketId, morpho)));
    }

    function borrow(uint256 amount) external view returns (Action memory) {
        return morphoMoneyMarket.delegateAction(abi.encodeCall(MorphoMoneyMarket.borrow, (amount, quote, account, marketId, morpho)));
    }

    function repay(uint256 amount) external view returns (Action memory) {
        return morphoMoneyMarket.delegateAction(abi.encodeCall(MorphoMoneyMarket.repay, (amount, quote, marketId, morpho)));
    }

    function withdraw(uint256 amount) external view returns (Action memory) {
        return morphoMoneyMarket.delegateAction(abi.encodeCall(MorphoMoneyMarket.withdraw, (amount, base, account, marketId, morpho)));
    }

    function collateralBalance() external view returns (uint256) {
        return MorphoMoneyMarket(morphoMoneyMarket).collateralBalance(account, base, marketId, morpho);
    }

    function debtBalance() external returns (uint256) {
        return MorphoMoneyMarket(morphoMoneyMarket).debtBalance(account, quote, marketId, morpho);
    }

    function prices() external view returns (uint256 collateral, uint256 debt, uint256 unit) {
        collateral = MorphoMoneyMarket(morphoMoneyMarket).oraclePrice(base, marketId, morpho);
        debt = MorphoMoneyMarket(morphoMoneyMarket).oraclePrice(quote, marketId, morpho);
        unit = MorphoMoneyMarket(morphoMoneyMarket).oracleUnit(marketId, morpho);
    }

    function thresholds() external view returns (uint256 ltv, uint256 liquidationThreshold) {
        ltv = liquidationThreshold = morpho.idToMarketParams(marketId).lltv;
    }

    function enableCollateral(address) external {
        // Not needed for Morpho
    }

    function enableDebt(address) external {
        // Not needed for Morpho
    }

    function borrowLiquidity() external view returns (uint256) {
        Market memory market = morpho.market(marketId);
        return market.totalSupplyAssets - market.totalBorrowAssets;
    }

    function unscaleAmounts(uint256 scaledCollateral, uint256 scaledDebt) external returns (uint256 collateral, uint256 debt) {
        collateral = scaledCollateral;

        if (scaledDebt > 0) {
            MarketParams memory marketParams = morpho.idToMarketParams(marketId);
            morpho.accrueInterest(marketParams);
            Market memory market = morpho.market(marketId);
            debt = scaledDebt.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        }
    }

    function logAccounting(Vm.Log[] memory logs, uint256 _collateralShares, uint256 _debtShares)
        external
        returns (uint256 collateralShares, uint256 debtShares)
    {
        collateralShares = _collateralShares;
        debtShares = _debtShares;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("MorphoSupplyCollateral(address,bytes32,address,uint256)")) {
                uint256 amount = abi.decode(logs[i].data, (uint256));
                collateralShares += amount;
                lots.push(
                    Lot({ lotType: LotType.Collateral, amount: amount, shares: amount, index: RAY, unrealisedPnL: 0, realisedPnL: 0 })
                );
            }
            if (logs[i].topics[0] == keccak256("MorphoBorrow(address,bytes32,address,uint256,uint256,uint256,address)")) {
                (uint256 amount, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                debtShares += shares;
                lots.push(Lot({ lotType: LotType.Debt, amount: amount, shares: shares, index: index, unrealisedPnL: 0, realisedPnL: 0 }));
            }
            if (logs[i].topics[0] == keccak256("MorphoRepay(address,bytes32,address,uint256,uint256,uint256)")) {
                (, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                debtShares -= shares;
                _closeShares(LotType.Debt, shares, index);
            }
            if (logs[i].topics[0] == keccak256("MorphoWithdrawCollateral(address,bytes32,address,uint256,address)")) {
                uint256 amount = abi.decode(logs[i].data, (uint256));
                collateralShares -= amount;
                _closeShares(LotType.Collateral, amount, RAY);
            }
        }
    }

}

contract CometMoneyMarketInvariantTest is AbstractMoneyMarketInvariantTest {

    using ActionLib for *;

    IComet comet = IComet(0x5D409e56D886231aDAf00c8775665AD0f9897b56);
    address cometMoneyMarket;

    uint64 internal constant BASE_INDEX_SCALE = 1e15;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        IERC20 wETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        quoteAmount = 1000e18;
        minDebt = minBorrowing = 10e18;

        cometMoneyMarket = address(new CometMoneyMarket());

        indexScale = BASE_INDEX_SCALE;

        MoneyMarket memory moneyMarket = MoneyMarket({
            instance: cometMoneyMarket,
            collateralBalance: this.collateralBalance,
            debtBalance: this.debtBalance,
            supply: this.supply,
            borrow: this.borrow,
            repay: this.repay,
            withdraw: this.withdraw,
            prices: this.prices,
            thresholds: this.thresholds,
            unscaleAmounts: this.unscaleAmounts,
            logAccounting: this.logAccounting,
            enableCollateral: this.enableCollateral,
            enableDebt: this.enableDebt,
            borrowLiquidity: this.borrowLiquidity
        });
        super.setUp(wETH, usds, moneyMarket);
    }

    function collateralBalance() external view returns (uint256) {
        return CometMoneyMarket(cometMoneyMarket).collateralBalance(account, base, comet);
    }

    function debtBalance() external view returns (uint256) {
        return CometMoneyMarket(cometMoneyMarket).debtBalance(account, quote, comet);
    }

    function supply(uint256 amount) external view returns (Action memory) {
        return cometMoneyMarket.delegateAction(abi.encodeCall(CometMoneyMarket.supply, (amount, base, comet)));
    }

    function borrow(uint256 amount) external view returns (Action memory) {
        return cometMoneyMarket.delegateAction(abi.encodeCall(CometMoneyMarket.borrow, (amount, quote, account, comet)));
    }

    function repay(uint256 amount) external view returns (Action memory) {
        return cometMoneyMarket.delegateAction(abi.encodeCall(CometMoneyMarket.repay, (amount, quote, comet)));
    }

    function withdraw(uint256 amount) external view returns (Action memory) {
        return cometMoneyMarket.delegateAction(abi.encodeCall(CometMoneyMarket.withdraw, (amount, base, account, comet)));
    }

    function prices() external view returns (uint256 collateral, uint256 debt, uint256 unit) {
        collateral = CometMoneyMarket(cometMoneyMarket).oraclePrice(base, comet);
        debt = CometMoneyMarket(cometMoneyMarket).oraclePrice(quote, comet);
        unit = CometMoneyMarket(cometMoneyMarket).oracleUnit(comet);
    }

    function thresholds() external view returns (uint256 ltv, uint256 liquidationThreshold) {
        IComet.AssetInfo memory assetInfo = comet.getAssetInfoByAddress(base);
        ltv = assetInfo.borrowCollateralFactor;
        liquidationThreshold = assetInfo.liquidateCollateralFactor;
    }

    function enableCollateral(address) external {
        // Not needed for Comet
    }

    function enableDebt(address) external {
        // Not needed for Comet
    }

    function borrowLiquidity() external view returns (uint256) {
        uint256 totalSupply = comet.totalSupply();
        uint256 totalBorrow = comet.totalBorrow();
        return totalSupply > totalBorrow ? totalSupply - totalBorrow : 0;
    }

    function unscaleAmounts(uint256 scaledCollateral, uint256 scaledDebt) external returns (uint256 collateral, uint256 debt) {
        collateral = scaledCollateral;

        // Force accrue interest
        comet.accrueAccount(address(this));
        uint256 baseBorrowIndex = comet.totalsBasic().baseBorrowIndex;

        debt = scaledDebt > 0 ? scaledDebt * baseBorrowIndex / BASE_INDEX_SCALE : 0;
    }

    function logAccounting(Vm.Log[] memory logs, uint256 _collateralShares, uint256 _debtShares)
        external
        returns (uint256 collateralShares, uint256 debtShares)
    {
        collateralShares = _collateralShares;
        debtShares = _debtShares;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("CometSupplyCollateral(address,address,uint256)")) {
                uint256 amount = abi.decode(logs[i].data, (uint256));
                collateralShares += amount;
                lots.push(
                    Lot({
                        lotType: LotType.Collateral,
                        amount: amount,
                        shares: amount,
                        index: BASE_INDEX_SCALE,
                        unrealisedPnL: 0,
                        realisedPnL: 0
                    })
                );
            }
            if (logs[i].topics[0] == keccak256("CometBorrow(address,address,uint256,uint256,uint256,address)")) {
                (uint256 amount, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                debtShares += shares;
                lots.push(Lot({ lotType: LotType.Debt, amount: amount, shares: shares, index: index, unrealisedPnL: 0, realisedPnL: 0 }));
            }
            if (logs[i].topics[0] == keccak256("CometRepay(address,address,uint256,uint256,uint256)")) {
                (, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                debtShares -= shares;
                _closeShares(LotType.Debt, shares, index);
            }
            if (logs[i].topics[0] == keccak256("CometWithdrawCollateral(address,address,uint256,address)")) {
                uint256 amount = abi.decode(logs[i].data, (uint256));
                collateralShares -= amount;
                _closeShares(LotType.Collateral, amount, BASE_INDEX_SCALE);
            }
        }
    }

}

contract EulerMoneyMarketInvariantTest is AbstractMoneyMarketInvariantTest {

    using ActionLib for *;

    address eulerMoneyMarket;
    IEulerVault baseVault = IEulerVault(0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2);
    IEulerVault quoteVault = IEulerVault(0x328646cdfBaD730432620d845B8F5A2f7D786C01);
    IEthereumVaultConnector evc = IEthereumVaultConnector(payable(0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383));
    uint256 borrowIndex;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        IERC20 baseAsset = IERC20(baseVault.asset());
        IERC20 quoteAsset = IERC20(quoteVault.asset());
        quoteAmount = 1000e18;
        minDeposit = 0.000_000_01 ether;

        wrapChainlinkAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        wrapChainlinkAggregator(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);

        eulerMoneyMarket = address(new EulerMoneyMarket());

        useSharesForDebt = false;

        MoneyMarket memory moneyMarket = MoneyMarket({
            instance: eulerMoneyMarket,
            collateralBalance: this.collateralBalance,
            debtBalance: this.debtBalance,
            supply: this.supply,
            borrow: this.borrow,
            repay: this.repay,
            withdraw: this.withdraw,
            prices: this.prices,
            thresholds: this.thresholds,
            unscaleAmounts: this.unscaleAmounts,
            logAccounting: this.logAccounting,
            enableCollateral: this.enableCollateral,
            enableDebt: this.enableDebt,
            borrowLiquidity: this.borrowLiquidity
        });

        super.setUp(baseAsset, quoteAsset, moneyMarket);
    }

    function collateralBalance() external view returns (uint256) {
        return EulerMoneyMarket(eulerMoneyMarket).collateralBalance(account, base, baseVault);
    }

    function debtBalance() external view returns (uint256) {
        return EulerMoneyMarket(eulerMoneyMarket).debtBalance(account, quote, quoteVault);
    }

    function supply(uint256 amount) external view returns (Action memory) {
        return eulerMoneyMarket.delegateAction(abi.encodeCall(EulerMoneyMarket.supply, (amount, base, baseVault)));
    }

    function borrow(uint256 amount) external view returns (Action memory) {
        return eulerMoneyMarket.delegateAction(abi.encodeCall(EulerMoneyMarket.borrow, (amount, quote, account, quoteVault)));
    }

    function repay(uint256 amount) external view returns (Action memory) {
        return eulerMoneyMarket.delegateAction(abi.encodeCall(EulerMoneyMarket.repay, (amount, quote, quoteVault)));
    }

    function withdraw(uint256 amount) external view returns (Action memory) {
        return eulerMoneyMarket.delegateAction(abi.encodeCall(EulerMoneyMarket.withdraw, (amount, base, account, baseVault)));
    }

    function prices() external view returns (uint256 collateral, uint256 debt, uint256 unit) {
        collateral = EulerMoneyMarket(eulerMoneyMarket).oraclePrice(base, baseVault);
        debt = EulerMoneyMarket(eulerMoneyMarket).oraclePrice(quote, quoteVault);
        unit = EulerMoneyMarket(eulerMoneyMarket).oracleUnit(baseVault);
    }

    function thresholds() external view returns (uint256 ltv, uint256 liquidationThreshold) {
        IEulerVault.LTVFullData memory ltvFull = quoteVault.LTVFull(baseVault);
        ltv = uint256(ltvFull.borrowLTV) * 1e14;
        liquidationThreshold = uint256(ltvFull.liquidationLTV) * 1e14;
    }

    function enableCollateral(address account) external {
        vm.prank(account);
        evc.enableCollateral(account, baseVault);
    }

    function enableDebt(address account) external {
        vm.prank(account);
        evc.enableController(account, quoteVault);
    }

    function borrowLiquidity() external view returns (uint256) {
        return quoteVault.cash() * 0.9e18 / 1e18;
    }

    function unscaleAmounts(uint256 scaledCollateral, uint256 scaledDebt) external view returns (uint256 collateral, uint256 debt) {
        collateral = baseVault.convertToAssets(scaledCollateral);

        debt = borrowIndex > 0 ? Math.mulDiv(scaledDebt, quoteVault.interestAccumulator(), borrowIndex, Math.Rounding.Ceil) : scaledDebt;
    }

    function logAccounting(Vm.Log[] memory logs, uint256 _collateralShares, uint256 _debtShares)
        external
        returns (uint256 collateralShares, uint256 debtShares)
    {
        collateralShares = _collateralShares;
        debtShares = _debtShares;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("EulerSupply(address,address,uint256,uint256,uint256)")) {
                (uint256 amount, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                collateralShares += shares;
                lots.push(
                    Lot({ lotType: LotType.Collateral, amount: amount, shares: shares, index: index, unrealisedPnL: 0, realisedPnL: 0 })
                );
            }
            if (logs[i].topics[0] == keccak256("EulerBorrow(address,address,uint256,uint256,address)")) {
                (uint256 amount, uint256 index) = abi.decode(logs[i].data, (uint256, uint256));

                lots.push(Lot({ lotType: LotType.Debt, amount: amount, shares: amount, index: index, unrealisedPnL: 0, realisedPnL: 0 }));

                if (borrowIndex > 0) {
                    uint256 delta = Math.mulDiv(debtShares, index, borrowIndex, Math.Rounding.Ceil) - debtShares;
                    debtShares += delta;
                }

                borrowIndex = index;
                debtShares += amount;
            }
            if (logs[i].topics[0] == keccak256("EulerRepay(address,address,uint256,uint256)")) {
                (uint256 amount, uint256 index) = abi.decode(logs[i].data, (uint256, uint256));

                if (borrowIndex > 0) {
                    uint256 delta = Math.mulDiv(debtShares, index, borrowIndex, Math.Rounding.Ceil) - debtShares;
                    debtShares += delta;
                }

                borrowIndex = index;
                debtShares -= amount;

                _closeDebt(amount, index);
            }
            if (logs[i].topics[0] == keccak256("EulerWithdraw(address,address,uint256,uint256,uint256,address)")) {
                (, uint256 shares, uint256 index) = abi.decode(logs[i].data, (uint256, uint256, uint256));
                collateralShares -= shares;
                _closeShares(LotType.Collateral, shares, index);
            }
        }
    }

}
