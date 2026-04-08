//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ACCOUNT_BALANCE, DEBT_BALANCE, COLLATERAL_BALANCE, SUPPLIED_BALANCE, RAY, WAD } from "../../constants.sol";
import { ERC20Lib } from "../../libraries/ERC20Lib.sol";

import { IMorpho, MorphoMarketId, Market, Position, MarketParams } from "./dependencies/IMorpho.sol";
import { SharesMathLib } from "./dependencies/SharesMathLib.sol";
import { MathLib } from "../../libraries/MathLib.sol";

/// @custom:security-contact security@contango.xyz
contract MorphoMoneyMarket {

    using ERC20Lib for IERC20;
    using SharesMathLib for *;

    error InvalidToken(IERC20 token);

    event MorphoSupply(
        IMorpho indexed morpho, MorphoMarketId indexed marketId, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index
    );
    event MorphoSupplyCollateral(IMorpho indexed morpho, MorphoMarketId indexed marketId, IERC20 indexed token, uint256 amount);
    event MorphoBorrow(
        IMorpho indexed morpho,
        MorphoMarketId indexed marketId,
        IERC20 indexed token,
        uint256 amount,
        uint256 shares,
        uint256 index,
        address to
    );
    event MorphoRepay(
        IMorpho indexed morpho, MorphoMarketId indexed marketId, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index
    );
    event MorphoWithdraw(
        IMorpho indexed morpho,
        MorphoMarketId indexed marketId,
        IERC20 indexed token,
        uint256 amount,
        uint256 shares,
        uint256 index,
        address to
    );
    event MorphoWithdrawCollateral(
        IMorpho indexed morpho, MorphoMarketId indexed marketId, IERC20 indexed token, uint256 amount, address to
    );

    /**
     * @notice Supplies collateral assets to a Morpho Blue market.
     * @param amount The amount of collateral to supply. Use `ACCOUNT_BALANCE` for the full token balance.
     * @param token The collateral token of the market.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return supplied The amount of collateral supplied.
     */
    function supplyCollateral(uint256 amount, IERC20 token, MorphoMarketId marketId, IMorpho morpho) public returns (uint256 supplied) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        if (amount == 0) return 0;

        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.collateralToken), InvalidToken(token));

        token.forceApprove(address(morpho), amount);
        morpho.supplyCollateral({ marketParams: marketParams, assets: amount, onBehalf: address(this), data: "" });
        supplied = amount;

        emit MorphoSupplyCollateral(morpho, marketId, token, amount);
    }

    /**
     * @notice Supplies loan-token liquidity to a Morpho Blue market.
     * @param amount The amount of loan token to supply. Use `ACCOUNT_BALANCE` for the full token balance.
     * @param token The loan token of the market.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return supplied The amount of loan token supplied.
     */
    function supplyLoan(uint256 amount, IERC20 token, MorphoMarketId marketId, IMorpho morpho) public returns (uint256 supplied) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        if (amount == 0) return 0;

        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.loanToken), InvalidToken(token));

        token.forceApprove(address(morpho), amount);
        (uint256 assetsSupplied, uint256 sharesSupplied) =
            morpho.supply({ marketParams: marketParams, assets: amount, shares: 0, onBehalf: address(this), data: "" });

        supplied = assetsSupplied;
        emit MorphoSupply(morpho, marketId, token, assetsSupplied, sharesSupplied, morpho.supplyIndex(marketId));
    }

    /**
     * @notice Borrows tokens from a Morpho Blue market.
     * @param amount The amount of tokens to borrow.
     * @param token The ERC20 token to borrow (must be the market's loan token).
     * @param to The address that will receive the borrowed tokens.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return borrowed The actual amount of tokens borrowed.
     */
    function borrow(uint256 amount, IERC20 token, address to, MorphoMarketId marketId, IMorpho morpho) public returns (uint256 borrowed) {
        if (amount == 0) return 0;

        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.loanToken), InvalidToken(token));

        (uint256 assetsBorrowed, uint256 sharesBorrowed) =
            morpho.borrow({ marketParams: marketParams, assets: amount, shares: 0, onBehalf: address(this), receiver: to });

        borrowed = assetsBorrowed;
        emit MorphoBorrow(morpho, marketId, token, assetsBorrowed, sharesBorrowed, morpho.debtIndex(marketId), to);
    }

    /**
     * @notice Repays a borrow on a Morpho Blue market.
     * @dev Calculates the precise number of shares to repay to match the requested amount.
     * @param amount The amount of tokens to repay. Use `ACCOUNT_BALANCE` or `DEBT_BALANCE`.
     * @param token The ERC20 token to repay (must be the market's loan token).
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return repaid The actual amount of tokens repaid.
     */
    function repay(uint256 amount, IERC20 token, MorphoMarketId marketId, IMorpho morpho) public returns (uint256 repaid) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        uint256 debt = debtBalance(address(this), token, marketId, morpho);
        if (amount == DEBT_BALANCE || amount > debt) amount = debt;
        if (amount == 0) return 0;

        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.loanToken), InvalidToken(token));

        Market memory market = morpho.market(marketId);

        uint256 borrowShares = morpho.position(marketId, address(this)).borrowShares;
        uint256 actualShares = amount == debt ? borrowShares : amount.toSharesDown(market.totalBorrowAssets, market.totalBorrowShares);

        if (actualShares > 0) {
            token.forceApprove(
                address(morpho),
                actualShares == borrowShares ? actualShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares) : amount
            );

            (uint256 assetsRepaid, uint256 sharesRepaid) =
                morpho.repay({ marketParams: marketParams, assets: 0, shares: actualShares, onBehalf: address(this), data: "" });

            repaid = assetsRepaid;
            emit MorphoRepay(morpho, marketId, token, assetsRepaid, sharesRepaid, market.debtIndex());
        }
    }

    /**
     * @notice Withdraws collateral assets from a Morpho Blue market.
     * @param amount The amount of collateral to withdraw. Use `COLLATERAL_BALANCE` to withdraw all.
     * @param token The collateral token of the market.
     * @param to The receiver of withdrawn collateral.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return withdrawn The amount of collateral withdrawn.
     */
    function withdrawCollateral(uint256 amount, IERC20 token, address to, MorphoMarketId marketId, IMorpho morpho)
        public
        returns (uint256 withdrawn)
    {
        uint256 balance = collateralBalance(address(this), token, marketId, morpho);
        if (amount == COLLATERAL_BALANCE || amount > balance) amount = balance;
        if (amount == 0) return 0;

        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.collateralToken), InvalidToken(token));

        morpho.withdrawCollateral({ marketParams: marketParams, assets: amount, onBehalf: address(this), receiver: to });
        withdrawn = amount;

        emit MorphoWithdrawCollateral(morpho, marketId, token, amount, to);
    }

    /**
     * @notice Withdraws loan-token supply from a Morpho Blue market.
     * @dev Uses share-based withdrawal to minimize rounding dust on full or partial withdrawals.
     * @param amount The desired amount of loan token to withdraw. Use `SUPPLIED_BALANCE` to withdraw all.
     * @param token The loan token of the market.
     * @param to The receiver of withdrawn loan tokens.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return withdrawn The amount of loan token withdrawn.
     */
    function withdrawLoan(uint256 amount, IERC20 token, address to, MorphoMarketId marketId, IMorpho morpho)
        public
        returns (uint256 withdrawn)
    {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.loanToken), InvalidToken(token));

        uint256 shares = morpho.position(marketId, address(this)).supplyShares;
        if (amount != SUPPLIED_BALANCE) {
            Market memory market = morpho.market(marketId);
            uint256 maxAmount = shares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
            if (amount > maxAmount) amount = maxAmount;
            if (amount == 0) return 0;
            if (amount < maxAmount) shares = amount.toSharesDown(market.totalSupplyAssets, market.totalSupplyShares);
        }
        if (shares == 0) return 0;

        (uint256 assetsWithdrawn, uint256 sharesWithdrawn) =
            morpho.withdraw({ marketParams: marketParams, assets: 0, shares: shares, onBehalf: address(this), receiver: to });

        withdrawn = assetsWithdrawn;
        emit MorphoWithdraw(morpho, marketId, token, assetsWithdrawn, sharesWithdrawn, morpho.supplyIndex(marketId), to);
    }

    /**
     * @notice Gets the debt balance of an account in a Morpho Blue market.
     * @dev Accrues interest before calculating the balance to provide an up-to-date value.
     * @param account The account to query.
     * @param token The loan token of the market.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return The current debt balance.
     */
    function debtBalance(address account, IERC20 token, MorphoMarketId marketId, IMorpho morpho) public returns (uint256) {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.loanToken), InvalidToken(token));

        morpho.accrueInterest(marketParams); // Accrue interest before loading the market state
        Market memory market = morpho.market(marketId);
        Position memory position = morpho.position(marketId, account);
        return position.borrowShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /**
     * @notice Gets the collateral balance of an account in a Morpho Blue market.
     * @param account The account to query.
     * @param token The collateral token of the market.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return The current collateral balance.
     */
    function collateralBalance(address account, IERC20 token, MorphoMarketId marketId, IMorpho morpho) public view returns (uint256) {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.collateralToken), InvalidToken(token));

        return morpho.position(marketId, account).collateral;
    }

    /**
     * @notice Gets the withdrawable loan-token balance for an account.
     * @dev Converts supply shares into assets using the current market totals.
     * @param account The account to query.
     * @param token The loan token of the market.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return The withdrawable loan-token amount.
     */
    function loanBalance(address account, IERC20 token, MorphoMarketId marketId, IMorpho morpho) public view returns (uint256) {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        require(address(token) == address(marketParams.loanToken), InvalidToken(token));

        Position memory position = morpho.position(marketId, account);
        Market memory market = morpho.market(marketId);
        return position.supplyShares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
    }

    /**
     * @notice Reads the current oracle price for a market.
     * @param marketParams The Morpho market parameters.
     * @return The oracle price scaled by Morpho's oracle unit.
     */
    function oraclePrice(IERC20 token, MorphoMarketId marketId, IMorpho morpho) public view returns (uint256) {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);

        if (address(token) == address(marketParams.collateralToken)) return marketParams.oracle.price();
        else if (address(token) == address(marketParams.loanToken)) return marketParams.oracleUnit();
        else revert InvalidToken(token);
    }

    function oracleUnit(MorphoMarketId marketId, IMorpho morpho) public view returns (uint256) {
        return morpho.idToMarketParams(marketId).oracleUnit();
    }

    /**
     * @notice Calculates the supply APY for a token in a Morpho Blue market.
     * @dev Adjusts the borrow rate based on utilization and protocol fees.
     * @param token The token to query.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return The supply APY in WAD.
     */
    function supplyRate(IERC20 token, MorphoMarketId marketId, IMorpho morpho) public view returns (uint256) {
        MarketParams memory params = morpho.idToMarketParams(marketId);
        if (address(token) == address(params.collateralToken)) return 0;

        Market memory market = morpho.market(marketId);
        if (market.totalSupplyAssets == 0) return 0;

        uint256 bRate = params.irm.borrowRateView(params, market);
        uint256 utilization = Math.mulDiv(market.totalBorrowAssets, WAD, market.totalSupplyAssets);
        uint256 sRate = Math.mulDiv(bRate, utilization, WAD);
        sRate = Math.mulDiv(sRate, WAD - market.fee, WAD);

        return MathLib.apy({ rate: sRate, perSeconds: 1 });
    }

    /**
     * @notice Calculates the borrow APY for a token in a Morpho Blue market.
     * @param token The loan token of the market.
     * @param marketId The ID of the Morpho Blue market.
     * @param morpho The Morpho Blue contract.
     * @return The borrow APY in WAD.
     */
    function borrowRate(IERC20 token, MorphoMarketId marketId, IMorpho morpho) public view returns (uint256) {
        MarketParams memory params = morpho.idToMarketParams(marketId);
        require(address(token) == address(params.loanToken), InvalidToken(token));

        return MathLib.apy({ rate: params.irm.borrowRateView(params, morpho.market(marketId)), perSeconds: 1 });
    }

}

library MorphoMoneyMarketLib {

    uint256 private constant ORACLE_PRICE_DECIMALS = 36;

    function debtIndex(Market memory market) internal pure returns (uint256) {
        return Math.mulDiv(market.totalBorrowAssets, RAY, market.totalBorrowShares);
    }

    function debtIndex(IMorpho morpho, MorphoMarketId marketId) internal view returns (uint256) {
        return debtIndex(morpho.market(marketId));
    }

    function supplyIndex(Market memory market) internal pure returns (uint256) {
        return Math.mulDiv(market.totalSupplyAssets, RAY, market.totalSupplyShares);
    }

    function supplyIndex(IMorpho morpho, MorphoMarketId marketId) internal view returns (uint256) {
        return supplyIndex(morpho.market(marketId));
    }

    /**
     * @notice Returns the oracle unit used by the market's oracle.
     * @param marketParams The Morpho market parameters.
     * @return The oracle precision unit.
     */
    function oracleUnit(MarketParams memory marketParams) internal view returns (uint256) {
        uint256 priceDecimals = ORACLE_PRICE_DECIMALS + marketParams.loanToken.decimals() - marketParams.collateralToken.decimals();
        return 10 ** priceDecimals;
    }

}

using MorphoMoneyMarketLib for Market;
using MorphoMoneyMarketLib for IMorpho;
using MorphoMoneyMarketLib for MarketParams;
