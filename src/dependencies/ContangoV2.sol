// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library ContangoV2 {

    enum Currency {
        None,
        Base,
        Quote
    }

    type PositionId is bytes32;
    type Symbol is bytes16;
    type MoneyMarketId is uint8;

    struct ExecutionParams {
        address spender;
        address router;
        uint256 swapAmount;
        bytes swapBytes;
        address flashLoanProvider;
    }

    struct Instrument {
        IERC20 base;
        uint256 baseUnit;
        IERC20 quote;
        uint256 quoteUnit;
        bool closingOnly;
    }

    struct SwapInfo {
        Currency inputCcy;
        int256 input;
        int256 output;
        uint256 price;
    }

    struct Trade {
        int256 quantity;
        SwapInfo swap;
        Currency cashflowCcy;
        int256 cashflow;
        uint256 fee;
        Currency feeCcy;
        uint256 forwardPrice;
    }

    struct TradeParams {
        PositionId positionId;
        int256 quantity;
        uint256 limitPrice;
        Currency cashflowCcy;
        int256 cashflow;
    }

    struct Balances {
        uint256 collateral;
        uint256 debt;
    }

}

interface IContangoV2 {

    error CashflowCcyRequired();
    error ClosingOnly();
    error InstrumentAlreadyExists(ContangoV2.Symbol symbol);
    error InsufficientBaseCashflow(int256 expected, int256 actual);
    error InsufficientBaseOnOpen(uint256 expected, int256 actual);
    error InvalidCashflowCcy();
    error InvalidInstrument(ContangoV2.Symbol symbol);
    error NotFlashBorrowProvider(address msgSender);
    error OnlyFullClosureAllowedAfterExpiry();
    error PriceAboveLimit(uint256 limit, uint256 actual);
    error PriceBelowLimit(uint256 limit, uint256 actual);
    error Unauthorised(address msgSender);
    error UnexpectedCallback();
    error UnexpectedTrade();
    error ZeroDestination();
    error ZeroPayer();

    event PositionUpserted(
        ContangoV2.PositionId indexed positionId,
        address indexed owner,
        address indexed tradedBy,
        ContangoV2.Currency cashflowCcy,
        int256 cashflow,
        int256 quantityDelta,
        uint256 price,
        uint256 fee,
        ContangoV2.Currency feeCcy
    );

    function instrument(ContangoV2.Symbol symbol) external view returns (ContangoV2.Instrument memory instrument_);
    function positionNFT() external view returns (ContangoV2PositionNFT);
    function vault() external view returns (IContangoV2Vault);
    function trade(ContangoV2.TradeParams memory tradeParams, ContangoV2.ExecutionParams memory execParams)
        external
        payable
        returns (ContangoV2.PositionId, ContangoV2.Trade memory);
    function donatePosition(ContangoV2.PositionId positionId, address to) external;

}

interface IContangoV2Vault {

    error NotEnoughBalance(address token, uint256 balance, uint256 requested);
    error SenderIsNotNativeToken(address msgSender, address nativeToken);
    error UnsupportedToken(address token);
    error ZeroAddress();
    error ZeroAmount();
    error ZeroDestination();
    error ZeroPayer();

    event Deposited(IERC20 indexed token, address indexed account, uint256 amount);
    event Withdrawn(IERC20 indexed token, address indexed account, uint256 amount, address indexed to);

    function balanceOf(IERC20 token, address owner) external view returns (uint256);
    function deposit(IERC20 token, address account, uint256 amount) external returns (uint256);
    function withdraw(IERC20 token, address account, uint256 amount, address to) external returns (uint256);

}

interface IContangoV2Lens {

    error CallFailed(address target, bytes4 selector);
    error InvalidMoneyMarket(ContangoV2.MoneyMarketId mm);

    function contango() external view returns (IContangoV2);
    function balances(ContangoV2.PositionId positionId) external returns (ContangoV2.Balances memory balances_);

}

interface ContangoV2PositionNFT is IERC721 {

    function positionOwnerOf(ContangoV2.PositionId positionId) external view returns (address);

}

interface IContangoV2Maestro {

    error InvalidCashflow();
    error InsufficientPermitAmount(uint256 required, uint256 actual);
    error NotNativeToken(IERC20 token);
    error UnknownIntegration(address integration);

    function contango() external view returns (IContangoV2);
    function vault() external view returns (IContangoV2Vault);
    function positionNFT() external view returns (ContangoV2PositionNFT);

    // =================== Funding primitives ===================

    function deposit(IERC20 token, uint256 amount) external payable returns (uint256);

    function withdraw(IERC20 token, uint256 amount, address to) external payable returns (uint256);

    function withdrawNative(uint256 amount, address to) external payable returns (uint256);

    // =================== Trading actions ===================

    function trade(ContangoV2.TradeParams calldata tradeParams, ContangoV2.ExecutionParams calldata execParams)
        external
        payable
        returns (ContangoV2.PositionId, ContangoV2.Trade memory);

}
