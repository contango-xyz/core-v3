// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import { console } from "forge-std/console.sol";

library console3 {

    event log_named_decimal_uint(string key, uint256 val, uint256 decimals);
    event log_named_decimal_int(string key, int256 val, uint256 decimals);

    function logDecimal(string memory p0, uint256 p1, uint256 p2) internal {
        emit log_named_decimal_uint(p0, p1, p2);
    }

    function logDecimal(string memory p0, int256 p1, uint256 p2) internal {
        emit log_named_decimal_int(p0, p1, p2);
    }

}
