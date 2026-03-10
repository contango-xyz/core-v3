//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { TransientSlot } from "@openzeppelin/contracts/utils/TransientSlot.sol";
import { SlotDerivation } from "@openzeppelin/contracts/utils/SlotDerivation.sol";

type TempStorageKey is bytes32;

library TempStorage {

    using TransientSlot for *;
    using SlotDerivation for *;

    function newKey(string memory str) internal pure returns (TempStorageKey) {
        return TempStorageKey.wrap(str.erc7201Slot());
    }

    function writeAddressBytes32BoolMapping(TempStorageKey key, address mappingKey1, bytes32 mappingKey2, bool newValue) internal {
        TempStorageKey.unwrap(key).deriveMapping(mappingKey1).deriveMapping(mappingKey2).asBoolean().tstore(newValue);
    }

    function readAddressBytes32BoolMapping(TempStorageKey key, address mappingKey1, bytes32 mappingKey2) internal view returns (bool) {
        return TempStorageKey.unwrap(key).deriveMapping(mappingKey1).deriveMapping(mappingKey2).asBoolean().tload();
    }

}

using TempStorage for TempStorageKey global;
