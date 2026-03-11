// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface INexusAccountFactory {

    error AccountAlreadyDeployed(address account);
    error AlreadyInitialized();
    error EthTransferFailed();
    error ImplementationAddressCanNotBeZero();
    error InvalidEntryPointAddress();
    error NewOwnerIsZeroAddress();
    error NoHandoverRequest();
    error Unauthorized();
    error ZeroAddressNotAllowed();

    event AccountCreated(address indexed account, bytes indexed initData, bytes32 indexed salt);
    event OwnershipHandoverCanceled(address indexed pendingOwner);
    event OwnershipHandoverRequested(address indexed pendingOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    function ACCOUNT_IMPLEMENTATION() external view returns (address);
    function addStake(address epAddress, uint32 unstakeDelaySec) external payable;
    function cancelOwnershipHandover() external payable;
    function completeOwnershipHandover(address pendingOwner) external payable;
    function computeAccountAddress(bytes memory initData, bytes32 salt) external view returns (address payable expectedAddress);
    function createAccount(bytes memory initData, bytes32 salt) external payable returns (address payable);
    function owner() external view returns (address result);
    function ownershipHandoverExpiresAt(address pendingOwner) external view returns (uint256 result);
    function renounceOwnership() external payable;
    function requestOwnershipHandover() external payable;
    function transferOwnership(address newOwner) external payable;
    function unlockStake(address epAddress) external;
    function withdrawStake(address epAddress, address payable withdrawAddress) external;

}
