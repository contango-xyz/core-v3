// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IEulerIRM {

    error E_IRMUpdateUnauthorized();

    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256);

    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256);

}
