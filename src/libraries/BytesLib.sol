//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

library BytesLib {

    using Address for address;

    error InvalidOffset(uint256 offset, uint256 length);

    function set(bytes memory buffer, uint256 offset, bytes32 value) internal pure returns (bytes memory) {
        require(offset + 32 <= buffer.length, InvalidOffset(offset, buffer.length));
        assembly ("memory-safe") {
            mstore(add(32, add(buffer, offset)), value)
        }
        return buffer;
    }

    function set(bytes memory buffer, uint256 offset, uint256 value) internal pure returns (bytes memory) {
        return set(buffer, offset, bytes32(value));
    }

    function functionCall(bytes calldata data) internal returns (bytes memory returnData) {
        (address target, bytes calldata callData) = asFunctionCall(data);
        returnData = target.functionCall(callData);
    }

    function asFunctionCall(bytes calldata data) internal pure returns (address target, bytes calldata callData) {
        target = address(bytes20(data[:20]));
        callData = data[20:];
    }

}
