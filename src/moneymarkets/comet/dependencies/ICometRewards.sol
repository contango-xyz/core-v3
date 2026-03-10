// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC20 } from "./IComet.sol";

interface ICometRewards {

    struct RewardConfig {
        IERC20 token;
        uint64 rescaleFactor;
        bool shouldUpscale;
    }

    struct RewardOwed {
        IERC20 token;
        uint256 owed;
    }

    error AlreadyConfigured(address);
    error InvalidUInt64(uint256);
    error NotPermitted(address);
    error NotSupported(address);
    error TransferOutFailed(address, uint256);

    event GovernorTransferred(address indexed oldGovernor, address indexed newGovernor);
    event RewardClaimed(address indexed src, address indexed recipient, address indexed token, uint256 amount);

    function claim(address comet, address src, bool shouldAccrue) external;
    function claimTo(address comet, address src, address to, bool shouldAccrue) external;
    function getRewardOwed(address comet, address account) external returns (RewardOwed memory);
    function governor() external view returns (address);
    function rewardConfig(address) external view returns (RewardConfig memory);
    function rewardsClaimed(address, address) external view returns (uint256);
    function setRewardConfig(address comet, address token) external;
    function transferGovernor(address newGovernor) external;
    function withdrawToken(address token, address to, uint256 amount) external;

}
