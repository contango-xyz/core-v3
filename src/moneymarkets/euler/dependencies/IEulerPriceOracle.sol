// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEulerPriceOracle {

    error PriceOracle_InvalidAnswer();
    error PriceOracle_InvalidConfiguration();
    error PriceOracle_NotSupported(address base, address quote);
    error PriceOracle_Overflow();
    error PriceOracle_TooStale(uint256 staleness, uint256 maxStaleness);

    function base() external view returns (address);
    function feed() external view returns (address);
    function getQuote(uint256 inAmount, IERC20 base, IERC20 quote) external view returns (uint256);
    function getQuotes(uint256 inAmount, IERC20 base, IERC20 quote) external view returns (uint256, uint256);
    function maxStaleness() external view returns (uint256);
    function name() external view returns (string memory);
    function quote() external view returns (IERC20);

}
