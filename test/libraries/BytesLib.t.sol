//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { BytesLib } from "../../src/libraries/BytesLib.sol";

// Hack so we can capture the error
contract BytesLibWrapper {

    function set(bytes memory buffer, uint256 offset, bytes32 value) public pure returns (bytes memory) {
        return BytesLib.set(buffer, offset, value);
    }

}

contract BytesLibTest is Test {

    BytesLibWrapper wrapper;

    function setUp() public {
        wrapper = new BytesLibWrapper();
    }

    function test_set_underflow() public {
        bytes memory buffer = new bytes(10); // length 10
        vm.expectRevert(abi.encodeWithSelector(BytesLib.InvalidOffset.selector, 0, 10));
        wrapper.set(buffer, 0, bytes32(uint256(1)));
    }

}
