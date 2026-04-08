//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// @custom:security-contact security@contango.xyz
contract LogAction {

    /**
     * @notice Emits an anonymous log (no topics).
     * @dev See `LogAction.t.sol` for examples.
     * @param data The encoded data to log.
     * @custom:example `log0(abi.encode(uint256(666)))`
     */
    function log0(bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log0(ptr, len)
        }
    }

    /**
     * @notice Emits a log with 1 topic.
     * @dev See `LogAction.t.sol` for examples.
     * @param topic0 The first topic (usually the event signature hash).
     * @param data The encoded data to log.
     * @custom:example `log1(keccak256("Foo(uint256)"), abi.encode(uint256(666)))`
     */
    function log1(bytes32 topic0, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log1(ptr, len, topic0)
        }
    }

    /**
     * @notice Emits a log with 2 topics.
     * @dev See `LogAction.t.sol` for examples.
     * @param topic0 The first topic.
     * @param topic1 The second topic (e.g., an indexed parameter).
     * @param data The encoded data to log.
     * @custom:example `log2(keccak256("Foo(uint256,uint256)"), bytes32(uint256(666)), abi.encode(uint256(777)))`
     */
    function log2(bytes32 topic0, bytes32 topic1, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log2(ptr, len, topic0, topic1)
        }
    }

    /**
     * @notice Emits a log with 3 topics.
     * @dev See `LogAction.t.sol` for examples.
     * @param topic0 The first topic.
     * @param topic1 The second topic.
     * @param topic2 The third topic.
     * @param data The encoded data to log.
     * @custom:example `log3(keccak256("Foo(...)"), t1, t2, abi.encode(data))`
     */
    function log3(bytes32 topic0, bytes32 topic1, bytes32 topic2, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log3(ptr, len, topic0, topic1, topic2)
        }
    }

    /**
     * @notice Emits a log with 4 topics.
     * @dev See `LogAction.t.sol` for examples.
     * @param topic0 The first topic.
     * @param topic1 The second topic.
     * @param topic2 The third topic.
     * @param topic3 The fourth topic.
     * @param data The encoded data to log.
     * @custom:example `log4(keccak256("Foo(...)"), t1, t2, t3, abi.encode(data))`
     */
    function log4(bytes32 topic0, bytes32 topic1, bytes32 topic2, bytes32 topic3, bytes memory data) public {
        assembly {
            let ptr := add(data, 32)
            let len := mload(data)
            log4(ptr, len, topic0, topic1, topic2, topic3)
        }
    }

}
