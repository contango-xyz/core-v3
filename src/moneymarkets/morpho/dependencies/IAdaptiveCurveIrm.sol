// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IAdaptiveCurveIrm {

    type Id is bytes32;

    struct Market {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
        uint128 lastUpdate;
        uint128 fee;
    }

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    event BorrowRateUpdate(Id indexed id, uint256 avgBorrowRate, uint256 rateAtTarget);

    function MORPHO() external view returns (address);
    function borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256);
    function borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256);
    function rateAtTarget(Id) external view returns (int256);

}
