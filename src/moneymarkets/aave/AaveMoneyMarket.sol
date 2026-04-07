//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Solarray } from "solarray/Solarray.sol";

import { ACCOUNT_BALANCE, DEBT_BALANCE, COLLATERAL_BALANCE } from "../../constants.sol";

import { IAaveOracle } from "./dependencies/IAaveOracle.sol";
import { IAToken } from "./dependencies/IAToken.sol";
import { DataTypes } from "./dependencies/DataTypes.sol";
import { IPool } from "./dependencies/IPool.sol";
import { IFlashLoanReceiver } from "./dependencies/IFlashLoanReceiver.sol";
import { ERC20Lib } from "../../libraries/ERC20Lib.sol";
import { toArray } from "../../libraries/Arrays.sol";
import { MathLib } from "../../libraries/MathLib.sol";
import { BytesLib } from "../../libraries/BytesLib.sol";

contract AaveMoneyMarket is IFlashLoanReceiver {

    using ERC20Lib for IERC20;
    using Solarray for *;
    using BytesLib for *;

    AaveMoneyMarket private immutable SELF = this;

    event AaveSupply(IPool indexed pool, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index);
    event AaveBorrow(IPool indexed pool, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index, address to);
    event AaveRepay(IPool indexed pool, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index);
    event AaveWithdraw(IPool indexed pool, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index, address to);

    /**
     * @notice Supplies tokens to an Aave V3 pool.
     * @param amount The amount of tokens to supply. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param token The ERC20 token to supply.
     * @param pool The Aave V3 pool.
     * @return supplied The actual amount of tokens supplied.
     */
    function supply(uint256 amount, IERC20 token, IPool pool) public returns (uint256 supplied) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        if (amount == 0) return 0;

        uint256 sharesBefore = pool.collateralShares(token);

        token.forceApprove(address(pool), amount);
        pool.supply({ asset: token, amount: amount, onBehalfOf: address(this), referralCode: 0 });
        supplied = amount;

        uint256 sharesAfter = pool.collateralShares(token);

        emit AaveSupply(pool, token, supplied, sharesAfter - sharesBefore, pool.collateralIndex(token));
    }

    /**
     * @notice Borrows tokens from an Aave V3 pool using variable interest rate.
     * @param amount The amount of tokens to borrow.
     * @param token The ERC20 token to borrow.
     * @param to The address that will receive the borrowed tokens.
     * @param pool The Aave V3 pool.
     * @return borrowed The actual amount of tokens borrowed.
     */
    function borrow(uint256 amount, IERC20 token, address to, IPool pool) public returns (uint256 borrowed) {
        if (amount == 0) return 0;

        uint256 sharesBefore = pool.debtShares(token);

        pool.borrow({
            asset: token,
            amount: amount,
            interestRateMode: uint8(DataTypes.InterestRateMode.VARIABLE),
            referralCode: 0,
            onBehalfOf: address(this)
        });
        borrowed = token.transferOut(address(this), to, amount);

        uint256 sharesAfter = pool.debtShares(token);

        emit AaveBorrow(pool, token, borrowed, sharesAfter - sharesBefore, pool.debtIndex(token), to);
    }

    /**
     * @notice Repays a variable rate borrow on an Aave V3 pool.
     * @param amount The amount of tokens to repay. Use `ACCOUNT_BALANCE` or `DEBT_BALANCE`.
     * @param token The ERC20 token to repay.
     * @param pool The Aave V3 pool.
     * @return repaid The actual amount of tokens repaid.
     */
    function repay(uint256 amount, IERC20 token, IPool pool) public returns (uint256 repaid) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        uint256 debt = debtBalance(address(this), token, pool);
        if (amount == DEBT_BALANCE || amount > debt) amount = debt;
        if (amount == 0) return 0;

        uint256 sharesBefore = pool.debtShares(token);

        token.forceApprove(address(pool), amount);
        repaid = pool.repay({
            asset: token, amount: amount, interestRateMode: uint8(DataTypes.InterestRateMode.VARIABLE), onBehalfOf: address(this)
        });

        uint256 sharesAfter = pool.debtShares(token);

        emit AaveRepay(pool, token, repaid, sharesBefore - sharesAfter, pool.debtIndex(token));
    }

    /**
     * @notice Withdraws tokens from an Aave V3 pool.
     * @param amount The amount of tokens to withdraw. Use `COLLATERAL_BALANCE` for all.
     * @param token The ERC20 token to withdraw.
     * @param to The address that will receive the withdrawn tokens.
     * @param pool The Aave V3 pool.
     * @return withdrawn The actual amount of tokens withdrawn.
     */
    function withdraw(uint256 amount, IERC20 token, address to, IPool pool) public returns (uint256 withdrawn) {
        if (amount == COLLATERAL_BALANCE) amount = type(uint256).max;
        if (amount == 0) return 0;

        uint256 sharesBefore = pool.collateralShares(token);

        withdrawn = pool.withdraw({ asset: token, amount: amount, to: to });

        uint256 sharesAfter = pool.collateralShares(token);

        emit AaveWithdraw(pool, token, withdrawn, sharesBefore - sharesAfter, pool.collateralIndex(token), to);
    }

    function collateralBalance(address account, IERC20 asset, IPool pool) public view returns (uint256) {
        return pool.aToken(asset).balanceOf(account);
    }

    function debtBalance(address account, IERC20 asset, IPool pool) public view returns (uint256) {
        return pool.vToken(asset).balanceOf(account);
    }

    function oraclePrice(IERC20 asset, IAaveOracle oracle) public view returns (uint256) {
        return oracle.getAssetPrice(asset);
    }

    function oracleUnit(IAaveOracle oracle) public view returns (uint256) {
        return oracle.BASE_CURRENCY_UNIT();
    }

    function supplyRate(IERC20 asset, IPool pool) public view returns (uint256) {
        return MathLib.apy({ rate: pool.getReserveData(asset).currentLiquidityRate / 1e9, perSeconds: 365 days });
    }

    function borrowRate(IERC20 asset, IPool pool) public view returns (uint256) {
        return MathLib.apy({ rate: pool.getReserveData(asset).currentVariableBorrowRate / 1e9, perSeconds: 365 days });
    }

    // =============================== Flash Borrowing ===============================

    /**
     * @notice Performs a flash borrow of a single asset from Aave V3.
     * @dev This uses Aave's flash loan mechanism with the `VARIABLE` interest rate mode.
     * If the caller has enough collateral, the borrowed amount is treated as a debt rather than requiring upfront repayment.
     * @param asset The token to borrow.
     * @param amount The amount to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param pool The Aave V3 pool.
     */
    function flashBorrow(IERC20 asset, uint256 amount, bytes calldata data, IPool pool) public {
        flashBorrowMany(toArray(asset), amount.uint256s(), data, pool);
    }

    /**
     * @notice Performs a flash borrow of multiple assets from Aave V3.
     * @dev This uses Aave's flash loan mechanism with the `VARIABLE` interest rate mode for all assets.
     * If the caller has enough collateral, the borrowed amounts are treated as debt.
     * @param assets The array of tokens to borrow.
     * @param amounts The array of amounts to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param pool The Aave V3 pool.
     */
    function flashBorrowMany(IERC20[] memory assets, uint256[] memory amounts, bytes calldata data, IPool pool) public {
        uint256 loans = assets.length;

        uint256[] memory shares = new uint256[](loans);
        for (uint256 i = 0; i < loans; i++) {
            shares[i] = pool.debtShares(assets[i]);
        }

        pool.flashLoan({
            receiverAddress: SELF,
            assets: assets,
            amounts: amounts,
            interestRateModes: uint8(DataTypes.InterestRateMode.VARIABLE).uint256s(),
            onBehalfOf: address(this),
            params: data,
            referralCode: 0
        });

        for (uint256 i = 0; i < loans; i++) {
            IERC20 token = assets[i];
            emit AaveBorrow(pool, token, amounts[i], pool.debtShares(token) - shares[i], pool.debtIndex(token), address(this));
        }
    }

    /**
     * @notice Callback for Aave V3 multi-token flash loans.
     * @dev Executes any additional actions via `data.functionCall()`.
     * @dev The data layout expected is [20 bytes target contract + X bytes calldata].
     * @dev This is inherently safe as it is validated by the account's executor.
     * @param assets The borrowed tokens.
     * @param amounts The borrowed amounts.
     * @param initiator The address that initiated the flash loan.
     * @param data Arbitrary data passed to the callback.
     * @return True if successful.
     */
    function executeOperation(
        IERC20[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address initiator,
        bytes calldata data
    ) public virtual override returns (bool) {
        for (uint256 i = 0; i < assets.length; i++) {
            assets[i].transferOut(address(SELF), initiator, amounts[i]);
        }
        data.functionCall();
        return true;
    }

}

library AaveMoneyMarketLib {

    function aToken(IPool pool, IERC20 asset) internal view returns (IAToken) {
        return pool.getReserveData(asset).aTokenAddress;
    }

    function vToken(IPool pool, IERC20 asset) internal view returns (IAToken) {
        return pool.getReserveData(asset).variableDebtTokenAddress;
    }

    function collateralIndex(IPool pool, IERC20 asset) internal view returns (uint256) {
        return pool.getReserveNormalizedIncome(asset);
    }

    function debtIndex(IPool pool, IERC20 asset) internal view returns (uint256) {
        return pool.getReserveNormalizedVariableDebt(asset);
    }

    function collateralShares(IPool pool, IERC20 asset) internal view returns (uint256) {
        return pool.aToken(asset).scaledBalanceOf(address(this));
    }

    function debtShares(IPool pool, IERC20 asset) internal view returns (uint256) {
        return pool.vToken(asset).scaledBalanceOf(address(this));
    }

}

using AaveMoneyMarketLib for IPool;
