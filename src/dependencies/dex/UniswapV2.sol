// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV2PoolEvents {

    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to);

}

interface IUniswapV2FactoryEvents {

    event PairCreated(address indexed token0, address indexed token1, address pool, uint256 idx);

}
