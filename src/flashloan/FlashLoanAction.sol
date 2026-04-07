//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Solarray } from "solarray/Solarray.sol";

import { BytesLib } from "../libraries/BytesLib.sol";
import { ERC20Lib } from "../libraries/ERC20Lib.sol";
import { toArray, fill } from "../libraries/Arrays.sol";

import { IERC7399 } from "./dependencies/IERC7399.sol";
import { IERC3156FlashLender, IERC3156FlashBorrower } from "./dependencies/IERC3156.sol";
import { IPool } from "../moneymarkets/aave/dependencies/IPool.sol";
import { IFlashLoanSimpleReceiver } from "../moneymarkets/aave/dependencies/IFlashLoanSimpleReceiver.sol";
import { IFlashLoanReceiver } from "../moneymarkets/aave/dependencies/IFlashLoanReceiver.sol";
import { DataTypes } from "../moneymarkets/aave/dependencies/DataTypes.sol";
import { IFlashLoaner, IFlashLoanRecipient } from "./dependencies/Balancer.sol";
import { IMorpho } from "../moneymarkets/morpho/dependencies/IMorpho.sol";
import { IMorphoFlashLoanCallback } from "../moneymarkets/morpho/dependencies/IMorphoFlashLoanCallback.sol";
import { IUniswapV3FlashCallback, IUniswapV3Pool, TickMath, IUniswapV3SwapCallback } from "./dependencies/UniswapV3.sol";
import { IAlgebraFlashCallback, IAlgebraPool, IAlgebraSwapCallback } from "../dependencies/dex/Algebra.sol";
import { ISolidlyFlashCallback, ISolidlyPool } from "./dependencies/Solidly.sol";
import { IEulerVault } from "../moneymarkets/euler/dependencies/IEulerVault.sol";
import { IEulerFlashLoan } from "../moneymarkets/euler/dependencies/IEulerFlashLoan.sol";
import { IPendleMarketSwapCallback, IPendleMarketV3 } from "../dependencies/dex/Pendle.sol";

contract FlashLoanAction is
    IERC3156FlashBorrower,
    IFlashLoanSimpleReceiver,
    IFlashLoanReceiver,
    IFlashLoanRecipient,
    IMorphoFlashLoanCallback,
    IUniswapV3FlashCallback,
    IUniswapV3SwapCallback,
    IAlgebraFlashCallback,
    IAlgebraSwapCallback,
    ISolidlyFlashCallback,
    IEulerFlashLoan,
    IPendleMarketSwapCallback
{

    using SafeCast for uint256;

    event FlashLoan(address indexed provider, IERC20 indexed token, uint256 amount, uint256 fee, address fundsReceiver);

    using BytesLib for *;
    using ERC20Lib for IERC20;
    using Solarray for *;

    bytes32 private constant ERC3156_CALLBACK_RESULT = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // ================================================ ERC7399 ================================================

    /**
     * @notice Initiates a flash loan using the ERC7399 standard.
     * @param provider The ERC7399-compliant flash loan provider.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanERC7399(IERC7399 provider, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        provider.flash(fundsReceiver, token, amount, data, this.callbackERC7399);
    }

    /**
     * @notice Callback for ERC7399 flash loans.
     * @dev Executes the `data` as a dynamic function call [20 bytes target address + X bytes calldata].
     * @dev This call is intended to be executed within the context of an account executor, which provides the necessary security validations.
     * @param data The encoded data containing the target and calldata.
     * @return returnData The return data from the function call.
     */
    function callbackERC7399(address, address, IERC20, uint256, uint256, bytes calldata data) external returns (bytes memory returnData) {
        returnData = data.functionCall();
    }

    // ================================================ ERC3156 ================================================

    /**
     * @notice Initiates a flash loan using the ERC3156 standard.
     * @param provider The ERC3156-compliant flash loan lender.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanERC3156(IERC3156FlashLender provider, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver)
        public
    {
        provider.flashLoan(this, token, amount, abi.encodePacked(fundsReceiver, token, amount, data));
    }

    /**
     * @notice Callback for ERC3156 flash loans.
     * @param fee The fee charged for the flash loan.
     * @param metadata Encoded metadata containing funds receiver and additional data.
     * @return Result hash confirming the callback was handled.
     */
    function onFlashLoan(address, IERC20, uint256, uint256 fee, bytes calldata metadata) external returns (bytes32) {
        _simpleCallback({ metadata: metadata, transfer: true, approve: true, fee: fee });
        return ERC3156_CALLBACK_RESULT;
    }

    // ================================================ Aave ================================================

    /**
     * @notice Initiates a simple flash loan on Aave V3.
     * @param pool The Aave V3 pool provider.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanAave(IPool pool, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        pool.flashLoanSimple(this, token, amount, abi.encodePacked(fundsReceiver, token, amount, data), 0);
    }

    /**
     * @notice Initiates a multi-token flash loan on Aave V3.
     * @param pool The Aave V3 pool provider.
     * @param tokens The tokens to borrow.
     * @param amounts The amounts of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */
    function flashLoansAave(IPool pool, IERC20[] calldata tokens, uint256[] calldata amounts, bytes calldata data, address fundsReceiver)
        public
    {
        pool.flashLoan({
            receiverAddress: this,
            assets: tokens,
            amounts: amounts,
            interestRateModes: fill(tokens.length, uint8(DataTypes.InterestRateMode.NONE)),
            onBehalfOf: address(this),
            params: abi.encodePacked(fundsReceiver, data),
            referralCode: 0
        });
    }

    /**
     * @notice Callback for Aave V3 simple flash loans.
     * @param fee The premium charged for the flash loan.
     * @param metadata Encoded metadata containing funds receiver and additional data.
     */
    function executeOperation(IERC20, uint256, uint256 fee, address, bytes calldata metadata) external override returns (bool) {
        _simpleCallback({ metadata: metadata, transfer: true, approve: true, fee: fee });
        return true;
    }

    /**
     * @notice Callback for Aave V3 multi-token flash loans.
     * @param assets The borrowed tokens.
     * @param amounts The borrowed amounts.
     * @param premiums The premiums charged for each token.
     * @param params Encoded metadata containing funds receiver and additional data.
     */
    function executeOperation(
        IERC20[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address,
        bytes calldata params
    ) external override returns (bool) {
        _multiCallback({ metadata: params, transfer: true, approve: true, tokens: assets, amounts: amounts, fees: premiums });
        return true;
    }

    // ================================================ Balancer ================================================

    /**
     * @notice Initiates a single-token flash loan on Balancer.
     * @param provider The Balancer vault/provider.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanBalancer(IFlashLoaner provider, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        provider.flashLoan(this, toArray(token), amount.uint256s(), abi.encodePacked(fundsReceiver, data));
    }

    /**
     * @notice Initiates a multi-token flash loan on Balancer.
     * @param provider The Balancer vault/provider.
     * @param tokens The tokens to borrow.
     * @param amounts The amounts of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */
    function flashLoansBalancer(
        IFlashLoaner provider,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data,
        address fundsReceiver
    ) public {
        provider.flashLoan(this, tokens, amounts, abi.encodePacked(fundsReceiver, data));
    }

    /**
     * @notice Callback for Balancer flash loans.
     * @param tokens The borrowed tokens.
     * @param amounts The borrowed amounts.
     * @param fees The fees charged for each token.
     * @param metadata Encoded metadata containing funds receiver and additional data.
     */
    function receiveFlashLoan(IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata metadata)
        external
        override
    {
        _multiCallback({ metadata: metadata, transfer: true, approve: false, tokens: tokens, amounts: amounts, fees: fees });
    }

    // ================================================ Morpho ================================================

    /**
     * @notice Initiates a flash loan on Morpho Blue.
     * @param morpho The Morpho Blue contract.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanMorpho(IMorpho morpho, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        morpho.flashLoan(token, amount, abi.encodePacked(fundsReceiver, token, amount, data));
    }

    /**
     * @notice Callback for Morpho Blue flash loans.
     * @param metadata Encoded metadata containing funds receiver and additional data.
     */
    function onMorphoFlashLoan(uint256, bytes calldata metadata) external override {
        _simpleCallback({ metadata: metadata, transfer: true, approve: true, fee: 0 });
    }

    // ================================================ Uniswap V3 ================================================

    /**
     * @notice Initiates a flash loan on Uniswap V3.
     * @param pool The Uniswap V3 pool.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanUniswapV3(IUniswapV3Pool pool, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        bool token0 = address(token) == address(pool.token0());
        pool.flash(fundsReceiver, token0 ? amount : 0, token0 ? 0 : amount, abi.encodePacked(fundsReceiver, token, amount, data));
    }

    /**
     * @notice Callback for Uniswap V3 flash loans.
     * @param metadata Encoded metadata containing funds receiver and additional data.
     */
    function uniswapV3FlashCallback(uint256, uint256, bytes calldata metadata) external override {
        _simpleCallback({ metadata: metadata, transfer: false, approve: false, fee: 0 });
    }

    /**
     * @notice Initiates a flash swap on Uniswap V3.
     * @param pool The Uniswap V3 pool.
     * @param token The token to provide for the swap.
     * @param amountSpecified The amount of tokens to swap.
     * @param data Arbitrary data to be passed to the swap callback.
     * @param fundsReceiver The address that will receive the swap proceeds.
     */
    function flashSwapUniswapV3(IUniswapV3Pool pool, IERC20 token, uint256 amountSpecified, bytes calldata data, address fundsReceiver)
        public
    {
        bool zeroForOne = address(token) == address(pool.token0());
        pool.swap({
            recipient: fundsReceiver,
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified.toInt256(),
            sqrtPriceLimitX96: (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            data: data
        });
    }

    /**
     * @notice Callback for Uniswap V3 swaps.
     * @dev Executes the `data` as a dynamic function call [20 bytes target address + X bytes calldata].
     * @param data The encoded data to be executed.
     */
    function uniswapV3SwapCallback(int256, int256, bytes calldata data) external override {
        data.functionCall();
    }

    // ================================================ Algebra ================================================

    /**
     * @notice Initiates a flash loan on Algebra (Uniswap V3 fork).
     * @param pool The Algebra pool.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanAlgebra(IAlgebraPool pool, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        bool token0 = address(token) == address(pool.token0());
        pool.flash(fundsReceiver, token0 ? amount : 0, token0 ? 0 : amount, abi.encodePacked(fundsReceiver, token, amount, data));
    }

    /**
     * @notice Callback for Algebra flash loans.
     * @param metadata Encoded metadata containing funds receiver and additional data.
     */
    function algebraFlashCallback(uint256, uint256, bytes calldata metadata) external override {
        _simpleCallback({ metadata: metadata, transfer: false, approve: false, fee: 0 });
    }

    /**
     * @notice Initiates a flash swap on Algebra.
     * @param pool The Algebra pool.
     * @param token The token to provide for the swap.
     * @param amountSpecified The amount of tokens to swap.
     * @param data Arbitrary data to be passed to the swap callback.
     * @param fundsReceiver The address that will receive the swap proceeds.
     */
    function flashSwapAlgebra(IAlgebraPool pool, IERC20 token, uint256 amountSpecified, bytes calldata data, address fundsReceiver) public {
        bool zeroForOne = address(token) == address(pool.token0());
        pool.swap({
            recipient: fundsReceiver,
            zeroToOne: zeroForOne,
            amountSpecified: amountSpecified.toInt256(),
            limitSqrtPrice: (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            data: data
        });
    }

    /**
     * @notice Callback for Algebra swaps.
     * @dev Executes the `data` as a dynamic function call [20 bytes target address + X bytes calldata].
     * @dev This is safe as it's validated by the account's executor.
     * @param data The encoded data to be executed.
     */
    function algebraSwapCallback(int256, int256, bytes calldata data) external override {
        data.functionCall();
    }

    // ================================================ Solidly ================================================

    /**
     * @notice Initiates a flash loan on Solidly.
     * @param pool The Solidly pool.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanSolidly(ISolidlyPool pool, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        (IERC20 token0, IERC20 token1) = pool.tokens();
        pool.swap(
            address(token0) == address(token) ? amount : 0,
            address(token1) == address(token) ? amount : 0,
            address(this),
            abi.encodePacked(fundsReceiver, token, amount, data)
        );
    }

    /**
     * @notice Callback for Solidly flash loans (swap hook).
     * @param metadata Encoded metadata containing funds receiver and additional data.
     */
    function hook(address, uint256, uint256, bytes calldata metadata) external override {
        _simpleCallback({ metadata: metadata, transfer: true, approve: false, fee: 0 });
    }

    /**
     * @notice Initiates a flash swap on Solidly.
     * @param pool The Solidly pool.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */
    function flashSwapSolidly(ISolidlyPool pool, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        (IERC20 token0, IERC20 token1) = pool.tokens();
        IERC20 tokenOut = address(token0) == address(token) ? token1 : token0;
        uint256 amountOut = pool.getAmountOut(amount, token);

        pool.swap(
            address(token0) == address(tokenOut) ? amountOut : 0,
            address(token1) == address(tokenOut) ? amountOut : 0,
            address(this),
            abi.encodePacked(fundsReceiver, tokenOut, amountOut, data)
        );
    }

    // ================================================ Euler ================================================

    /**
     * @notice Initiates a flash loan on Euler.
     * @param vault The Euler vault.
     * @param token The token to borrow.
     * @param amount The amount of tokens to borrow.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the borrowed funds.
     */

    function flashLoanEuler(IEulerVault vault, IERC20 token, uint256 amount, bytes calldata data, address fundsReceiver) public {
        vault.flashLoan(amount, abi.encodePacked(fundsReceiver, token, amount, data));
    }

    /**
     * @notice Callback for Euler flash loans.
     * @param data Encoded metadata containing funds receiver and additional data.
     */
    function onFlashLoan(bytes calldata data) external override {
        _simpleCallback({ metadata: data, transfer: true, approve: false, fee: 0 });
    }

    // ================================================ Pendle ================================================

    /**
     * @notice Initiates a flash swap on Pendle.
     * @param market The Pendle market.
     * @param amount The amount to swap.
     * @param data Arbitrary data to be passed to the callback.
     * @param fundsReceiver The address that will receive the swap proceeds.
     */

    function flashSwapPendle(IPendleMarketV3 market, uint256 amount, bytes calldata data, address fundsReceiver) public {
        market.swapExactPtForSy(fundsReceiver, amount, data);
    }

    /**
     * @notice Callback for Pendle swaps.
     * @dev Executes the `data` as a dynamic function call [20 bytes target address + X bytes calldata].
     * @dev This is safe as it's validated by the account's executor.
     * @param data The encoded data to be executed.
     */
    function swapCallback(int256, int256, bytes calldata data) external override {
        data.functionCall();
    }

    // ================================================ Internal ================================================

    /**
     * @notice Internal helper to handle simple flash loan callbacks.
     * @dev Decodes metadata, transfers funds to the receiver, executes the callback data, and optionally approves the lender for repayment.
     * @dev The internal `data.functionCall()` expects `data` to be [20 bytes target + X bytes calldata].
     * @param metadata Encoded metadata [0:20 bytes receiver, 20:40 bytes token, 40:72 bytes amount, 72:+ bytes data].
     * @param transfer Whether to transfer the borrowed funds to the receiver.
     * @param approve Whether to approve the lender for repayment (amount + fee).
     * @param fee The fee charged by the lender.
     */
    function _simpleCallback(bytes calldata metadata, bool transfer, bool approve, uint256 fee) internal {
        (address fundsReceiver, IERC20 token, uint256 amount, bytes calldata data) =
            (address(bytes20(metadata[:20])), IERC20(address(bytes20(metadata[20:40]))), uint256(bytes32(metadata[40:72])), metadata[72:]);
        if (transfer) token.transferOut(address(this), fundsReceiver, amount);
        data.functionCall();
        if (approve) token.forceApprove(msg.sender, amount + fee);
        emit FlashLoan(msg.sender, token, amount, fee, fundsReceiver);
    }

    /**
     * @notice Internal helper to handle multi-token flash loan callbacks.
     * @dev Decodes metadata, transfers funds for each token, executes the callback data, and optionally approves the lender for repayment of all tokens.
     * @dev The internal `data.functionCall()` expects `data` to be [20 bytes target + X bytes calldata].
     * @param metadata Encoded metadata [0:20 bytes receiver, 20:+ bytes data].
     * @param transfer Whether to transfer the borrowed funds to the receiver.
     * @param approve Whether to approve the lender for repayment (amount + fee).
     * @param tokens The array of tokens borrowed.
     * @param amounts The array of borrowed amounts.
     * @param fees The array of fees charged for each token.
     */
    function _multiCallback(
        bytes calldata metadata,
        bool transfer,
        bool approve,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees
    ) internal {
        (address fundsReceiver, bytes calldata data) = (address(bytes20(metadata[:20])), metadata[20:]);
        uint256 length = tokens.length;

        for (uint256 i = 0; i < length; i++) {
            if (transfer) tokens[i].transferOut(address(this), fundsReceiver, amounts[i]);
        }

        data.functionCall();

        for (uint256 i = 0; i < length; i++) {
            if (approve) tokens[i].forceApprove(msg.sender, amounts[i] + fees[i]);
            emit FlashLoan(msg.sender, tokens[i], amounts[i], fees[i], fundsReceiver);
        }
    }

}
