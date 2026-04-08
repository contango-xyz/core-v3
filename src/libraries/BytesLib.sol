//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

library BytesLib {

    using Address for address;

    error InvalidOffset(uint256 offset, uint256 length);

    /**
     * @notice Sets a bytes32 value in a buffer at a specific offset.
     * @param buffer The bytes buffer to modify.
     * @param offset The offset in the buffer where the value should be set.
     * @param value The bytes32 value to set.
     * @return The modified buffer.
     */
    function set(bytes memory buffer, uint256 offset, bytes32 value) internal pure returns (bytes memory) {
        require(offset + 32 <= buffer.length, InvalidOffset(offset, buffer.length));
        assembly ("memory-safe") {
            mstore(add(32, add(buffer, offset)), value)
        }
        return buffer;
    }

    /**
     * @notice Sets a uint256 value in a buffer at a specific offset.
     * @param buffer The bytes buffer to modify.
     * @param offset The offset in the buffer where the value should be set.
     * @param value The uint256 value to set.
     * @return The modified buffer.
     */
    function set(bytes memory buffer, uint256 offset, uint256 value) internal pure returns (bytes memory) {
        return set(buffer, offset, bytes32(value));
    }

    /**
     * @notice Executes a dynamic function call from encoded data.
     * @dev The first 20 bytes of `data` are treated as the target address, and the remainder as the calldata.
     * @dev This call is intended to be executed within the context of an account executor, which provides the necessary security validations.
     * @param data Encoded data: [0:20 bytes target address, 20:+ bytes call data (selector + params)].
     * @return returnData The return data from the function call.
     */
    function functionCall(bytes calldata data) internal returns (bytes memory returnData) {
        (address target, bytes calldata callData) = asFunctionCall(data);
        returnData = target.functionCall(callData);
    }

    /**
     * @notice Decodes the target address and call data from encoded bytes.
     * @dev The layout expected is the target address (20 bytes) followed by the call data.
     * @param data Encoded data: [0:20 bytes target address, 20:+ bytes call data].
     * @return target The target address for the function call.
     * @return callData The data to be passed to the target address.
     */
    function asFunctionCall(bytes calldata data) internal pure returns (address target, bytes calldata callData) {
        target = address(bytes20(data[:20]));
        callData = data[20:];
    }

}
