//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MathLib } from "../../libraries/MathLib.sol";

import { ACCOUNT_BALANCE, DEBT_BALANCE, COLLATERAL_BALANCE } from "../../constants.sol";
import { ERC20Lib } from "../../libraries/ERC20Lib.sol";
import { IComet } from "./dependencies/IComet.sol";

contract CometMoneyMarket {

    using ERC20Lib for IERC20;

    event CometSupply(IComet indexed comet, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index);
    event CometWithdraw(IComet indexed comet, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index, address to);
    event CometSupplyCollateral(IComet indexed comet, IERC20 indexed token, uint256 amount);
    event CometBorrow(IComet indexed comet, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index, address to);
    event CometRepay(IComet indexed comet, IERC20 indexed token, uint256 amount, uint256 shares, uint256 index);
    event CometWithdrawCollateral(IComet indexed comet, IERC20 indexed token, uint256 amount, address to);

    error InvalidAsset(IERC20 asset);

    function supply(uint256 amount, IERC20 token, IComet comet) public returns (uint256 supplied) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        if (amount == 0) return 0;

        uint256 sharesBefore = comet.shares(token);

        token.forceApprove(address(comet), amount);
        comet.supply(token, amount);
        supplied = amount;

        uint256 sharesAfter = comet.shares(token);

        if (address(token) == address(comet.baseToken())) {
            emit CometSupply(comet, token, supplied, sharesAfter - sharesBefore, comet.supplyIndex());
        } else {
            emit CometSupplyCollateral(comet, token, supplied);
        }
    }

    function borrow(uint256 amount, IERC20 token, address to, IComet comet) public returns (uint256 borrowed) {
        if (amount == 0) return 0;

        uint256 sharesBefore = comet.shares(token);

        comet.withdrawTo(to, token, amount);
        borrowed = amount;

        uint256 sharesAfter = comet.shares(token);

        emit CometBorrow(comet, token, borrowed, sharesAfter - sharesBefore, comet.borrowIndex(), to);
    }

    function repay(uint256 amount, IERC20 token, IComet comet) public returns (uint256 repaid) {
        if (amount == ACCOUNT_BALANCE) amount = token.myBalance();
        uint256 debt = debtBalance(address(this), token, comet);
        if (amount == DEBT_BALANCE || amount > debt) amount = debt;
        if (amount == 0) return 0;

        uint256 sharesBefore = comet.shares(token);

        token.forceApprove(address(comet), amount);
        comet.supply(token, amount);
        repaid = amount;

        uint256 sharesAfter = comet.shares(token);

        emit CometRepay(comet, token, repaid, sharesBefore - sharesAfter, comet.borrowIndex());
    }

    function withdraw(uint256 amount, IERC20 token, address to, IComet comet) public returns (uint256 withdrawn) {
        if (amount == COLLATERAL_BALANCE) amount = collateralBalance(address(this), token, comet);
        if (amount == 0) return 0;

        uint256 sharesBefore = comet.shares(token);

        comet.withdrawTo(to, token, amount);
        withdrawn = amount;

        uint256 sharesAfter = comet.shares(token);

        if (address(token) == address(comet.baseToken())) {
            emit CometWithdraw(comet, token, withdrawn, sharesBefore - sharesAfter, comet.supplyIndex(), to);
        } else {
            emit CometWithdrawCollateral(comet, token, withdrawn, to);
        }
    }

    function debtBalance(address account, IERC20 token, IComet comet) public view returns (uint256) {
        require(address(token) == address(comet.baseToken()), InvalidAsset(token));
        return comet.borrowBalanceOf(account);
    }

    function collateralBalance(address account, IERC20 token, IComet comet) public view returns (uint256) {
        require(address(token) != address(comet.baseToken()), InvalidAsset(token));
        return comet.collateralBalanceOf(account, token);
    }

    function oraclePrice(IERC20 token, IComet comet) public view returns (uint256) {
        address feed =
            address(comet.baseToken()) == address(token) ? comet.baseTokenPriceFeed() : comet.getAssetInfoByAddress(token).priceFeed;
        return comet.getPrice(feed);
    }

    function oracleUnit(IComet comet) public view returns (uint256 unit) {
        unit = comet.priceScale();
    }

    function supplyRate(IERC20 token, IComet comet) public view returns (uint256) {
        return address(token) == address(comet.baseToken()) ? comet.getSupplyRate(comet.getUtilization()) : 0;
    }

    function borrowRate(IERC20 token, IComet comet) public view returns (uint256) {
        require(address(token) == address(comet.baseToken()), InvalidAsset(token));
        return comet.getBorrowRate(comet.getUtilization());
    }

}

library CometMoneyMarketLib {

    using MathLib for *;

    function supplyIndex(IComet comet) internal view returns (uint256 index) {
        index = comet.totalsBasic().baseSupplyIndex;
    }

    function borrowIndex(IComet comet) internal view returns (uint256 index) {
        index = comet.totalsBasic().baseBorrowIndex;
    }

    function shares(IComet comet, IERC20 token) internal view returns (uint256) {
        return address(token) == address(comet.baseToken()) ? comet.userBasic(address(this)).principal.abs() : 0;
    }

}

using CometMoneyMarketLib for IComet;
