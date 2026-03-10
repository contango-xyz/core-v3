// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IAToken } from "./IAToken.sol";

library DataTypes {

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    struct CollateralConfig {
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
    }

    struct EModeCategoryBaseConfiguration {
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        string label;
    }

    struct EModeCategoryLegacy {
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        address priceSource;
        string label;
    }

    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 __deprecatedStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        uint40 liquidationGracePeriodUntil;
        IAToken aTokenAddress;
        address __deprecatedStableDebtTokenAddress;
        IAToken variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
        uint128 virtualUnderlyingBalance;
    }

    struct ReserveDataLegacy {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        IAToken aTokenAddress;
        address stableDebtTokenAddress;
        IAToken variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }

    struct UserConfigurationMap {
        uint256 data;
    }

}
