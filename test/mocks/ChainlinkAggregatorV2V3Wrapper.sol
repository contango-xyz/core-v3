//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import { Vm } from "forge-std/Vm.sol";
import { IAggregatorV2V3 } from "../dependencies/Chainlink.sol";

interface FooAccessControl {

    function addAccess(address _user) external;
    function owner() external view returns (address);

}

contract ChainlinkAggregatorV2V3Wrapper is IAggregatorV2V3 {

    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IAggregatorV2V3 public immutable AGGREGATOR_;
    address public immutable PROXY_;

    constructor(address _proxy) {
        AGGREGATOR_ = IAggregatorV2V3(_proxy).aggregator();
        PROXY_ = _proxy;
        VM.prank(FooAccessControl(address(AGGREGATOR_)).owner());
        FooAccessControl(address(AGGREGATOR_)).addAccess(address(this));
    }

    int256 public price;

    function setPrice(int256 _price) external {
        price = _price;
    }

    // V3

    function decimals() external view override returns (uint8) {
        return AGGREGATOR_.decimals();
    }

    function aggregator() external view override returns (IAggregatorV2V3) {
        return AGGREGATOR_.aggregator();
    }

    function description() external view override returns (string memory) {
        return AGGREGATOR_.description();
    }

    function version() external view override returns (uint256) {
        return AGGREGATOR_.version();
    }

    function getRoundData(uint80 roundId)
        external
        view
        override
        returns (uint80 roundId_, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId_, answer, startedAt, updatedAt, answeredInRound) = AGGREGATOR_.getRoundData(roundId);
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
        if (price != 0) answer = price;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = AGGREGATOR_.latestRoundData();
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
        if (price != 0) answer = price;
    }

    // V2

    function latestAnswer() external view override returns (int256 answer) {
        answer = AGGREGATOR_.latestAnswer();
        if (price != 0) answer = price;
    }

    function latestTimestamp() external view override returns (uint256) {
        return block.timestamp;
    }

    function latestRound() external view override returns (uint256) {
        return AGGREGATOR_.latestRound();
    }

    function getAnswer(uint256 roundId) external view override returns (int256) {
        return AGGREGATOR_.getAnswer(roundId);
    }

    function getTimestamp(uint256) external view override returns (uint256) {
        return block.timestamp;
    }

    // Aggregator

    function minAnswer() external pure returns (int192) {
        return type(int192).min;
    }

    function maxAnswer() external pure returns (int192) {
        return type(int192).max;
    }

}
