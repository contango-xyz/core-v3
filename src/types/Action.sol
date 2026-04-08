//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

struct Action {
    address target;
    uint256 value;
    bytes data;
    bool delegateCall;
    bool allowFailure;
}

struct ActionResult {
    bool success;
    bytes data;
}

/// @notice The packed action data is tightly packed in the following format:
/// @notice - [0:20]   target address (20 bytes)
/// @notice - [20:32]  value as uint96 (12 bytes)
/// @notice - [32:33]  delegateCall flag (1 byte, 0x01 = true)
/// @notice - [33:34]  allowFailure flag (1 byte, 0x01 = true)
/// @notice - [34:]    call data (remaining bytes)
struct PackedAction {
    bytes data;
}

library PackedActionLib {

    uint256 internal constant CALL_DATA_OFFSET = 34;

    /**
     * @notice Unpacks an encoded action payload.
     * @param packedAction The encoded packed action payload.
     * @return action_ The unpacked action struct.
     */
    function unpack(PackedAction calldata packedAction) internal pure returns (Action memory action_) {
        action_.target = address(bytes20(packedAction.data[:20]));
        action_.value = uint96(bytes12(packedAction.data[20:32]));
        action_.delegateCall = packedAction.data[32] == 0x01;
        action_.allowFailure = packedAction.data[33] == 0x01;
        action_.data = packedAction.data[CALL_DATA_OFFSET:];
    }

}

using PackedActionLib for PackedAction global;
