//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

import { LogAction } from "../../src/actions/LogAction.sol";

contract LogActionTest is Test {

    LogAction private logAction = new LogAction();

    event Foo(bytes data) anonymous;

    event FooOneTopic();
    event FooOneTopicData(uint256 data);
    event FooOneTopicMultiData(uint256 data1, address data2, string data3);
    event FooOneTopicRawData(bytes data);

    event FooTwoTopic(uint256 indexed topic1);
    event FooTwoTopicData(uint256 indexed topic1, uint256 data);
    event FooTwoTopicMultiData(uint256 indexed topic1, uint256 data1, address data2, string data3);
    event FooTwoTopicRawData(uint256 indexed topic1, bytes data);

    event FooThreeTopic(uint256 indexed topic1, uint256 indexed topic2);
    event FooThreeTopicData(uint256 indexed topic1, uint256 indexed topic2, uint256 data);
    event FooThreeTopicMultiData(uint256 indexed topic1, uint256 indexed topic2, uint256 data1, address data2, string data3);
    event FooThreeTopicRawData(uint256 indexed topic1, uint256 indexed topic2, bytes data);

    event FooFourTopic(uint256 indexed topic1, uint256 indexed topic2, uint256 indexed topic3);
    event FooFourTopicData(uint256 indexed topic1, uint256 indexed topic2, uint256 indexed topic3, uint256 data);
    event FooFourTopicMultiData(
        uint256 indexed topic1, uint256 indexed topic2, uint256 indexed topic3, uint256 data1, address data2, string data3
    );
    event FooFourTopicRawData(uint256 indexed topic1, uint256 indexed topic2, uint256 indexed topic3, bytes data);

    event FooIndexedString(string indexed topic1);

    modifier withGenericLogs() {
        vm.recordLogs();
        _;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 2, "Expected 2 logs");
        assertEq(logs[0].topics.length, logs[1].topics.length, "Expected same number of topics");

        for (uint256 i = 0; i < logs[0].topics.length; i++) {
            assertEq(logs[0].topics[i], logs[1].topics[i], string.concat("Expected same topic ", vm.toString(i), " content"));
        }

        assertEq(logs[0].data, logs[1].data, "Expected same data");
    }

    function test_Foo() public withGenericLogs {
        emit Foo(abi.encode(uint256(666)));
        logAction.log0(abi.encode(abi.encode(uint256(666))));
    }

    function test_FooOneTopic() public withGenericLogs {
        emit FooOneTopic();
        logAction.log1(keccak256("FooOneTopic()"), "");
    }

    function test_FooOneTopicData() public withGenericLogs {
        emit FooOneTopicData(666);
        logAction.log1(keccak256("FooOneTopicData(uint256)"), abi.encode(uint256(666)));
    }

    function test_FooOneTopicMultiData() public withGenericLogs {
        emit FooOneTopicMultiData(666, 0x1234567890123456789012345678901234567890, "Hello, world!");
        logAction.log1(
            keccak256("FooOneTopicMultiData(uint256,address,string)"),
            abi.encode(666, address(0x1234567890123456789012345678901234567890), "Hello, world!")
        );
    }

    function test_FooOneTopicRawData() public withGenericLogs {
        emit FooOneTopicRawData(abi.encode(uint256(666)));
        logAction.log1(keccak256("FooOneTopicRawData(bytes)"), abi.encode(abi.encode(uint256(666))));
    }

    function test_FooTwoTopic() public withGenericLogs {
        emit FooTwoTopic(666);
        logAction.log2(keccak256("FooTwoTopic(uint256)"), bytes32(uint256(666)), "");
    }

    function test_FooTwoTopicData() public withGenericLogs {
        emit FooTwoTopicData(666, 777);
        logAction.log2(keccak256("FooTwoTopicData(uint256,uint256)"), bytes32(uint256(666)), abi.encode(uint256(777)));
    }

    function test_FooTwoTopicMultiData() public withGenericLogs {
        emit FooTwoTopicMultiData(666, 777, 0x1234567890123456789012345678901234567890, "Hello, world!");
        logAction.log2(
            keccak256("FooTwoTopicMultiData(uint256,uint256,address,string)"),
            bytes32(uint256(666)),
            abi.encode(777, address(0x1234567890123456789012345678901234567890), "Hello, world!")
        );
    }

    function test_FooTwoTopicRawData() public withGenericLogs {
        emit FooTwoTopicRawData(666, abi.encode(uint256(777)));
        logAction.log2(keccak256("FooTwoTopicRawData(uint256,bytes)"), bytes32(uint256(666)), abi.encode(abi.encode(uint256(777))));
    }

    function test_FooThreeTopic() public withGenericLogs {
        emit FooThreeTopic(666, 777);
        logAction.log3(keccak256("FooThreeTopic(uint256,uint256)"), bytes32(uint256(666)), bytes32(uint256(777)), "");
    }

    function test_FooThreeTopicData() public withGenericLogs {
        emit FooThreeTopicData(666, 777, 888);
        logAction.log3(
            keccak256("FooThreeTopicData(uint256,uint256,uint256)"), bytes32(uint256(666)), bytes32(uint256(777)), abi.encode(uint256(888))
        );
    }

    function test_FooThreeTopicMultiData() public withGenericLogs {
        emit FooThreeTopicMultiData(666, 777, 888, 0x1234567890123456789012345678901234567890, "Hello, world!");
        logAction.log3(
            keccak256("FooThreeTopicMultiData(uint256,uint256,uint256,address,string)"),
            bytes32(uint256(666)),
            bytes32(uint256(777)),
            abi.encode(888, address(0x1234567890123456789012345678901234567890), "Hello, world!")
        );
    }

    function test_FooThreeTopicRawData() public withGenericLogs {
        emit FooThreeTopicRawData(666, 777, abi.encode(uint256(888)));
        logAction.log3(
            keccak256("FooThreeTopicRawData(uint256,uint256,bytes)"),
            bytes32(uint256(666)),
            bytes32(uint256(777)),
            abi.encode(abi.encode(uint256(888)))
        );
    }

    function test_FooFourTopic() public withGenericLogs {
        emit FooFourTopic(666, 777, 888);
        logAction.log4(
            keccak256("FooFourTopic(uint256,uint256,uint256)"), bytes32(uint256(666)), bytes32(uint256(777)), bytes32(uint256(888)), ""
        );
    }

    function test_FooFourTopicData() public withGenericLogs {
        emit FooFourTopicData(666, 777, 888, 999);
        logAction.log4(
            keccak256("FooFourTopicData(uint256,uint256,uint256,uint256)"),
            bytes32(uint256(666)),
            bytes32(uint256(777)),
            bytes32(uint256(888)),
            abi.encode(uint256(999))
        );
    }

    function test_FooFourTopicMultiData() public withGenericLogs {
        emit FooFourTopicMultiData(666, 777, 888, 999, 0x1234567890123456789012345678901234567890, "Hello, world!");
        logAction.log4(
            keccak256("FooFourTopicMultiData(uint256,uint256,uint256,uint256,address,string)"),
            bytes32(uint256(666)),
            bytes32(uint256(777)),
            bytes32(uint256(888)),
            abi.encode(999, address(0x1234567890123456789012345678901234567890), "Hello, world!")
        );
    }

    function test_FooFourTopicRawData() public withGenericLogs {
        emit FooFourTopicRawData(666, 777, 888, abi.encode(uint256(999)));
        logAction.log4(
            keccak256("FooFourTopicRawData(uint256,uint256,uint256,bytes)"),
            bytes32(uint256(666)),
            bytes32(uint256(777)),
            bytes32(uint256(888)),
            abi.encode(abi.encode(uint256(999)))
        );
    }

    function test_FooIndexedString() public withGenericLogs {
        string memory longString = "Hello, world! this message is longer than 32 bytes";
        emit FooIndexedString(longString);
        logAction.log2(keccak256("FooIndexedString(string)"), keccak256(bytes(longString)), "");
    }

}
