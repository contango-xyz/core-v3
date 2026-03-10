// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IEulerPerspective {

    event PerspectiveUnverified(address indexed vault);
    event PerspectiveVerified(address indexed vault);

    function isVerified(address vault) external view returns (bool);

    function verifiedArray() external view returns (address[] memory);

}
