// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAlgebraPoolFactory {

    error FeeInvalid();
    error FeeTooHigh();
    error InvalidPool();
    error NotFeeManager();
    error NotPauser();
    error NotVoter();
    error PoolAlreadyExists();
    error SameAddress();
    error ZeroAddress();
    error ZeroFee();

    event PoolCreated(address indexed token0, address indexed token1, bool indexed stable, address pool, uint256 _idx);
    event SetCustomFee(address indexed pool, uint256 fee);
    event SetFeeManager(address feeManager);
    event SetPauseState(bool state);
    event SetPauser(address pauser);
    event SetVoter(address voter);

    function MAX_FEE() external view returns (uint256);
    function ZERO_FEE_INDICATOR() external view returns (uint256);
    function allPools(uint256) external view returns (address);
    function allPoolsLength() external view returns (uint256);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function customFee(address) external view returns (uint256);
    function feeManager() external view returns (address);
    function getFee(address pool, bool _stable) external view returns (uint256);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function implementation() external view returns (address);
    function isPaused() external view returns (bool);
    function isPool(address pool) external view returns (bool);
    function pauser() external view returns (address);
    function setCustomFee(address pool, uint256 fee) external;
    function setFee(bool _stable, uint256 _fee) external;
    function setFeeManager(address _feeManager) external;
    function setPauseState(bool _state) external;
    function setPauser(address _pauser) external;
    function setVoter(address _voter) external;
    function stableFee() external view returns (uint256);
    function volatileFee() external view returns (uint256);
    function voter() external view returns (address);

}

interface IAlgebraPool {

    struct Observation {
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
    }

    error BelowMinimumK();
    error DepositsNotEqual();
    error FactoryAlreadySet();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InsufficientLiquidityBurned();
    error InsufficientLiquidityMinted();
    error InsufficientOutputAmount();
    error InvalidTo();
    error IsPaused();
    error K();
    error NotEmergencyCouncil();
    error StringTooLong(string str);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed sender, address indexed to, uint256 amount0, uint256 amount1);
    event Claim(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);
    event EIP712DomainChanged();
    event Fees(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, address indexed to, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function blockTimestampLast() external view returns (uint256);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
    function claimable0(address) external view returns (uint256);
    function claimable1(address) external view returns (uint256);
    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function factory() external view returns (address);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function getK() external returns (uint256);
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function index0() external view returns (uint256);
    function index1() external view returns (uint256);
    function initialize(address _token0, address _token1, bool _stable) external;
    function lastObservation() external view returns (Observation memory);
    function metadata() external view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);
    function mint(address to) external returns (uint256 liquidity);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function observationLength() external view returns (uint256);
    function observations(uint256) external view returns (uint256 timestamp, uint256 reserve0Cumulative, uint256 reserve1Cumulative);
    function periodSize() external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function poolFees() external view returns (address);
    function prices(address tokenIn, uint256 amountIn, uint256 points) external view returns (uint256[] memory);
    function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256 amountOut);
    function reserve0() external view returns (uint256);
    function reserve0CumulativeLast() external view returns (uint256);
    function reserve1() external view returns (uint256);
    function reserve1CumulativeLast() external view returns (uint256);
    function sample(address tokenIn, uint256 amountIn, uint256 points, uint256 window) external view returns (uint256[] memory);
    function setName(string memory __name) external;
    function setSymbol(string memory __symbol) external;
    function skim(address to) external;
    function stable() external view returns (bool);
    function supplyIndex0(address) external view returns (uint256);
    function supplyIndex1(address) external view returns (uint256);

    /**
     * @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
     * @dev The caller of this method receives a callback in the form of IAlgebraFlashCallback# AlgebraFlashCallback
     * @dev All excess tokens paid in the callback are distributed to liquidity providers as an additional fee. So this method can be used
     * to donate underlying tokens to currently in-range liquidity providers by calling with 0 amount{0,1} and sending
     * the donation amount(s) from the callback
     * @param recipient The address which will receive the token0 and token1 amounts
     * @param amount0 The amount of token0 to send
     * @param amount1 The amount of token1 to send
     * @param data Any data to be passed through to the callback
     */
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;

    /**
     * @notice Swap token0 for token1, or token1 for token0
     * @dev The caller of this method receives a callback in the form of IAlgebraSwapCallback# AlgebraSwapCallback
     * @param recipient The address to receive the output of the swap
     * @param zeroToOne The direction of the swap, true for token0 to token1, false for token1 to token0
     * @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
     * @param limitSqrtPrice The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
     * value after the swap. If one for zero, the price cannot be greater than this value after the swap
     * @param data Any data to be passed through to the callback. If using the Router it should contain
     * SwapRouter#SwapCallbackData
     * @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
     * @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
     */
    function swap(address recipient, bool zeroToOne, int256 amountSpecified, uint160 limitSqrtPrice, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);

    function symbol() external view returns (string memory);
    function sync() external;
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
    function tokens() external view returns (IERC20, IERC20);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

}

/**
 * @title Callback for IAlgebraPoolActions#flash
 * @notice Any contract that calls IAlgebraPoolActions#flash must implement this interface
 * @dev Credit to Uniswap Labs under GPL-2.0-or-later license:
 * https://github.com/Uniswap/v3-core/tree/main/contracts/interfaces
 */
interface IAlgebraFlashCallback {

    /**
     * @notice Called to `msg.sender` after transferring to the recipient from IAlgebraPool#flash.
     * @dev In the implementation you must repay the pool the tokens sent by flash plus the computed fee amounts.
     * The caller of this method must be checked to be a AlgebraPool deployed by the canonical AlgebraFactory.
     * @param fee0 The fee amount in token0 due to the pool by the end of the flash
     * @param fee1 The fee amount in token1 due to the pool by the end of the flash
     * @param data Any data passed through by the caller via the IAlgebraPoolActions#flash call
     */
    function algebraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;

}

/// @title Callback for IAlgebraPoolActions#swap
/// @notice Any contract that calls IAlgebraPoolActions#swap must implement this interface
/// @dev Credit to Uniswap Labs under GPL-2.0-or-later license:
/// https://github.com/Uniswap/v3-core/tree/main/contracts/interfaces
interface IAlgebraSwapCallback {

    /// @notice Called to `msg.sender` after executing a swap via IAlgebraPool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a AlgebraPool deployed by the canonical AlgebraFactory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IAlgebraPoolActions#swap call
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;

}
