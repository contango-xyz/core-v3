//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Converts a single IERC20 token into an array containing that token.
 * @param a The IERC20 token.
 * @return arr An array containing the single token.
 */
function toArray(IERC20 a) pure returns (IERC20[] memory arr) {
    arr = new IERC20[](1);
    arr[0] = a;
}

/**
 * @notice Creates and fills an array with a specific value.
 * @param length The desired length of the array.
 * @param value The value to fill the array with.
 * @return arr The filled array.
 */
function fill(uint256 length, uint256 value) pure returns (uint256[] memory arr) {
    arr = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
        arr[i] = value;
    }
}
