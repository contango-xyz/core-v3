// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IPendleMarketV3 {

    struct MarketState {
        int256 totalPt;
        int256 totalSy;
        int256 totalLp;
        address treasury;
        int256 scalarRoot;
        uint256 expiry;
        uint256 lnFeeRateRoot;
        uint256 reserveFeePercent;
        uint256 lastLnImpliedRate;
    }

    error MarketExchangeRateBelowOne(int256 exchangeRate);
    error MarketExpired();
    error MarketInsufficientPtForTrade(int256 currentAmount, int256 requiredAmount);
    error MarketInsufficientPtReceived(uint256 actualBalance, uint256 requiredBalance);
    error MarketInsufficientSyReceived(uint256 actualBalance, uint256 requiredBalance);
    error MarketProportionMustNotEqualOne();
    error MarketProportionTooHigh(int256 proportion, int256 maxProportion);
    error MarketRateScalarBelowZero(int256 rateScalar);
    error MarketScalarRootBelowZero(int256 scalarRoot);
    error MarketZeroAmountsInput();
    error MarketZeroAmountsOutput();
    error MarketZeroLnImpliedRate();
    error MarketZeroTotalPtOrTotalAsset(int256 totalPt, int256 totalAsset);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed receiverSy, address indexed receiverPt, uint256 netLpBurned, uint256 netSyOut, uint256 netPtOut);
    event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew);
    event Mint(address indexed receiver, uint256 netLpMinted, uint256 netSyUsed, uint256 netPtUsed);
    event RedeemRewards(address indexed user, uint256[] rewardsOut);
    event Swap(
        address indexed caller, address indexed receiver, int256 netPtOut, int256 netSyOut, uint256 netSyFee, uint256 netSyToReserve
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event UpdateImpliedRate(uint256 indexed timestamp, uint256 lnLastImpliedRate);

    function _storage()
        external
        view
        returns (
            int128 totalPt,
            int128 totalSy,
            uint96 lastLnImpliedRate,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext
        );
    function activeBalance(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burn(address receiverSy, address receiverPt, uint256 netLpToBurn) external returns (uint256 netSyOut, uint256 netPtOut);
    function decimals() external view returns (uint8);
    function expiry() external view returns (uint256);
    function factory() external view returns (address);
    function getNonOverrideLnFeeRateRoot() external view returns (uint80);
    function getRewardTokens() external view returns (address[] memory);
    function increaseObservationsCardinalityNext(uint16 cardinalityNext) external;
    function isExpired() external view returns (bool);
    function lastRewardBlock() external view returns (uint256);
    function mint(address receiver, uint256 netSyDesired, uint256 netPtDesired)
        external
        returns (uint256 netLpOut, uint256 netSyUsed, uint256 netPtUsed);
    function name() external view returns (string memory);
    function observations(uint256) external view returns (uint32 blockTimestamp, uint216 lnImpliedRateCumulative, bool initialized);
    function observe(uint32[] memory secondsAgos) external view returns (uint216[] memory lnImpliedRateCumulative);
    function readState(address router) external view returns (MarketState memory market);

    struct Tokens {
        address sy;
        address pt;
        address yt;
    }

    function readTokens() external view returns (Tokens memory tokens);
    function redeemRewards(address user) external returns (uint256[] memory);
    function rewardState(address) external view returns (uint128 index, uint128 lastBalance);
    function skim() external;
    function swapExactPtForSy(address receiver, uint256 exactPtIn, bytes memory data) external returns (uint256 netSyOut, uint256 netSyFee);
    function swapSyForExactPt(address receiver, uint256 exactPtOut, bytes memory data) external returns (uint256 netSyIn, uint256 netSyFee);
    function symbol() external view returns (string memory);
    function totalActiveSupply() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function userReward(address, address) external view returns (uint128 index, uint128 accrued);

}

interface IPendleMarketSwapCallback {

    function swapCallback(int256 ptToAccount, int256 syToAccount, bytes calldata data) external;

}

interface IPendleMarketFactoryV3 {

    error MFNotPendleMarket(address addr);
    error MarketFactoryExpiredPt();
    error MarketFactoryInitialAnchorTooLow(int256 initialAnchor, int256 minInitialAnchor);
    error MarketFactoryInvalidPt();
    error MarketFactoryLnFeeRateRootTooHigh(uint80 lnFeeRateRoot, uint256 maxLnFeeRateRoot);
    error MarketFactoryMarketExists();
    error MarketFactoryOverriddenFeeTooHigh(uint80 overriddenFee, uint256 marketLnFeeRateRoot);
    error MarketFactoryReserveFeePercentTooHigh(uint8 reserveFeePercent, uint8 maxReserveFeePercent);
    error MarketFactoryZeroTreasury();

    event CreateNewMarket(address indexed market, address indexed PT, int256 scalarRoot, int256 initialAnchor, uint256 lnFeeRateRoot);
    event Initialized(uint8 version);
    event NewTreasuryAndFeeReserve(address indexed treasury, uint8 reserveFeePercent);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SetOverriddenFee(address indexed router, address indexed market, uint80 lnFeeRateRoot);

    function claimOwnership() external;
    function createNewMarket(address PT, int256 scalarRoot, int256 initialAnchor, uint80 lnFeeRateRoot) external returns (address market);
    function gaugeController() external view returns (address);
    function getMarketConfig(address market, address router)
        external
        view
        returns (address _treasury, uint80 _overriddenFee, uint8 _reserveFeePercent);
    function isValidMarket(address market) external view returns (bool);
    function marketCreationCodeContractA() external view returns (address);
    function marketCreationCodeContractB() external view returns (address);
    function marketCreationCodeSizeA() external view returns (uint256);
    function marketCreationCodeSizeB() external view returns (uint256);
    function maxLnFeeRateRoot() external view returns (uint256);
    function maxReserveFeePercent() external view returns (uint8);
    function minInitialAnchor() external view returns (int256);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function reserveFeePercent() external view returns (uint8);
    function setOverriddenFee(address router, address market, uint80 newFee) external;
    function setTreasuryAndFeeReserve(address newTreasury, uint8 newReserveFeePercent) external;
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
    function treasury() external view returns (address);
    function vePendle() external view returns (address);
    function yieldContractFactory() external view returns (address);

}

interface IPendleYieldContractFactory {

    error YCFactoryInterestFeeRateTooHigh(uint256 interestFeeRate, uint256 maxInterestFeeRate);
    error YCFactoryInvalidExpiry();
    error YCFactoryRewardFeeRateTooHigh(uint256 newRewardFeeRate, uint256 maxRewardFeeRate);
    error YCFactoryYieldContractExisted();
    error YCFactoryZeroExpiryDivisor();
    error YCFactoryZeroTreasury();

    event CreateYieldContract(address indexed SY, uint256 indexed expiry, address PT, address YT);
    event Initialized(uint8 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SetExpiryDivisor(uint256 newExpiryDivisor);
    event SetInterestFeeRate(uint256 newInterestFeeRate);
    event SetRewardFeeRate(uint256 newRewardFeeRate);
    event SetTreasury(address indexed treasury);

    function claimOwnership() external;
    function createYieldContract(address SY, uint32 expiry, bool doCacheIndexSameBlock) external returns (address PT, address YT);
    function expiryDivisor() external view returns (uint96);
    function getPT(address, uint256) external view returns (address);
    function getYT(address, uint256) external view returns (address);
    function initialize(uint96 _expiryDivisor, uint128 _interestFeeRate, uint128 _rewardFeeRate, address _treasury) external;
    function interestFeeRate() external view returns (uint128);
    function isPT(address) external view returns (bool);
    function isYT(address) external view returns (bool);
    function maxInterestFeeRate() external view returns (uint256);
    function maxRewardFeeRate() external view returns (uint256);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function rewardFeeRate() external view returns (uint128);
    function setExpiryDivisor(uint96 newExpiryDivisor) external;
    function setInterestFeeRate(uint128 newInterestFeeRate) external;
    function setRewardFeeRate(uint128 newRewardFeeRate) external;
    function setTreasury(address newTreasury) external;
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
    function treasury() external view returns (address);
    function ytCreationCodeContractA() external view returns (address);
    function ytCreationCodeContractB() external view returns (address);
    function ytCreationCodeSizeA() external view returns (uint256);
    function ytCreationCodeSizeB() external view returns (uint256);

}

interface IPendleSY {

    type AssetType is uint8;

    error InvalidShortString();
    error SYInsufficientSharesOut(uint256 actualSharesOut, uint256 requiredSharesOut);
    error SYInsufficientTokenOut(uint256 actualTokenOut, uint256 requiredTokenOut);
    error SYInvalidTokenIn(address token);
    error SYInvalidTokenOut(address token);
    error SYZeroDeposit();
    error SYZeroRedeem();
    error StringTooLong(string str);
    error SupplyCapExceeded(uint256 totalSupply, uint256 supplyCap);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ClaimRewards(address indexed user, address[] rewardTokens, uint256[] rewardAmounts);
    event Deposit(address indexed caller, address indexed receiver, address indexed tokenIn, uint256 amountDeposited, uint256 amountSyOut);
    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Redeem(
        address indexed caller, address indexed receiver, address indexed tokenOut, uint256 amountSyToRedeem, uint256 amountTokenOut
    );
    event SupplyCapUpdated(uint256 newSupplyCap);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);

    receive() external payable;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function accruedRewards(address) external view returns (uint256[] memory rewardAmounts);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function assetInfo() external view returns (IPendleSY.AssetType assetType, address assetAddress, uint8 assetDecimals);
    function balanceOf(address account) external view returns (uint256);
    function claimOwnership() external;
    function claimRewards(address) external returns (uint256[] memory rewardAmounts);
    function decimals() external view returns (uint8);
    function deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 minSharesOut)
        external
        payable
        returns (uint256 amountSharesOut);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function exchangeRate() external view returns (uint256);
    function getAbsoluteSupplyCap() external view returns (uint256);
    function getAbsoluteTotalSupply() external view returns (uint256);
    function getRewardTokens() external view returns (address[] memory rewardTokens);
    function getTokensIn() external view returns (address[] memory res);
    function getTokensOut() external view returns (address[] memory res);
    function isValidTokenIn(address token) external view returns (bool);
    function isValidTokenOut(address token) external view returns (bool);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingOwner() external view returns (address);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit) external view returns (uint256 amountSharesOut);
    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem) external view returns (uint256 amountTokenOut);
    function redeem(address receiver, uint256 amountSharesToRedeem, address tokenOut, uint256 minTokenOut, bool burnFromInternalBalance)
        external
        returns (uint256 amountTokenOut);
    function rewardIndexesCurrent() external returns (uint256[] memory indexes);
    function rewardIndexesStored() external view returns (uint256[] memory indexes);
    function supplyCap() external view returns (uint256);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
    function unpause() external;
    function updateSupplyCap(uint256 newSupplyCap) external;
    function yieldToken() external view returns (address);

}
