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
import { ACCOUNT_BALANCE } from "../../src/constants.sol";
import { TokenAction } from "../../src/actions/TokenAction.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { FlashLoanAction } from "../../src/flashloan/FlashLoanAction.sol";
import { MorphoMoneyMarket, MorphoMarketId, IMorpho, MarketParams } from "../../src/moneymarkets/morpho/MorphoMoneyMarket.sol";
import { Authorization, Signature } from "../../src/moneymarkets/morpho/dependencies/IMorpho.sol";
import { EulerMoneyMarket, IEthereumVaultConnector, IEulerVault } from "../../src/moneymarkets/euler/EulerMoneyMarket.sol";
import { CometMoneyMarket, IComet } from "../../src/moneymarkets/comet/CometMoneyMarket.sol";
import { ICometExt } from "../../src/moneymarkets/comet/dependencies/IComet.sol";

contract PositionImporterTest is BaseTest {

    using Packing for *;
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH9;
    using Solarray for *;
    using MessageHashUtils for *;
    using ActionLib for *;

    Action[] actions;

    IWETH9 internal weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    IERC20 internal gho = IERC20(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);

    FlashLoanProvider internal flashLoanProvider;
    address internal owner;
    uint256 internal ownerPk;
    address internal account;
    address internal treasury;

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
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

        account = newAccount(owner);
        vm.label(account, "Account");
    }

    function test_importAavePosition() public {
        AaveMoneyMarket aaveMoneyMarket = AaveMoneyMarket(_deployAction(type(AaveMoneyMarket).creationCode, ""));
        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        IPool pool = poolAddressesProvider.getPool();
        IERC20 aWeth = IERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);

        vm.prank(treasury);
        weth.safeTransfer(owner, 1e18);

        vm.startPrank(owner);
        weth.approve(address(pool), 1e18);
        pool.supply(weth, 1e18, owner, 0);
        pool.borrow(usdc, 500e6, 2, 0, owner);
        vm.stopPrank();

        skip(3 days);

        uint256 collateralBalance = aWeth.balanceOf(owner);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (usdc, type(uint256).max, address(pool)))));
        actions.push(address(pool).action(abi.encodeCall(IPool.repay, (usdc, 505e6, 2, owner))));
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (usdc, 0, address(pool)))));
        actions.push(
            address(tokenAction)
                .delegateAction(
                    abi.encodeCall(
                        TokenAction.pullWithPermit,
                        (aWeth, collateralBalance, owner, signPermit(aWeth, owner, ownerPk, collateralBalance, account))
                    )
                )
        );

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;

        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(aaveMoneyMarket)
                .delegateAction(
                    abi.encodeCall(
                        AaveMoneyMarket.flashBorrow,
                        (
                            usdc,
                            505e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            pool
                        )
                    )
                )
        );

        _executeActions(account, owner, actions);

        assertEqDecimal(aaveMoneyMarket.collateralBalance(account, weth, pool), 1.000168272686551062e18, 18, "imported collateral balance");
        assertEqDecimal(aaveMoneyMarket.debtBalance(account, usdc, pool), 504.999999e6, 6, "imported debt balance");
        assertEqDecimal(usdc.balanceOf(account), 4.796432e6, 6, "dust usdc balance");
    }

    function test_importMorphoPosition() public {
        IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        MorphoMoneyMarket morphoMoneyMarket = MorphoMoneyMarket(_deployAction(type(MorphoMoneyMarket).creationCode, abi.encode(morpho)));
        MorphoMarketId marketId = MorphoMarketId.wrap(0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);

        vm.prank(treasury);
        wstETH.safeTransfer(owner, 1e18);

        vm.startPrank(owner);
        wstETH.approve(address(morpho), 1e18);
        morpho.supplyCollateral({ marketParams: marketParams, assets: 1e18, onBehalf: owner, data: "" });
        morpho.borrow({ marketParams: marketParams, assets: 500e6, shares: 0, onBehalf: owner, receiver: owner });
        vm.stopPrank();

        skip(3 days);

        uint256 borrowShares = morpho.position(marketId, owner).borrowShares;

        Authorization memory authorization = Authorization({
            authorizer: owner, authorized: account, isAuthorized: true, nonce: morpho.nonce(owner), deadline: block.timestamp + 1 days
        });
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)"),
                authorization
            )
        );
        bytes32 digest = keccak256(bytes.concat("\x19\x01", morpho.DOMAIN_SEPARATOR(), hashStruct));
        Signature memory signature;
        (signature.v, signature.r, signature.s) = vm.sign(ownerPk, digest);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (usdt, type(uint256).max, address(morpho)))));
        actions.push(address(morpho).action(abi.encodeCall(IMorpho.repay, (marketParams, 0, borrowShares, owner, ""))));
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (usdt, 0, address(morpho)))));
        actions.push(address(morpho).action(abi.encodeCall(IMorpho.setAuthorizationWithSig, (authorization, signature))));
        actions.push(address(morpho).action(abi.encodeCall(IMorpho.withdrawCollateral, (marketParams, 1e18, owner, account))));
        actions.push(address(morphoMoneyMarket).delegateAction(abi.encodeCall(MorphoMoneyMarket.supply, (1e18, wstETH, marketId, morpho))));
        actions.push(
            address(morphoMoneyMarket).delegateAction(abi.encodeCall(MorphoMoneyMarket.borrow, (505e6, usdt, account, marketId, morpho)))
        );

        _flashLoan(usdt, 505e6);
        _executeActions(account, owner, actions);

        assertEqDecimal(morphoMoneyMarket.collateralBalance(account, wstETH, marketId, morpho), 1e18, 18, "imported collateral balance");
        assertEqDecimal(morphoMoneyMarket.debtBalance(account, usdt, marketId, morpho), 505.000001e6, 6, "imported debt balance");
        assertEqDecimal(usdt.balanceOf(account), 4.854278e6, 6, "dust usdt balance");
    }

    function test_importEulerPosition() public {
        IEthereumVaultConnector evc = IEthereumVaultConnector(payable(0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383));
        EulerMoneyMarket eulerMoneyMarket = EulerMoneyMarket(_deployAction(type(EulerMoneyMarket).creationCode, abi.encode(evc)));
        IEulerVault baseVault = IEulerVault(0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2);
        IEulerVault quoteVault = IEulerVault(0xc2d36F41841B420937643dcccbEa8163D4F59B6c);
        IERC20 quoteAsset = IERC20(quoteVault.asset());

        vm.prank(treasury);
        weth.safeTransfer(owner, 1e18);

        vm.startPrank(owner);
        weth.approve(address(baseVault), 1e18);
        evc.enableCollateral(owner, baseVault);
        baseVault.deposit(1e18, owner);
        evc.enableController(owner, quoteVault);
        quoteVault.borrow(500e18, owner);
        vm.stopPrank();

        skip(60 seconds);

        uint256 collateralShares = baseVault.balanceOf(owner);
        vm.prank(owner);
        baseVault.approve(address(permit2), type(uint256).max);

        actions.push(
            address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (quoteAsset, type(uint256).max, address(quoteVault))))
        );
        actions.push(address(quoteVault).action(abi.encodeCall(IEulerVault.repay, (type(uint256).max, owner))));
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (quoteAsset, 0, address(quoteVault)))));
        actions.push(
            address(tokenAction)
                .delegateAction(
                    abi.encodeCall(
                        TokenAction.pullWithPermit,
                        (
                            baseVault,
                            collateralShares,
                            owner,
                            signPermit2SignatureTransfer(baseVault, owner, ownerPk, collateralShares, account)
                        )
                    )
                )
        );
        actions.push(address(evc).action(abi.encodeCall(IEthereumVaultConnector.enableCollateral, (account, baseVault))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;

        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(address(evc).action(abi.encodeCall(IEthereumVaultConnector.enableController, (account, quoteVault))));
        actions.push(
            address(eulerMoneyMarket)
                .delegateAction(
                    abi.encodeCall(
                        EulerMoneyMarket.flashBorrow,
                        (
                            evc,
                            quoteVault,
                            505e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            )
                        )
                    )
                )
        );

        _executeActions(account, owner, actions);

        assertEqDecimal(
            eulerMoneyMarket.collateralBalance(account, weth, baseVault), 1.000000042514020079e18, 18, "imported collateral balance"
        );
        assertEqDecimal(eulerMoneyMarket.debtBalance(account, quoteAsset, quoteVault), 505e18, 18, "imported debt balance");
        assertEqDecimal(quoteAsset.balanceOf(account), 4.999969887711037604e18, 18, "dust quoteAsset balance");
    }

    function test_importCometPosition() public {
        CometMoneyMarket cometMoneyMarket = CometMoneyMarket(_deployAction(type(CometMoneyMarket).creationCode, ""));
        IComet comet = IComet(0x5D409e56D886231aDAf00c8775665AD0f9897b56);

        vm.prank(treasury);
        weth.safeTransfer(owner, 1e18);

        vm.startPrank(owner);
        weth.approve(address(comet), 1e18);
        comet.supply(weth, 1e18);
        comet.withdrawTo(owner, usds, 500e18);
        vm.stopPrank();

        skip(3 days);

        uint256 collateralBalance = comet.collateralBalanceOf(owner, weth);

        bytes32 DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 AUTHORIZATION_TYPEHASH =
            keccak256("Authorization(address owner,address manager,bool isAllowed,uint256 nonce,uint256 expiry)");

        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(comet.name())), keccak256(bytes(comet.version())), block.chainid, address(comet))
        );
        bytes32 structHash =
            keccak256(abi.encode(AUTHORIZATION_TYPEHASH, owner, account, true, comet.userNonce(owner), block.timestamp + 1 days));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (usds, type(uint256).max, address(comet)))));
        actions.push(address(comet).action(abi.encodeCall(IComet.supplyTo, (owner, usds, type(uint256).max))));
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.approve, (usds, 0, address(comet)))));
        actions.push(
            address(comet)
                .action(
                    abi.encodeCall(ICometExt.allowBySig, (owner, account, true, comet.userNonce(owner), block.timestamp + 1 days, v, r, s))
                )
        );
        actions.push(address(comet).action(abi.encodeCall(IComet.transferAssetFrom, (owner, account, weth, collateralBalance))));
        actions.push(address(cometMoneyMarket).delegateAction(abi.encodeCall(CometMoneyMarket.borrow, (505e18, usds, account, comet))));

        _flashLoan(usds, 505e18);
        _executeActions(account, owner, actions);

        assertEqDecimal(cometMoneyMarket.collateralBalance(account, weth, comet), 1e18, 18, "imported collateral balance");
        assertEqDecimal(cometMoneyMarket.debtBalance(account, usds, comet), 505e18, 18, "imported debt balance");
        assertEqDecimal(usds.balanceOf(account), 4.835796174291454832e18, 18, "dust usds balance");
    }

    uint256 vaultId = 54;

    function _flashLoan(IERC20 token, uint256 amount) internal {
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (token, amount, address(flashLoanProvider)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
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
                            account
                        )
                    )
                )
        );
    }

}
