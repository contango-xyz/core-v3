//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISolidlyPool {

    /// @notice This low-level function should be called from a contract which performs important safety checks
    /// @param amount0Out   Amount of token0 to send to `to`
    /// @param amount1Out   Amount of token1 to send to `to`
    /// @param to           Address to receive the swapped output
    /// @param data         Additional calldata for flashloans
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Get the amount of tokenOut given the amount of tokenIn
    /// @param amountIn Amount of token in
    /// @param tokenIn  Address of token
    /// @return Amount out
    function getAmountOut(uint256 amountIn, IERC20 tokenIn) external view returns (uint256);

    /// @notice Returns [token0, token1]
    function tokens() external view returns (IERC20 token0, IERC20 token1);

}

interface ISolidlyFlashCallback {

    function hook(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;

}
