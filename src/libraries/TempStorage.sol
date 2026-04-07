//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { TransientSlot } from "@openzeppelin/contracts/utils/TransientSlot.sol";
import { SlotDerivation } from "@openzeppelin/contracts/utils/SlotDerivation.sol";

type TempStorageKey is bytes32;

library TempStorage {

    using TransientSlot for *;
    using SlotDerivation for *;

    /**
     * @notice Creates a new transient storage key from a string.
     * @dev Uses ERC-7201 slot derivation.
     * @param str The string to derive the key from.
     * @return The derived TempStorageKey.
     */
    function newKey(string memory str) internal pure returns (TempStorageKey) {
        return TempStorageKey.wrap(str.erc7201Slot());
    }

    /**
     * @notice Writes a boolean value to a double-mapped transient storage (address => bytes32 => bool).
     * @param key The base transient storage key.
     * @param mappingKey1 The first mapping key (address).
     * @param mappingKey2 The second mapping key (bytes32).
     * @param newValue The boolean value to write.
     */
    function writeAddressBytes32BoolMapping(TempStorageKey key, address mappingKey1, bytes32 mappingKey2, bool newValue) internal {
        TempStorageKey.unwrap(key).deriveMapping(mappingKey1).deriveMapping(mappingKey2).asBoolean().tstore(newValue);
    }

    /**
     * @notice Reads a boolean value from a double-mapped transient storage (address => bytes32 => bool).
     * @param key The base transient storage key.
     * @param mappingKey1 The first mapping key (address).
     * @param mappingKey2 The second mapping key (bytes32).
     * @return The boolean value read from transient storage.
     */
    function readAddressBytes32BoolMapping(TempStorageKey key, address mappingKey1, bytes32 mappingKey2) internal view returns (bool) {
        return TempStorageKey.unwrap(key).deriveMapping(mappingKey1).deriveMapping(mappingKey2).asBoolean().tload();
    }

}

using TempStorage for TempStorageKey global;
