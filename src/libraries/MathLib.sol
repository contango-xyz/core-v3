//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UD60x18, ud, UNIT } from "@prb/math/UD60x18.sol";
import { WAD, DAYS_PER_YEAR, SECONDS_PER_DAY } from "../constants.sol";

library MathLib {

    /**
     * @notice Calculates the Annual Percentage Yield (APY) from a periodic rate.
     * @dev Uses compounding: APY = (rate + 1) ^ DaysPerYear - 1.
     * @param rate The periodic rate.
     * @param perSeconds The number of seconds in the period the rate represents.
     * @return The APY in WAD (1e18).
     */
    function apy(uint256 rate, uint256 perSeconds) internal pure returns (uint256) {
        UD60x18 _rate = ud(rate) / ud(perSeconds * WAD) * SECONDS_PER_DAY;

        // APY = (rate + 1) ^ Days Per Year - 1)
        return ((_rate + UNIT).pow(DAYS_PER_YEAR) - UNIT).unwrap();
    }

    /**
     * @notice Calculates the absolute value of an integer.
     * @param value The signed integer.
     * @return result The absolute value as an unsigned integer.
     */
    function abs(int256 value) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            result := value
            if slt(value, 0) { result := sub(0, value) }
        }
    }

}
