// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DataTypes } from "./DataTypes.sol";
import { IFlashLoanReceiver } from "./IFlashLoanReceiver.sol";
import { IFlashLoanSimpleReceiver } from "./IFlashLoanSimpleReceiver.sol";

interface IPool {

    event BackUnbacked(address indexed reserve, address indexed backer, uint256 amount, uint256 fee);
    event Borrow(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        DataTypes.InterestRateMode interestRateMode,
        uint256 borrowRate,
        uint16 indexed referralCode
    );
    event FlashLoan(
        address indexed target,
        address initiator,
        address indexed asset,
        uint256 amount,
        DataTypes.InterestRateMode interestRateMode,
        uint256 premium,
        uint16 indexed referralCode
    );
    event IsolationModeTotalDebtUpdated(address indexed asset, uint256 totalDebt);
    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receiveAToken
    );
    event MintUnbacked(address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint16 indexed referralCode);
    event MintedToTreasury(address indexed reserve, uint256 amountMinted);
    event Repay(address indexed reserve, address indexed user, address indexed repayer, uint256 amount, bool useATokens);
    event ReserveDataUpdated(
        address indexed reserve,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );
    event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);
    event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);
    event Supply(address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint16 indexed referralCode);
    event UserEModeSet(address indexed user, uint8 categoryId);
    event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

    function ADDRESSES_PROVIDER() external view returns (address);
    function BRIDGE_PROTOCOL_FEE() external view returns (uint256);
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);
    function MAX_NUMBER_RESERVES() external view returns (uint16);
    function POOL_REVISION() external view returns (uint256);
    function backUnbacked(IERC20 asset, uint256 amount, uint256 fee) external returns (uint256);
    function borrow(IERC20 asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function configureEModeCategory(uint8 id, DataTypes.EModeCategoryBaseConfiguration memory category) external;
    function configureEModeCategoryBorrowableBitmap(uint8 id, uint128 borrowableBitmap) external;
    function configureEModeCategoryCollateralBitmap(uint8 id, uint128 collateralBitmap) external;
    function deposit(IERC20 asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function dropReserve(IERC20 asset) external;
    function finalizeTransfer(IERC20 asset, address from, address to, uint256 amount, uint256 balanceFromBefore, uint256 balanceToBefore)
        external;
    function flashLoan(
        IFlashLoanReceiver receiverAddress,
        IERC20[] memory assets,
        uint256[] memory amounts,
        uint256[] memory interestRateModes,
        address onBehalfOf,
        bytes memory params,
        uint16 referralCode
    ) external;
    function flashLoanSimple(
        IFlashLoanSimpleReceiver receiverAddress,
        IERC20 asset,
        uint256 amount,
        bytes memory params,
        uint16 referralCode
    ) external;
    function getBorrowLogic() external pure returns (address);
    function getBridgeLogic() external pure returns (address);
    function getConfiguration(IERC20 asset) external view returns (DataTypes.ReserveConfigurationMap memory);
    function getEModeCategoryBorrowableBitmap(uint8 id) external view returns (uint128);
    function getEModeCategoryCollateralBitmap(uint8 id) external view returns (uint128);
    function getEModeCategoryCollateralConfig(uint8 id) external view returns (DataTypes.CollateralConfig memory);
    function getEModeCategoryData(uint8 id) external view returns (DataTypes.EModeCategoryLegacy memory);
    function getEModeCategoryLabel(uint8 id) external view returns (string memory);
    function getEModeLogic() external pure returns (address);
    function getFlashLoanLogic() external pure returns (address);
    function getLiquidationGracePeriod(IERC20 asset) external returns (uint40);
    function getLiquidationLogic() external pure returns (address);
    function getPoolLogic() external pure returns (address);
    function getReserveAddressById(uint16 id) external view returns (address);
    function getReserveData(IERC20 asset) external view returns (DataTypes.ReserveDataLegacy memory);
    function getReserveDataExtended(IERC20 asset) external view returns (DataTypes.ReserveData memory);
    function getReserveNormalizedIncome(IERC20 asset) external view returns (uint256);
    function getReserveNormalizedVariableDebt(IERC20 asset) external view returns (uint256);
    function getReservesCount() external view returns (uint256);
    function getReservesList() external view returns (address[] memory);
    function getSupplyLogic() external pure returns (address);
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
    function getUserConfiguration(address user) external view returns (DataTypes.UserConfigurationMap memory);
    function getUserEMode(address user) external view returns (uint256);
    function getVirtualUnderlyingBalance(IERC20 asset) external view returns (uint128);
    function initReserve(IERC20 asset, address aTokenAddress, address variableDebtAddress, address interestRateStrategyAddress) external;
    function initialize(address provider) external;
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function mintToTreasury(address[] memory assets) external;
    function mintUnbacked(IERC20 asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function repay(IERC20 asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function repayWithATokens(IERC20 asset, uint256 amount, uint256 interestRateMode) external returns (uint256);
    function repayWithPermit(
        IERC20 asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external returns (uint256);
    function rescueTokens(address token, address to, uint256 amount) external;
    function resetIsolationModeTotalDebt(IERC20 asset) external;
    function setConfiguration(IERC20 asset, DataTypes.ReserveConfigurationMap memory configuration) external;
    function setLiquidationGracePeriod(IERC20 asset, uint40 until) external;
    function setReserveInterestRateStrategyAddress(IERC20 asset, address rateStrategyAddress) external;
    function setUserEMode(uint8 categoryId) external;
    function setUserUseReserveAsCollateral(IERC20 asset, bool useAsCollateral) external;
    function supply(IERC20 asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function supplyWithPermit(
        IERC20 asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;
    function syncIndexesState(IERC20 asset) external;
    function syncRatesState(IERC20 asset) external;
    function updateBridgeProtocolFee(uint256 protocolFee) external;
    function updateFlashloanPremiums(uint128 flashLoanPremiumTotal, uint128 flashLoanPremiumToProtocol) external;
    function withdraw(IERC20 asset, uint256 amount, address to) external returns (uint256);

}
