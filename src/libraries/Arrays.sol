//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

function toArray(IERC20 a) pure returns (IERC20[] memory arr) {
    arr = new IERC20[](1);
    arr[0] = a;
}

function fill(uint256 length, uint256 value) pure returns (uint256[] memory arr) {
    arr = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
        arr[i] = value;
    }
}
