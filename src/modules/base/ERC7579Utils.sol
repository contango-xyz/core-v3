// SPDX-License-Identifier: BSUL-1.1
pragma solidity ^0.8.0;

import { Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { CallType } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";

library ERC7579Lib {

    CallType constant CALLTYPE_STATIC = CallType.wrap(0xFE);

    function encodeSingle(address target, uint256 value, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(target, value, data);
    }

    function encodeDelegate(address target, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(target, data);
    }

    function encodeBatch(Execution[] memory calls) internal pure returns (bytes memory) {
        return abi.encode(calls);
    }

}
