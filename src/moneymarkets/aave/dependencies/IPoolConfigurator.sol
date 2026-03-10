// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IPoolConfigurator {

    struct InitReserveInput {
        address aTokenImpl;
        address variableDebtTokenImpl;
        bool useVirtualBalance;
        address interestRateStrategyAddress;
        address underlyingAsset;
        address treasury;
        address incentivesController;
        string aTokenName;
        string aTokenSymbol;
        string variableDebtTokenName;
        string variableDebtTokenSymbol;
        bytes params;
        bytes interestRateData;
    }

    struct UpdateATokenInput {
        address asset;
        address treasury;
        address incentivesController;
        string name;
        string symbol;
        address implementation;
        bytes params;
    }

    struct UpdateDebtTokenInput {
        address asset;
        address incentivesController;
        string name;
        string symbol;
        address implementation;
        bytes params;
    }

    event ATokenUpgraded(address indexed asset, address indexed proxy, address indexed implementation);
    event AssetBorrowableInEModeChanged(address indexed asset, uint8 categoryId, bool borrowable);
    event AssetCollateralInEModeChanged(address indexed asset, uint8 categoryId, bool collateral);
    event BorrowCapChanged(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);
    event BorrowableInIsolationChanged(address asset, bool borrowable);
    event BridgeProtocolFeeUpdated(uint256 oldBridgeProtocolFee, uint256 newBridgeProtocolFee);
    event CollateralConfigurationChanged(address indexed asset, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus);
    event DebtCeilingChanged(address indexed asset, uint256 oldDebtCeiling, uint256 newDebtCeiling);
    event EModeCategoryAdded(
        uint8 indexed categoryId, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, address oracle, string label
    );
    event FlashloanPremiumToProtocolUpdated(uint128 oldFlashloanPremiumToProtocol, uint128 newFlashloanPremiumToProtocol);
    event FlashloanPremiumTotalUpdated(uint128 oldFlashloanPremiumTotal, uint128 newFlashloanPremiumTotal);
    event LiquidationGracePeriodChanged(address indexed asset, uint40 gracePeriodUntil);
    event LiquidationGracePeriodDisabled(address indexed asset);
    event LiquidationProtocolFeeChanged(address indexed asset, uint256 oldFee, uint256 newFee);
    event PendingLtvChanged(address indexed asset, uint256 ltv);
    event ReserveActive(address indexed asset, bool active);
    event ReserveBorrowing(address indexed asset, bool enabled);
    event ReserveDropped(address indexed asset);
    event ReserveFactorChanged(address indexed asset, uint256 oldReserveFactor, uint256 newReserveFactor);
    event ReserveFlashLoaning(address indexed asset, bool enabled);
    event ReserveFrozen(address indexed asset, bool frozen);
    event ReserveInitialized(
        address indexed asset,
        address indexed aToken,
        address stableDebtToken,
        address variableDebtToken,
        address interestRateStrategyAddress
    );
    event ReserveInterestRateDataChanged(address indexed asset, address indexed strategy, bytes data);
    event ReserveInterestRateStrategyChanged(address indexed asset, address oldStrategy, address newStrategy);
    event ReservePaused(address indexed asset, bool paused);
    event SiloedBorrowingChanged(address indexed asset, bool oldState, bool newState);
    event SupplyCapChanged(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);
    event UnbackedMintCapChanged(address indexed asset, uint256 oldUnbackedMintCap, uint256 newUnbackedMintCap);
    event VariableDebtTokenUpgraded(address indexed asset, address indexed proxy, address indexed implementation);

    // Backwards compatibility
    event EModeAssetCategoryChanged(address indexed asset, uint8 oldCategoryId, uint8 newCategoryId);

    function CONFIGURATOR_REVISION() external view returns (uint256);
    function MAX_GRACE_PERIOD() external view returns (uint40);
    function configureReserveAsCollateral(address asset, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus) external;
    function disableLiquidationGracePeriod(address asset) external;
    function dropReserve(address asset) external;
    function getConfiguratorLogic() external pure returns (address);
    function getPendingLtv(address asset) external view returns (uint256);
    function initReserves(InitReserveInput[] memory input) external;
    function initialize(address provider) external;
    function setAssetBorrowableInEMode(address asset, uint8 categoryId, bool borrowable) external;
    function setAssetCollateralInEMode(address asset, uint8 categoryId, bool allowed) external;
    function setBorrowCap(address asset, uint256 newBorrowCap) external;
    function setBorrowableInIsolation(address asset, bool borrowable) external;
    function setDebtCeiling(address asset, uint256 newDebtCeiling) external;
    function setEModeCategory(uint8 categoryId, uint16 ltv, uint16 liquidationThreshold, uint16 liquidationBonus, string memory label)
        external;
    function setLiquidationProtocolFee(address asset, uint256 newFee) external;
    function setPoolPause(bool paused, uint40 gracePeriod) external;
    function setPoolPause(bool paused) external;
    function setReserveActive(address asset, bool active) external;
    function setReserveBorrowing(address asset, bool enabled) external;
    function setReserveFactor(address asset, uint256 newReserveFactor) external;
    function setReserveFlashLoaning(address asset, bool enabled) external;
    function setReserveFreeze(address asset, bool freeze) external;
    function setReserveInterestRateData(address asset, bytes memory rateData) external;
    function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress, bytes memory rateData) external;
    function setReservePause(address asset, bool paused) external;
    function setReservePause(address asset, bool paused, uint40 gracePeriod) external;
    function setSiloedBorrowing(address asset, bool newSiloed) external;
    function setSupplyCap(address asset, uint256 newSupplyCap) external;
    function setUnbackedMintCap(address asset, uint256 newUnbackedMintCap) external;
    function updateAToken(UpdateATokenInput memory input) external;
    function updateBridgeProtocolFee(uint256 newBridgeProtocolFee) external;
    function updateFlashloanPremiumToProtocol(uint128 newFlashloanPremiumToProtocol) external;
    function updateFlashloanPremiumTotal(uint128 newFlashloanPremiumTotal) external;
    function updateVariableDebtToken(UpdateDebtTokenInput memory input) external;

}
