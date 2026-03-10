//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { AbstractPositionLifecycleTest } from "./AbstractPositionLifecycle.t.sol";

import { IWETH9 } from "../../src/dependencies/IWETH9.sol";
import { AaveMoneyMarket } from "../../src/moneymarkets/aave/AaveMoneyMarket.sol";
import { IPoolAddressesProvider } from "../../src/moneymarkets/aave/dependencies/IPoolAddressesProvider.sol";
import { IPool } from "../../src/moneymarkets/aave/dependencies/IPool.sol";
import { MorphoMoneyMarket, IMorpho, MorphoMarketId } from "../../src/moneymarkets/morpho/MorphoMoneyMarket.sol";
import { CometMoneyMarket, IComet } from "../../src/moneymarkets/comet/CometMoneyMarket.sol";
import { EulerMoneyMarket, IEulerVault, IEthereumVaultConnector } from "../../src/moneymarkets/euler/EulerMoneyMarket.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";
import { ERC7579Lib } from "../../src/modules/base/ERC7579Utils.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { PackedAction, Action } from "../../src/types/Action.sol";
import { ActionLib } from "../ActionLib.sol";

contract AavePositionLifecycleTest is AbstractPositionLifecycleTest {

    using ERC7579Lib for *;
    using ActionLib for *;

    AaveMoneyMarket aaveMoneyMarket;
    IPoolAddressesProvider provider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IPool pool;

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
        super.setUp();

        pool = provider.getPool();

        aaveMoneyMarket = AaveMoneyMarket(_deployAction(type(AaveMoneyMarket).creationCode, ""));
        supportsFlashBorrow = true;
    }

    function _flashBorrow(IERC20 token, uint256 amount) internal virtual override {
        PackedAction[] memory packedCalls = holdingActions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(holdingAccount), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete holdingActions;

        holdingActions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        holdingActions.push(
            address(aaveMoneyMarket)
                .delegateAction(
                    abi.encodeCall(
                        AaveMoneyMarket.flashBorrow,
                        (
                            token,
                            amount,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(holdingAccount), packedCalls, signature, innerNonce)
                                )
                            ),
                            pool
                        )
                    )
                )
        );
    }

    function _supplyToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.supply, (amount, base, pool))));
    }

    function _borrowFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.borrow, (amount, quote, holdingAccount, pool))));
    }

    function _repayToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.repay, (amount, quote, pool))));
    }

    function _withdrawFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(
            address(aaveMoneyMarket).delegateAction(abi.encodeCall(AaveMoneyMarket.withdraw, (amount, base, holdingAccount, pool)))
        );
    }

    function _collateralOnMarket() internal view override returns (address, bytes memory) {
        return (address(aaveMoneyMarket), abi.encodeCall(AaveMoneyMarket.collateralBalance, (holdingAccount, base, pool)));
    }

    function _debtOnMarket() internal view override returns (address, bytes memory) {
        return (address(aaveMoneyMarket), abi.encodeCall(AaveMoneyMarket.debtBalance, (holdingAccount, quote, pool)));
    }

}

contract MorphoPositionLifecycleTest is AbstractPositionLifecycleTest {

    using ActionLib for *;

    MorphoMoneyMarket morphoMoneyMarket;
    MorphoMarketId marketId = MorphoMarketId.wrap(0x6029eea874791e01e2f3ce361f2e08839cd18b1e26eea6243fa3e43fe8f6fa23);
    IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
        base = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        quote = IERC20(0xA0d69E286B938e21CBf7E51D71F6A4c8918f482F);
        super.setUp();

        morphoMoneyMarket = MorphoMoneyMarket(_deployAction(type(MorphoMoneyMarket).creationCode, ""));
    }

    function _supplyToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(morphoMoneyMarket).delegateAction(abi.encodeCall(MorphoMoneyMarket.supply, (amount, base, marketId, morpho))));
    }

    function _borrowFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(
            address(morphoMoneyMarket)
                .delegateAction(abi.encodeCall(MorphoMoneyMarket.borrow, (amount, quote, holdingAccount, marketId, morpho)))
        );
    }

    function _repayToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(morphoMoneyMarket).delegateAction(abi.encodeCall(MorphoMoneyMarket.repay, (amount, quote, marketId, morpho))));
    }

    function _withdrawFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(
            address(morphoMoneyMarket)
                .delegateAction(abi.encodeCall(MorphoMoneyMarket.withdraw, (amount, base, holdingAccount, marketId, morpho)))
        );
    }

    function _collateralOnMarket() internal view override returns (address, bytes memory) {
        return (address(morphoMoneyMarket), abi.encodeCall(MorphoMoneyMarket.collateralBalance, (holdingAccount, base, marketId, morpho)));
    }

    function _debtOnMarket() internal view override returns (address, bytes memory) {
        return (address(morphoMoneyMarket), abi.encodeCall(MorphoMoneyMarket.debtBalance, (holdingAccount, quote, marketId, morpho)));
    }

}

contract CometPositionLifecycleTest is AbstractPositionLifecycleTest {

    using ActionLib for *;

    CometMoneyMarket cometMoneyMarket;
    IComet comet = IComet(0x5D409e56D886231aDAf00c8775665AD0f9897b56);

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
        quote = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
        super.setUp();

        cometMoneyMarket = CometMoneyMarket(_deployAction(type(CometMoneyMarket).creationCode, ""));
    }

    function _supplyToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(cometMoneyMarket).delegateAction(abi.encodeCall(CometMoneyMarket.supply, (amount, base, comet))));
    }

    function _borrowFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(
            address(cometMoneyMarket).delegateAction(abi.encodeCall(CometMoneyMarket.borrow, (amount, quote, holdingAccount, comet)))
        );
    }

    function _repayToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(cometMoneyMarket).delegateAction(abi.encodeCall(CometMoneyMarket.repay, (amount, quote, comet))));
    }

    function _withdrawFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(
            address(cometMoneyMarket).delegateAction(abi.encodeCall(CometMoneyMarket.withdraw, (amount, base, holdingAccount, comet)))
        );
    }

    function _collateralOnMarket() internal view override returns (address, bytes memory) {
        return (address(cometMoneyMarket), abi.encodeCall(CometMoneyMarket.collateralBalance, (holdingAccount, base, comet)));
    }

    function _debtOnMarket() internal view override returns (address, bytes memory) {
        return (address(cometMoneyMarket), abi.encodeCall(CometMoneyMarket.debtBalance, (holdingAccount, quote, comet)));
    }

}

contract EulerPositionLifecycleTest is AbstractPositionLifecycleTest {

    using ERC7579Lib for *;
    using ActionLib for *;

    EulerMoneyMarket eulerMoneyMarket;
    IEulerVault baseVault = IEulerVault(0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2);
    IEulerVault quoteVault = IEulerVault(0xc2d36F41841B420937643dcccbEa8163D4F59B6c);
    IEthereumVaultConnector evc = IEthereumVaultConnector(payable(0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383));

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
        quote = IERC20(quoteVault.asset());
        super.setUp();

        vm.startPrank(treasury);
        quote.approve(address(quoteVault), type(uint256).max);
        quoteVault.deposit(100_000e18, treasury);
        vm.stopPrank();

        eulerMoneyMarket = EulerMoneyMarket(_deployAction(type(EulerMoneyMarket).creationCode, ""));

        supportsFlashBorrow = true;
        supportsFlashWithdraw = true;
    }

    function _flashBorrow(IERC20, uint256 amount) internal virtual override {
        PackedAction[] memory packedCalls = holdingActions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(holdingAccount), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete holdingActions;

        holdingActions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        holdingActions.push(address(evc).action(abi.encodeCall(IEthereumVaultConnector.enableController, (holdingAccount, quoteVault))));
        holdingActions.push(
            address(eulerMoneyMarket)
                .delegateAction(
                    abi.encodeCall(
                        EulerMoneyMarket.flashBorrow,
                        (
                            evc,
                            quoteVault,
                            amount,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(holdingAccount), packedCalls, signature, innerNonce)
                                )
                            )
                        )
                    )
                )
        );
    }

    function _flashWithdraw(IERC20, uint256 amount) internal virtual override {
        PackedAction[] memory packedCalls = holdingActions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(holdingAccount), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete holdingActions;

        holdingActions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));

        holdingActions.push(
            address(eulerMoneyMarket)
                .delegateAction(
                    abi.encodeCall(
                        EulerMoneyMarket.flashWithdraw,
                        (
                            evc,
                            baseVault,
                            amount,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(holdingAccount), packedCalls, signature, innerNonce)
                                )
                            )
                        )
                    )
                )
        );
    }

    function _supplyToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(evc).action(abi.encodeCall(IEthereumVaultConnector.enableCollateral, (holdingAccount, baseVault))));
        actions.push(address(eulerMoneyMarket).delegateAction(abi.encodeCall(EulerMoneyMarket.supply, (amount, base, baseVault))));
    }

    function _borrowFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(evc).action(abi.encodeCall(IEthereumVaultConnector.enableController, (holdingAccount, quoteVault))));
        actions.push(
            address(eulerMoneyMarket).delegateAction(abi.encodeCall(EulerMoneyMarket.borrow, (amount, quote, holdingAccount, quoteVault)))
        );
    }

    function _repayToMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(address(eulerMoneyMarket).delegateAction(abi.encodeCall(EulerMoneyMarket.repay, (amount, quote, quoteVault))));
    }

    function _withdrawFromMarket(Action[] storage actions, uint256 amount) internal virtual override {
        actions.push(
            address(eulerMoneyMarket).delegateAction(abi.encodeCall(EulerMoneyMarket.withdraw, (amount, base, holdingAccount, baseVault)))
        );
    }

    function _collateralOnMarket() internal view override returns (address, bytes memory) {
        return (address(eulerMoneyMarket), abi.encodeCall(EulerMoneyMarket.collateralBalance, (holdingAccount, base, baseVault)));
    }

    function _debtOnMarket() internal view override returns (address, bytes memory) {
        return (address(eulerMoneyMarket), abi.encodeCall(EulerMoneyMarket.debtBalance, (holdingAccount, quote, quoteVault)));
    }

}
