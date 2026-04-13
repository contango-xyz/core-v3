//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest, console } from "../BaseTest.t.sol";

import { Packing } from "@openzeppelin/contracts/utils/Packing.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Solarray } from "solarray/Solarray.sol";

import { IWETH9 } from "../../src/dependencies/IWETH9.sol";
import { EIP2098Permit } from "../../src/libraries/ERC20Lib.sol";
import { Action, PackedAction } from "../../src/types/Action.sol";
import { ActionLib } from "../ActionLib.sol";
import { FlashLoanProvider } from "../FlashLoanProvider.t.sol";
import { AaveMoneyMarket } from "../../src/moneymarkets/aave/AaveMoneyMarket.sol";
import { IPoolAddressesProvider } from "../../src/moneymarkets/aave/dependencies/IPoolAddressesProvider.sol";
import { IPool } from "../../src/moneymarkets/aave/dependencies/IPool.sol";
import { ACCOUNT_BALANCE, DEBT_BALANCE } from "../../src/constants.sol";
import { TokenAction } from "../../src/actions/TokenAction.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { OwnableExecutor } from "../../src/modules/OwnableExecutor.sol";
import { FlashLoanAction } from "../../src/flashloan/FlashLoanAction.sol";
import { MorphoMoneyMarket, MorphoMarketId, IMorpho, MarketParams } from "../../src/moneymarkets/morpho/MorphoMoneyMarket.sol";
import { Authorization, Signature } from "../../src/moneymarkets/morpho/dependencies/IMorpho.sol";
import { EulerMoneyMarket, IEthereumVaultConnector, IEulerVault } from "../../src/moneymarkets/euler/EulerMoneyMarket.sol";
import { CometMoneyMarket, IComet } from "../../src/moneymarkets/comet/CometMoneyMarket.sol";
import { ICometExt } from "../../src/moneymarkets/comet/dependencies/IComet.sol";

contract PositionMigrationTest is BaseTest {

    using Packing for *;
    using Address for address;
    using SafeERC20 for IERC20;
    using Solarray for *;
    using MessageHashUtils for *;
    using ActionLib for *;

    Action[] rootActions;
    Action[] actions1;
    Action[] actions2;

    IWETH9 internal weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal usdm = IERC20(0x57F5E098CaD7A3D1Eed53991D4d66C45C9AF7812);
    IERC20 internal usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    IERC20 internal gho = IERC20(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);

    FlashLoanProvider internal flashLoanProvider;
    address internal owner;
    uint256 internal ownerPk;
    address internal treasury;

    address internal rootAccount;
    address internal holdingAccount1;
    address internal holdingAccount2;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        flashLoanProvider = new FlashLoanProvider();

        (owner, ownerPk) = makeAddrAndKey("owner");
        treasury = makeAddr("treasury");

        deal(address(weth), treasury, 10_000e18);
        deal(address(wstETH), treasury, 10_000e18);
        deal(address(usdt), treasury, 10_000_000e6);
        deal(address(usds), treasury, 10_000_000e18);
        deal(address(gho), treasury, 10_000_000e18);
        deal(address(usdc), treasury, 10_000_000e6);
        vm.startPrank(treasury);
        usdt.safeTransfer(address(flashLoanProvider), 10_000e6);
        usds.safeTransfer(address(flashLoanProvider), 10_000e18);
        gho.safeTransfer(address(flashLoanProvider), 10_000e18);
        usdc.safeTransfer(address(flashLoanProvider), 10_000e6);
        vm.stopPrank();

        rootAccount = newAccount(owner, "Root Account");
        holdingAccount1 = newAccount(rootAccount, "Holding Account 1");
        holdingAccount2 = newAccount(rootAccount, "Holding Account 2");
    }

    function test_migratePositionOnSameHoldingAccount() public {
        AaveMoneyMarket aaveMoneyMarket = new AaveMoneyMarket();
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        IPool pool = poolAddressesProvider.getPool();

        vm.prank(treasury);
        wstETH.safeTransfer(holdingAccount1, 10e18);

        actions1.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.supply, (10e18, wstETH, pool))));
        actions1.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.borrow, (6000e6, usdc, owner, pool))));

        _executeAction(
            rootAccount,
            owner,
            address(ownableExecutor)
                .action(abi.encodeCall(OwnableExecutor.executeActions, (IERC7579Execution(holdingAccount1), actions1.pack())))
        );
        delete actions1;

        assertApproxEqAbsDecimal(
            aaveMoneyMarket.collateralBalance(holdingAccount1, wstETH, pool), 10e18, 1, 18, "starting collateral balance"
        );
        assertApproxEqAbsDecimal(aaveMoneyMarket.debtBalance(holdingAccount1, usdc, pool), 6000e6, 1, 6, "starting debt balance");
        assertEqDecimal(usdc.balanceOf(holdingAccount1), 0, 6, "dust usdc balance");

        // Accrue some interest
        skip(30 days);

        IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        MorphoMoneyMarket morphoMoneyMarket = new MorphoMoneyMarket();
        MorphoMarketId marketId = MorphoMarketId.wrap(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);

        uint256 flashLoanAmount = aaveMoneyMarket.debtBalance(holdingAccount1, usdc, pool) * 1.00025e18 / 1e18;

        actions1.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.repay, (DEBT_BALANCE, usdc, pool))));
        actions1.push(
            address(aaveMoneyMarket)
                .delegateAction(abi.encodeCall(AaveMoneyMarket.withdraw, (ACCOUNT_BALANCE, wstETH, holdingAccount1, pool)))
        );
        actions1.push(
            address(morphoMoneyMarket)
                .delegateAction(abi.encodeCall(MorphoMoneyMarket.supplyCollateral, (ACCOUNT_BALANCE, wstETH, marketId, morpho)))
        );
        actions1.push(
            address(morphoMoneyMarket)
                .delegateAction(
                    abi.encodeCall(MorphoMoneyMarket.borrow, (flashLoanAmount, usdc, address(flashLoanProvider), marketId, morpho))
                )
        );
        _flashLoan(holdingAccount1, actions1, usdc, flashLoanAmount, holdingAccount1);

        _executeAction(
            rootAccount,
            owner,
            address(ownableExecutor)
                .action(abi.encodeCall(OwnableExecutor.executeActions, (IERC7579Execution(holdingAccount1), actions1.pack())))
        );
        delete actions1;

        assertEqDecimal(aaveMoneyMarket.collateralBalance(holdingAccount1, wstETH, pool), 0, 18, "aave collateral balance");
        assertEqDecimal(aaveMoneyMarket.debtBalance(holdingAccount1, usdc, pool), 0, 6, "aave debt balance");

        assertEqDecimal(
            morphoMoneyMarket.collateralBalance(holdingAccount1, wstETH, marketId, morpho),
            10.000011619060644669e18,
            18,
            "morpho collateral balance"
        );
        assertApproxEqAbsDecimal(
            morphoMoneyMarket.debtBalance(holdingAccount1, usdc, marketId, morpho), flashLoanAmount, 1, 6, "morpho debt balance"
        );

        assertEqDecimal(usdc.balanceOf(holdingAccount1), 1.503549e6, 6, "dust usdc balance");
    }

    function test_migratePositionOnDifferentHoldingAccount() public {
        AaveMoneyMarket aaveMoneyMarket = new AaveMoneyMarket();
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        IPool pool = poolAddressesProvider.getPool();

        vm.prank(treasury);
        wstETH.safeTransfer(holdingAccount1, 10e18);

        actions1.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.supply, (10e18, wstETH, pool))));
        actions1.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.borrow, (6000e6, usdc, owner, pool))));

        _executeAction(
            rootAccount,
            owner,
            address(ownableExecutor)
                .action(abi.encodeCall(OwnableExecutor.executeActions, (IERC7579Execution(holdingAccount1), actions1.pack())))
        );
        delete actions1;

        assertApproxEqAbsDecimal(
            aaveMoneyMarket.collateralBalance(holdingAccount1, wstETH, pool), 10e18, 1, 18, "starting collateral balance"
        );
        assertApproxEqAbsDecimal(aaveMoneyMarket.debtBalance(holdingAccount1, usdc, pool), 6000e6, 1, 6, "starting debt balance");
        assertEqDecimal(usdc.balanceOf(holdingAccount1), 0, 6, "dust usdc balance");

        // Accrue some interest
        skip(30 days);

        IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        MorphoMoneyMarket morphoMoneyMarket = new MorphoMoneyMarket();
        MorphoMarketId marketId = MorphoMarketId.wrap(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);

        uint256 flashLoanAmount = aaveMoneyMarket.debtBalance(holdingAccount1, usdc, pool) * 1.00025e18 / 1e18;

        actions1.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.repay, (DEBT_BALANCE, usdc, pool))));
        actions1.push(
            address(aaveMoneyMarket)
                .delegateAction(abi.encodeCall(AaveMoneyMarket.withdraw, (ACCOUNT_BALANCE, wstETH, holdingAccount2, pool)))
        );
        actions2.push(
            address(morphoMoneyMarket)
                .delegateAction(abi.encodeCall(MorphoMoneyMarket.supplyCollateral, (ACCOUNT_BALANCE, wstETH, marketId, morpho)))
        );
        actions2.push(
            address(morphoMoneyMarket)
                .delegateAction(
                    abi.encodeCall(MorphoMoneyMarket.borrow, (flashLoanAmount, usdc, address(flashLoanProvider), marketId, morpho))
                )
        );

        rootActions.push(
            address(ownableExecutor)
                .action(abi.encodeCall(OwnableExecutor.executeActions, (IERC7579Execution(holdingAccount1), actions1.pack())))
        );
        rootActions.push(
            address(ownableExecutor)
                .action(abi.encodeCall(OwnableExecutor.executeActions, (IERC7579Execution(holdingAccount2), actions2.pack())))
        );

        _flashLoan(rootAccount, rootActions, usdc, flashLoanAmount, holdingAccount1);
        _executeActions(rootAccount, owner, rootActions);

        assertEqDecimal(aaveMoneyMarket.collateralBalance(holdingAccount1, wstETH, pool), 0, 18, "aave collateral balance");
        assertEqDecimal(aaveMoneyMarket.debtBalance(holdingAccount1, usdc, pool), 0, 6, "aave debt balance");

        assertEqDecimal(
            morphoMoneyMarket.collateralBalance(holdingAccount2, wstETH, marketId, morpho),
            10.000011619060644669e18,
            18,
            "morpho collateral balance"
        );
        assertApproxEqAbsDecimal(
            morphoMoneyMarket.debtBalance(holdingAccount2, usdc, marketId, morpho), flashLoanAmount, 1, 6, "morpho debt balance"
        );

        assertEqDecimal(usdc.balanceOf(holdingAccount1), 1.503549e6, 6, "dust usdc balance");
    }

    function _flashLoan(address account, Action[] storage actions, IERC20 token, uint256 amount, address receiver) internal {
        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        // delete doesn't work with a storage pointer
        while (actions.length > 0) actions.pop();
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
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
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            receiver
                        )
                    )
                )
        );
    }

}
