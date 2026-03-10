//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MorphoMoneyMarket, IMorpho, MorphoMarketId } from "../../src/moneymarkets/morpho/MorphoMoneyMarket.sol";
import { AaveMoneyMarket } from "../../src/moneymarkets/aave/AaveMoneyMarket.sol";
import { IPoolAddressesProvider } from "../../src/moneymarkets/aave/dependencies/IPoolAddressesProvider.sol";
import { IPool } from "../../src/moneymarkets/aave/dependencies/IPool.sol";
import { CometMoneyMarket, IComet } from "../../src/moneymarkets/comet/CometMoneyMarket.sol";
import { EulerMoneyMarket, IEulerVault } from "../../src/moneymarkets/euler/EulerMoneyMarket.sol";

contract MoneyMarketRatesTest is Test {

    MorphoMoneyMarket morphoMarket;
    AaveMoneyMarket aaveMarket;
    CometMoneyMarket cometMarket;
    EulerMoneyMarket eulerMarket;

    function setUp() public {
        vm.createSelectFork("mainnet", 22_895_431);
        morphoMarket = new MorphoMoneyMarket();
        aaveMarket = new AaveMoneyMarket();
        cometMarket = new CometMoneyMarket();
        eulerMarket = new EulerMoneyMarket();
    }

    function test_MorphoRates() public view {
        MorphoMarketId marketId = MorphoMarketId.wrap(0x6029eea874791e01e2f3ce361f2e08839cd18b1e26eea6243fa3e43fe8f6fa23);
        IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0); // collateral
        IERC20 eUSD = IERC20(0xA0d69E286B938e21CBf7E51D71F6A4c8918f482F); // loan

        uint256 borrowRate = morphoMarket.borrowRate(eUSD, marketId, morpho);
        assertGt(borrowRate, 0, "Borrow rate should be > 0");

        uint256 supplyRate = morphoMarket.supplyRate(eUSD, marketId, morpho);
        assertGt(supplyRate, 0, "Supply rate should be > 0");
        assertGt(borrowRate, supplyRate, "Borrow rate should be > Supply rate");

        // Collateral should return 0
        assertEq(morphoMarket.supplyRate(wstETH, marketId, morpho), 0);
    }

    function test_AaveRates() public view {
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        IPool pool = poolAddressesProvider.getPool();
        IERC20 wETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        uint256 borrowRate = aaveMarket.borrowRate(wETH, pool);
        assertGt(borrowRate, 0, "Borrow rate should be > 0");

        uint256 supplyRate = aaveMarket.supplyRate(wETH, pool);
        assertGt(supplyRate, 0, "Supply rate should be > 0");
        assertGt(borrowRate, supplyRate, "Borrow rate should be > Supply rate");
    }

    function test_CometRates() public {
        IComet comet = IComet(0x5D409e56D886231aDAf00c8775665AD0f9897b56);
        IERC20 wETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // collateral
        IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F); // loan

        uint256 borrowRate = cometMarket.borrowRate(usds, comet);
        assertGt(borrowRate, 0, "Borrow rate should be > 0");

        uint256 supplyRate = cometMarket.supplyRate(usds, comet);
        assertGt(supplyRate, 0, "Supply rate should be > 0");

        assertEq(cometMarket.supplyRate(wETH, comet), 0); // collateral returns 0

        vm.expectRevert();
        cometMarket.borrowRate(wETH, comet); // collateral borrow returns InvalidAsset
    }

    function test_EulerRates() public {
        IEulerVault quoteVault = IEulerVault(0xc2d36F41841B420937643dcccbEa8163D4F59B6c);
        IERC20 quoteAsset = IERC20(quoteVault.asset());

        vm.expectRevert("not implemented");
        eulerMarket.borrowRate(quoteAsset, quoteVault);

        vm.expectRevert("not implemented");
        eulerMarket.supplyRate(quoteAsset, quoteVault);
    }

}
