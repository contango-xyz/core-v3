// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { ISafe } from "./ISafe.sol";

interface ISafeProxyFactory {

    event ProxyCreation(address indexed proxy, address singleton);

    function createChainSpecificProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce)
        external
        returns (ISafe proxy);
    function createProxyWithCallback(address _singleton, bytes memory initializer, uint256 saltNonce, address callback)
        external
        returns (ISafe proxy);
    function createProxyWithNonce(address _singleton, bytes memory initializer, uint256 saltNonce) external returns (address proxy);
    function getChainId() external view returns (uint256);
    function proxyCreationCode() external pure returns (bytes memory);

}
