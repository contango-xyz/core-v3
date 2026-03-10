//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

contract LogAction {

    function log0(bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log0(ptr, len)
        }
    }

    function log1(bytes32 topic0, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log1(ptr, len, topic0)
        }
    }

    function log2(bytes32 topic0, bytes32 topic1, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log2(ptr, len, topic0, topic1)
        }
    }

    function log3(bytes32 topic0, bytes32 topic1, bytes32 topic2, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log3(ptr, len, topic0, topic1, topic2)
        }
    }

    function log4(bytes32 topic0, bytes32 topic1, bytes32 topic2, bytes32 topic3, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log4(ptr, len, topic0, topic1, topic2, topic3)
        }
    }

}
