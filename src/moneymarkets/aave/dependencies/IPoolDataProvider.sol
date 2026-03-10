// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPoolAddressesProvider } from "./IPoolAddressesProvider.sol";

/**
 * @title IPoolDataProvider
 * @author Aave
 * @notice Defines the basic interface of a PoolDataProvider
 */
interface IPoolDataProvider {

    struct TokenData {
        string symbol;
        address tokenAddress;
    }

    /**
     * @notice Returns the address for the PoolAddressesProvider contract.
     * @return The address for the PoolAddressesProvider contract
     */
    function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

    /**
     * @notice Returns the list of the existing reserves in the pool.
     * @dev Handling MKR and ETH in a different way since they do not have standard `symbol` functions.
     * @return The list of reserves, pairs of symbols and addresses
     */
    function getAllReservesTokens() external view returns (TokenData[] memory);

    /**
     * @notice Returns the list of the existing ATokens in the pool.
     * @return The list of ATokens, pairs of symbols and addresses
     */
    function getAllATokens() external view returns (TokenData[] memory);

    /**
     * @notice Returns the configuration data of the reserve
     * @dev Not returning borrow and supply caps for compatibility, nor pause flag
     * @param asset The address of the underlying asset of the reserve
     * @return decimals The number of decimals of the reserve
     * @return ltv The ltv of the reserve
     * @return liquidationThreshold The liquidationThreshold of the reserve
     * @return liquidationBonus The liquidationBonus of the reserve
     * @return reserveFactor The reserveFactor of the reserve
     * @return usageAsCollateralEnabled True if the usage as collateral is enabled, false otherwise
     * @return borrowingEnabled True if borrowing is enabled, false otherwise
     * @return stableBorrowRateEnabled True if stable rate borrowing is enabled, false otherwise
     * @return isActive True if it is active, false otherwise
     * @return isFrozen True if it is frozen, false otherwise
     */
    function getReserveConfigurationData(IERC20 asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );

    /**
     * @notice Returns the efficiency mode category of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The eMode id of the reserve
     */
    function getReserveEModeCategory(IERC20 asset) external view returns (uint256);

    /**
     * @notice Returns the caps parameters of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return borrowCap The borrow cap of the reserve
     * @return supplyCap The supply cap of the reserve
     */
    function getReserveCaps(IERC20 asset) external view returns (uint256 borrowCap, uint256 supplyCap);

    /**
     * @notice Returns if the pool is paused
     * @param asset The address of the underlying asset of the reserve
     * @return isPaused True if the pool is paused, false otherwise
     */
    function getPaused(IERC20 asset) external view returns (bool isPaused);

    /**
     * @notice Returns the siloed borrowing flag
     * @param asset The address of the underlying asset of the reserve
     * @return True if the asset is siloed for borrowing
     */
    function getSiloedBorrowing(IERC20 asset) external view returns (bool);

    /**
     * @notice Returns the protocol fee on the liquidation bonus
     * @param asset The address of the underlying asset of the reserve
     * @return The protocol fee on liquidation
     */
    function getLiquidationProtocolFee(IERC20 asset) external view returns (uint256);

    /**
     * @notice Returns the unbacked mint cap of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The unbacked mint cap of the reserve
     */
    function getUnbackedMintCap(IERC20 asset) external view returns (uint256);

    /**
     * @notice Returns the debt ceiling of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The debt ceiling of the reserve
     */
    function getDebtCeiling(IERC20 asset) external view returns (uint256);

    /**
     * @notice Returns the debt ceiling decimals
     * @return The debt ceiling decimals
     */
    function getDebtCeilingDecimals() external pure returns (uint256);

    struct ReserveData {
        uint256 unbacked;
        uint256 accruedToTreasuryScaled;
        uint256 totalAToken;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        uint256 liquidityRate;
        uint256 variableBorrowRate;
        uint256 stableBorrowRate;
        uint256 averageStableBorrowRate;
        uint256 liquidityIndex;
        uint256 variableBorrowIndex;
        uint40 lastUpdateTimestamp;
    }

    function getReserveData(IERC20 asset) external view returns (ReserveData memory);

    /**
     * @notice Returns the total supply of aTokens for a given asset
     * @param asset The address of the underlying asset of the reserve
     * @return The total supply of the aToken
     */
    function getATokenTotalSupply(IERC20 asset) external view returns (uint256);

    /**
     * @notice Returns the total debt for a given asset
     * @param asset The address of the underlying asset of the reserve
     * @return The total debt for asset
     */
    function getTotalDebt(IERC20 asset) external view returns (uint256);

    /**
     * @notice Returns the user data in a reserve
     * @param asset The address of the underlying asset of the reserve
     * @param user The address of the user
     * @return currentATokenBalance The current AToken balance of the user
     * @return currentStableDebt The current stable debt of the user
     * @return currentVariableDebt The current variable debt of the user
     * @return principalStableDebt The principal stable debt of the user
     * @return scaledVariableDebt The scaled variable debt of the user
     * @return stableBorrowRate The stable borrow rate of the user
     * @return liquidityRate The liquidity rate of the reserve
     * @return stableRateLastUpdated The timestamp of the last update of the user stable rate
     * @return usageAsCollateralEnabled True if the user is using the asset as collateral, false
     *         otherwise
     */
    function getUserReserveData(IERC20 asset, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );

    /**
     * @notice Returns the token addresses of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return aTokenAddress The AToken address of the reserve
     * @return stableDebtTokenAddress The StableDebtToken address of the reserve
     * @return variableDebtTokenAddress The VariableDebtToken address of the reserve
     */
    function getReserveTokensAddresses(IERC20 asset)
        external
        view
        returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress);

    /**
     * @notice Returns the address of the Interest Rate strategy
     * @param asset The address of the underlying asset of the reserve
     * @return irStrategyAddress The address of the Interest Rate strategy
     */
    function getInterestRateStrategyAddress(IERC20 asset) external view returns (address irStrategyAddress);

    /**
     * @notice Returns whether the reserve has FlashLoans enabled or disabled
     * @param asset The address of the underlying asset of the reserve
     * @return True if FlashLoans are enabled, false otherwise
     */
    function getFlashLoanEnabled(IERC20 asset) external view returns (bool);

    // V3.2
    function getIsVirtualAccActive(address asset) external view returns (bool);
    function getVirtualUnderlyingBalance(address asset) external view returns (uint256);

}
