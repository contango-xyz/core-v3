//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "../BaseTest.t.sol";

import { Packing } from "@openzeppelin/contracts/utils/Packing.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { Action, PackedAction } from "../../src/types/Action.sol";
import { ActionLib } from "../ActionLib.sol";
import { IContangoV2Lens, IContangoV2Vault, IContangoV2, ContangoV2, ContangoV2PositionNFT } from "../../src/dependencies/ContangoV2.sol";
import { FlashLoanAction } from "../../src/flashloan/FlashLoanAction.sol";
import { FlashLoanProvider } from "../FlashLoanProvider.t.sol";
import { AaveMoneyMarket } from "../../src/moneymarkets/aave/AaveMoneyMarket.sol";
import { IPoolAddressesProvider } from "../../src/moneymarkets/aave/dependencies/IPoolAddressesProvider.sol";
import { IPool } from "../../src/moneymarkets/aave/dependencies/IPool.sol";
import { ACCOUNT_BALANCE } from "../../src/constants.sol";
import { IContangoV2Maestro } from "../../src/dependencies/ContangoV2.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { TokenAction } from "../../src/actions/TokenAction.sol";

contract MigrateFromContangoV2Test is BaseTest {

    using ActionLib for *;
    using Packing for *;
    using SafeCast for uint256;

    Action[] internal actions;

    IContangoV2Lens internal lens = IContangoV2Lens(0xe03835Dfae2644F37049c1feF13E8ceD6b1Bb72a);
    IContangoV2Maestro internal maestro = IContangoV2Maestro(0xa6a147946FACAc9E0B99824870B36088764f969F);
    IContangoV2 public contango;
    IContangoV2Vault public vault;
    ContangoV2PositionNFT public positionNFT;

    FlashLoanProvider internal flashLoanProvider;
    address internal owner;
    uint256 internal ownerPk;
    address internal account;
    address internal treasury;

    function setUp() public override {
        vm.createSelectFork("mainnet", 22_895_431);
        super.setUp();

        flashLoanProvider = new FlashLoanProvider();

        positionNFT = lens.contango().positionNFT();
        contango = lens.contango();
        vault = lens.contango().vault();

        (owner, ownerPk) = makeAddrAndKey("owner");
        treasury = makeAddr("treasury");

        account = newAccount(owner);
        vm.label(account, "Account");
    }

    function test_migrateFromContangoV2() public {
        address positionOwner = 0x56CF0ff00fd6CfB23ce964C6338B228B0FA76640;
        ContangoV2.PositionId positionId = ContangoV2.PositionId.wrap(0x7773744554485745544800000000000001ffffffff0100000000000000000224);
        ContangoV2.Balances memory balances = lens.balances(positionId);
        ContangoV2.Instrument memory instrument =
            lens.contango().instrument(ContangoV2.Symbol.wrap(ContangoV2.PositionId.unwrap(positionId).extract_32_16(0)));

        IPoolAddressesProvider aavePoolAddressesProvider = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        IPool aavePool = aavePoolAddressesProvider.getPool();
        AaveMoneyMarket aaveMoneyMarket = AaveMoneyMarket(_deployAction(type(AaveMoneyMarket).creationCode, ""));

        flashLoanProvider.setFee(0.005e4); // 0.05% fee
        uint256 flashLoanAmount = balances.debt * 1.00025e18 / 1e18; // 0.025% buffer/fee
        uint256 flashLoanFee = flashLoanProvider.flashFee(instrument.quote, flashLoanAmount);
        deal(address(instrument.quote), address(flashLoanProvider), type(uint128).max);

        {
            // Approve the quote
            actions.push(
                address(tokenAction)
                    .delegateAction(abi.encodeCall(TokenAction.approve, (instrument.quote, flashLoanAmount, address(vault))))
            );

            // Deposit enough to cover the debt
            actions.push(address(maestro).action(abi.encodeCall(IContangoV2Maestro.deposit, (instrument.quote, flashLoanAmount))));

            // Repay the debt
            actions.push(
                address(contango)
                    .action(
                        abi.encodeCall(
                            IContangoV2.trade,
                            (
                                ContangoV2.TradeParams({
                                    positionId: positionId,
                                    quantity: 0,
                                    limitPrice: 0,
                                    cashflowCcy: ContangoV2.Currency.Quote,
                                    cashflow: flashLoanAmount.toInt256()
                                }),
                                _noExecution()
                            )
                        )
                    )
            );

            // Close the position
            actions.push(
                address(contango)
                    .action(
                        abi.encodeCall(
                            IContangoV2.trade,
                            (
                                ContangoV2.TradeParams({
                                    positionId: positionId,
                                    quantity: type(int256).min,
                                    limitPrice: 0,
                                    cashflowCcy: ContangoV2.Currency.Base,
                                    cashflow: -1
                                }),
                                _noExecution()
                            )
                        )
                    )
            );

            // Withdraw the collateral and leave it on the safe
            actions.push(address(maestro).action(abi.encodeCall(IContangoV2Maestro.withdraw, (instrument.base, 0, account))));

            // Be nice with V2 accounting
            actions.push(address(contango).action(abi.encodeCall(IContangoV2.donatePosition, (positionId, positionOwner))));

            // Enable e-mode
            actions.push(address(aavePool).action(abi.encodeCall(IPool.setUserEMode, (1))));

            // Supply the base
            actions.push(
                address(aaveMoneyMarket)
                    .delegateAction(abi.encodeCall(AaveMoneyMarket.supply, (ACCOUNT_BALANCE, instrument.base, aavePool)))
            );

            // Borrow the quote
            actions.push(
                address(aaveMoneyMarket)
                    .delegateAction(
                        abi.encodeCall(AaveMoneyMarket.borrow, (flashLoanAmount + flashLoanFee, instrument.quote, account, aavePool))
                    )
            );
        }

        {
            actions.push(
                address(tokenAction)
                    .delegateAction(
                        abi.encodeCall(TokenAction.push, (instrument.quote, flashLoanAmount + flashLoanFee, address(flashLoanProvider)))
                    )
            );

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
                                instrument.quote,
                                flashLoanAmount,
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

        // Take any leftover balances as fees
        actions.push(address(maestro).action(abi.encodeCall(IContangoV2Maestro.withdraw, (instrument.base, 0, treasury))));
        actions.push(address(maestro).action(abi.encodeCall(IContangoV2Maestro.withdraw, (instrument.quote, 0, treasury))));

        (address target, bytes memory data) = _encodeActions(account, ownerPk, actions);

        vm.prank(positionOwner);
        positionNFT.safeTransferFrom(
            positionOwner, account, uint256(ContangoV2.PositionId.unwrap(positionId)), abi.encodePacked(target, data)
        );

        assertEqDecimal(lens.contango().vault().balanceOf(instrument.base, account), 0, 18, "action base vault balance");
        assertEqDecimal(lens.contango().vault().balanceOf(instrument.quote, account), 0, 18, "action quote vault balance");
        assertEqDecimal(
            aaveMoneyMarket.collateralBalance(account, instrument.base, aavePool), balances.collateral, 18, "safe collateral balance"
        );
        assertEqDecimal(
            aaveMoneyMarket.debtBalance(account, instrument.quote, aavePool), flashLoanAmount + flashLoanFee, 18, "safe debt balance"
        );
        assertEqDecimal(instrument.base.balanceOf(account), 0, 18, "safe base balance");
        assertEqDecimal(instrument.quote.balanceOf(account), 0, 18, "safe quote balance");
        assertEqDecimal(instrument.quote.balanceOf(treasury), 0.611_034_857_874_110_659 ether, 18, "treasury quote balance");
    }

    function _noExecution() internal pure returns (ContangoV2.ExecutionParams memory executionParams) {
        executionParams = ContangoV2.ExecutionParams({
            spender: address(0), router: address(0), swapAmount: 0, swapBytes: bytes(""), flashLoanProvider: address(0)
        });
    }

}
