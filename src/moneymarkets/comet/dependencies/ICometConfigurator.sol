// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ICometConfigurator {

    struct AssetConfig {
        address asset;
        address priceFeed;
        uint8 decimals;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    struct Configuration {
        address governor;
        address pauseGuardian;
        address baseToken;
        address baseTokenPriceFeed;
        address extensionDelegate;
        uint64 supplyKink;
        uint64 supplyPerYearInterestRateSlopeLow;
        uint64 supplyPerYearInterestRateSlopeHigh;
        uint64 supplyPerYearInterestRateBase;
        uint64 borrowKink;
        uint64 borrowPerYearInterestRateSlopeLow;
        uint64 borrowPerYearInterestRateSlopeHigh;
        uint64 borrowPerYearInterestRateBase;
        uint64 storeFrontPriceFactor;
        uint64 trackingIndexScale;
        uint64 baseTrackingSupplySpeed;
        uint64 baseTrackingBorrowSpeed;
        uint104 baseMinForRewards;
        uint104 baseBorrowMin;
        uint104 targetReserves;
        AssetConfig[] assetConfigs;
    }

    error AlreadyInitialized();
    error AssetDoesNotExist();
    error ConfigurationAlreadyExists();
    error InvalidAddress();
    error Unauthorized();

    event AddAsset(address indexed cometProxy, AssetConfig assetConfig);
    event CometDeployed(address indexed cometProxy, address indexed newComet);
    event GovernorTransferred(address indexed oldGovernor, address indexed newGovernor);
    event SetBaseBorrowMin(address indexed cometProxy, uint104 oldBaseBorrowMin, uint104 newBaseBorrowMin);
    event SetBaseMinForRewards(address indexed cometProxy, uint104 oldBaseMinForRewards, uint104 newBaseMinForRewards);
    event SetBaseTokenPriceFeed(address indexed cometProxy, address indexed oldBaseTokenPriceFeed, address indexed newBaseTokenPriceFeed);
    event SetBaseTrackingBorrowSpeed(address indexed cometProxy, uint64 oldBaseTrackingBorrowSpeed, uint64 newBaseTrackingBorrowSpeed);
    event SetBaseTrackingSupplySpeed(address indexed cometProxy, uint64 oldBaseTrackingSupplySpeed, uint64 newBaseTrackingSupplySpeed);
    event SetBorrowKink(address indexed cometProxy, uint64 oldKink, uint64 newKink);
    event SetBorrowPerYearInterestRateBase(address indexed cometProxy, uint64 oldIRBase, uint64 newIRBase);
    event SetBorrowPerYearInterestRateSlopeHigh(address indexed cometProxy, uint64 oldIRSlopeHigh, uint64 newIRSlopeHigh);
    event SetBorrowPerYearInterestRateSlopeLow(address indexed cometProxy, uint64 oldIRSlopeLow, uint64 newIRSlopeLow);
    event SetConfiguration(address indexed cometProxy, Configuration oldConfiguration, Configuration newConfiguration);
    event SetExtensionDelegate(address indexed cometProxy, address indexed oldExt, address indexed newExt);
    event SetFactory(address indexed cometProxy, address indexed oldFactory, address indexed newFactory);
    event SetGovernor(address indexed cometProxy, address indexed oldGovernor, address indexed newGovernor);
    event SetPauseGuardian(address indexed cometProxy, address indexed oldPauseGuardian, address indexed newPauseGuardian);
    event SetStoreFrontPriceFactor(address indexed cometProxy, uint64 oldStoreFrontPriceFactor, uint64 newStoreFrontPriceFactor);
    event SetSupplyKink(address indexed cometProxy, uint64 oldKink, uint64 newKink);
    event SetSupplyPerYearInterestRateBase(address indexed cometProxy, uint64 oldIRBase, uint64 newIRBase);
    event SetSupplyPerYearInterestRateSlopeHigh(address indexed cometProxy, uint64 oldIRSlopeHigh, uint64 newIRSlopeHigh);
    event SetSupplyPerYearInterestRateSlopeLow(address indexed cometProxy, uint64 oldIRSlopeLow, uint64 newIRSlopeLow);
    event SetTargetReserves(address indexed cometProxy, uint104 oldTargetReserves, uint104 newTargetReserves);
    event UpdateAsset(address indexed cometProxy, AssetConfig oldAssetConfig, AssetConfig newAssetConfig);
    event UpdateAssetBorrowCollateralFactor(address indexed cometProxy, address indexed asset, uint64 oldBorrowCF, uint64 newBorrowCF);
    event UpdateAssetLiquidateCollateralFactor(
        address indexed cometProxy, address indexed asset, uint64 oldLiquidateCF, uint64 newLiquidateCF
    );
    event UpdateAssetLiquidationFactor(
        address indexed cometProxy, address indexed asset, uint64 oldLiquidationFactor, uint64 newLiquidationFactor
    );
    event UpdateAssetPriceFeed(address indexed cometProxy, address indexed asset, address oldPriceFeed, address newPriceFeed);
    event UpdateAssetSupplyCap(address indexed cometProxy, address indexed asset, uint128 oldSupplyCap, uint128 newSupplyCap);

    function addAsset(address cometProxy, AssetConfig memory assetConfig) external;
    function deploy(address cometProxy) external returns (address);
    function factory(address) external view returns (address);
    function getAssetIndex(address cometProxy, address asset) external view returns (uint256);
    function getConfiguration(address cometProxy) external view returns (Configuration memory);
    function governor() external view returns (address);
    function initialize(address governor_) external;
    function setBaseBorrowMin(address cometProxy, uint104 newBaseBorrowMin) external;
    function setBaseMinForRewards(address cometProxy, uint104 newBaseMinForRewards) external;
    function setBaseTokenPriceFeed(address cometProxy, address newBaseTokenPriceFeed) external;
    function setBaseTrackingBorrowSpeed(address cometProxy, uint64 newBaseTrackingBorrowSpeed) external;
    function setBaseTrackingSupplySpeed(address cometProxy, uint64 newBaseTrackingSupplySpeed) external;
    function setBorrowKink(address cometProxy, uint64 newBorrowKink) external;
    function setBorrowPerYearInterestRateBase(address cometProxy, uint64 newBase) external;
    function setBorrowPerYearInterestRateSlopeHigh(address cometProxy, uint64 newSlope) external;
    function setBorrowPerYearInterestRateSlopeLow(address cometProxy, uint64 newSlope) external;
    function setConfiguration(address cometProxy, Configuration memory newConfiguration) external;
    function setExtensionDelegate(address cometProxy, address newExtensionDelegate) external;
    function setFactory(address cometProxy, address newFactory) external;
    function setGovernor(address cometProxy, address newGovernor) external;
    function setPauseGuardian(address cometProxy, address newPauseGuardian) external;
    function setStoreFrontPriceFactor(address cometProxy, uint64 newStoreFrontPriceFactor) external;
    function setSupplyKink(address cometProxy, uint64 newSupplyKink) external;
    function setSupplyPerYearInterestRateBase(address cometProxy, uint64 newBase) external;
    function setSupplyPerYearInterestRateSlopeHigh(address cometProxy, uint64 newSlope) external;
    function setSupplyPerYearInterestRateSlopeLow(address cometProxy, uint64 newSlope) external;
    function setTargetReserves(address cometProxy, uint104 newTargetReserves) external;
    function transferGovernor(address newGovernor) external;
    function updateAsset(address cometProxy, AssetConfig memory newAssetConfig) external;
    function updateAssetBorrowCollateralFactor(address cometProxy, address asset, uint64 newBorrowCF) external;
    function updateAssetLiquidateCollateralFactor(address cometProxy, address asset, uint64 newLiquidateCF) external;
    function updateAssetLiquidationFactor(address cometProxy, address asset, uint64 newLiquidationFactor) external;
    function updateAssetPriceFeed(address cometProxy, address asset, address newPriceFeed) external;
    function updateAssetSupplyCap(address cometProxy, address asset, uint128 newSupplyCap) external;
    function version() external view returns (uint256);

}
