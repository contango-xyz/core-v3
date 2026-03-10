// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ICometExt is IERC20Metadata {

    error BadAmount();
    error BadNonce();
    error BadSignatory();
    error InvalidValueS();
    error InvalidValueV();
    error SignatureExpired();

    // 512 bits total = 2 slots
    struct TotalsBasic {
        // 1st slot
        uint64 baseSupplyIndex;
        uint64 baseBorrowIndex;
        uint64 trackingSupplyIndex;
        uint64 trackingBorrowIndex;
        // 2nd slot
        uint104 totalSupplyBase;
        uint104 totalBorrowBase;
        uint40 lastAccrualTime;
        uint8 pauseFlags;
    }

    function allow(address manager, bool isAllowed) external;
    function allowBySig(address owner, address manager, bool isAllowed, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
        external;

    function collateralBalanceOf(address account, IERC20 asset) external view returns (uint128);
    function baseTrackingAccrued(address account) external view returns (uint64);

    function baseAccrualScale() external view returns (uint64);
    function baseIndexScale() external view returns (uint64);
    function factorScale() external view returns (uint64);
    function priceScale() external view returns (uint64);

    function maxAssets() external view returns (uint8);

    function totalsBasic() external view returns (TotalsBasic memory);

    function version() external view returns (string memory);

}

interface IComet is ICometExt {

    struct AssetConfig {
        IERC20 asset;
        address priceFeed;
        uint8 decimals;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    struct AssetInfo {
        uint8 offset;
        IERC20 asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    struct Configuration {
        address governor;
        address pauseGuardian;
        IERC20 baseToken;
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

    struct TotalsCollateral {
        uint128 totalSupplyAsset;
        uint128 _reserved;
    }

    struct UserCollateral {
        uint128 balance;
        uint128 _reserved;
    }

    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    error Absurd();
    error AlreadyInitialized();
    error BadAsset();
    error BadDecimals();
    error BadDiscount();
    error BadMinimum();
    error BadPrice();
    error BorrowCFTooLarge();
    error BorrowTooSmall();
    error InsufficientReserves();
    error InvalidInt104();
    error InvalidInt256();
    error InvalidUInt104();
    error InvalidUInt128();
    error InvalidUInt64();
    error LiquidateCFTooLarge();
    error NegativeNumber();
    error NoSelfTransfer();
    error NotCollateralized();
    error NotForSale();
    error NotLiquidatable();
    error Paused();
    error SupplyCapExceeded();
    error TimestampTooLarge();
    error TooManyAssets();
    error TooMuchSlippage();
    error TransferInFailed();
    error TransferOutFailed();
    error Unauthorized();

    event AbsorbCollateral(address indexed absorber, address indexed borrower, address indexed asset, uint256 amount, uint256 usdValue);
    event AbsorbDebt(address indexed absorber, address indexed borrower, uint256 amount, uint256 usdValue);
    event BuyCollateral(address indexed buyer, address indexed asset, uint256 baseAmount, uint256 collateralAmount);
    event PauseAction(bool supplyPaused, bool transferPaused, bool withdrawPaused, bool absorbPaused, bool buyPaused);
    event Supply(address indexed from, address indexed dst, uint256 amount);
    event SupplyCollateral(address indexed from, address indexed dst, address indexed asset, uint256 amount);
    event TransferCollateral(address indexed from, address indexed to, address indexed asset, uint256 amount);
    event Withdraw(address indexed src, address indexed to, uint256 amount);
    event WithdrawCollateral(address indexed src, address indexed to, address indexed asset, uint256 amount);
    event WithdrawReserves(address indexed to, uint256 amount);

    function absorb(address absorber, address[] memory accounts) external;
    function accrueAccount(address account) external;
    function approveThis(address manager, IERC20 asset, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function baseBorrowMin() external view returns (uint256);
    function baseMinForRewards() external view returns (uint256);
    function baseScale() external view returns (uint256);
    function baseToken() external view returns (IERC20);
    function baseTokenPriceFeed() external view returns (address);
    function baseTrackingBorrowSpeed() external view returns (uint256);
    function baseTrackingSupplySpeed() external view returns (uint256);
    function borrowBalanceOf(address account) external view returns (uint256);
    function borrowKink() external view returns (uint256);
    function borrowPerSecondInterestRateBase() external view returns (uint256);
    function borrowPerSecondInterestRateSlopeHigh() external view returns (uint256);
    function borrowPerSecondInterestRateSlopeLow() external view returns (uint256);
    function buyCollateral(IERC20 asset, uint256 minAmount, uint256 baseAmount, address recipient) external;
    function decimals() external view returns (uint8);
    function extensionDelegate() external view returns (address);
    function getAssetInfo(uint8 i) external view returns (AssetInfo memory);
    function getAssetInfoByAddress(IERC20 asset) external view returns (AssetInfo memory);
    function getBorrowRate(uint256 utilization) external view returns (uint64);
    function getCollateralReserves(IERC20 asset) external view returns (uint256);
    function getPrice(address priceFeed) external view returns (uint256);
    function getReserves() external view returns (int256);
    function getSupplyRate(uint256 utilization) external view returns (uint64);
    function getUtilization() external view returns (uint256);
    function governor() external view returns (address);
    function hasPermission(address owner, address manager) external view returns (bool);
    function initializeStorage() external;
    function isAbsorbPaused() external view returns (bool);
    function isAllowed(address, address) external view returns (bool);
    function isBorrowCollateralized(address account) external view returns (bool);
    function isBuyPaused() external view returns (bool);
    function isLiquidatable(address account) external view returns (bool);
    function isSupplyPaused() external view returns (bool);
    function isTransferPaused() external view returns (bool);
    function isWithdrawPaused() external view returns (bool);
    function liquidatorPoints(address) external view returns (uint32 numAbsorbs, uint64 numAbsorbed, uint128 approxSpend, uint32 _reserved);
    function numAssets() external view returns (uint8);
    function pause(bool supplyPaused, bool transferPaused, bool withdrawPaused, bool absorbPaused, bool buyPaused) external;
    function pauseGuardian() external view returns (address);
    function quoteCollateral(IERC20 asset, uint256 baseAmount) external view returns (uint256);
    function storeFrontPriceFactor() external view returns (uint256);
    function supply(IERC20 asset, uint256 amount) external;
    function supplyFrom(address from, address dst, IERC20 asset, uint256 amount) external;
    function supplyKink() external view returns (uint256);
    function supplyPerSecondInterestRateBase() external view returns (uint256);
    function supplyPerSecondInterestRateSlopeHigh() external view returns (uint256);
    function supplyPerSecondInterestRateSlopeLow() external view returns (uint256);
    function supplyTo(address dst, IERC20 asset, uint256 amount) external;
    function targetReserves() external view returns (uint256);
    function totalBorrow() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalsCollateral(IERC20) external view returns (TotalsCollateral memory);
    function trackingIndexScale() external view returns (uint256);
    function transfer(address dst, uint256 amount) external returns (bool);
    function transferAsset(address dst, IERC20 asset, uint256 amount) external;
    function transferAssetFrom(address src, address dst, IERC20 asset, uint256 amount) external;
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
    function userBasic(address) external view returns (UserBasic memory);
    function userCollateral(address, IERC20) external view returns (UserCollateral memory);
    function userNonce(address) external view returns (uint256);
    function withdraw(IERC20 asset, uint256 amount) external;
    function withdrawFrom(address src, address to, IERC20 asset, uint256 amount) external;
    function withdrawReserves(address to, uint256 amount) external;
    function withdrawTo(address to, IERC20 asset, uint256 amount) external;

}
