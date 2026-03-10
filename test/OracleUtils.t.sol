// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import { Vm } from "forge-std/Vm.sol";

import { ChainlinkAggregatorV2V3Wrapper } from "./mocks/ChainlinkAggregatorV2V3Wrapper.sol";

abstract contract OracleUtils {

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function wrapChainlinkAggregator(address chainlinkProxy) internal returns (ChainlinkAggregatorV2V3Wrapper wrapper) {
        wrapper = new ChainlinkAggregatorV2V3Wrapper(chainlinkProxy);

        vm.startPrank(IChainlinkAggregatorOwned(chainlinkProxy).owner());
        IChainlinkAggregatorOwned(chainlinkProxy).proposeAggregator(address(wrapper));
        IChainlinkAggregatorOwned(chainlinkProxy).confirmAggregator(address(wrapper));
        vm.stopPrank();
    }

}

interface IChainlinkAggregatorOwned {

    function owner() external view returns (address);
    function proposeAggregator(address _aggregator) external;
    function confirmAggregator(address _aggregator) external;

}
