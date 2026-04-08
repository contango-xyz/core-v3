//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "../BaseTest.t.sol";
import { Vm } from "forge-std/Vm.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";

contract PreSignedValidatorTest is BaseTest {

    function test_ApproveHash_DuplicatePermanentNoop() public {
        bytes32 hash = keccak256("hash-permanent-approve");
        assertTrue(preSignedValidator.approveHash(hash, true));

        vm.recordLogs();
        assertFalse(preSignedValidator.approveHash(hash, true));

        bytes32 hashSignedSig = keccak256("HashSigned(address,bytes32)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(entries[i].topics[0] != hashSignedSig, "unexpected HashSigned");
        }
        assertTrue(preSignedValidator.isSigned(address(this), hash));
    }

    function test_RevokeHash_DuplicatePermanentNoop() public {
        bytes32 hash = keccak256("hash-permanent-revoke");
        assertTrue(preSignedValidator.approveHash(hash, true));
        assertTrue(preSignedValidator.revokeHash(hash, true));

        vm.recordLogs();
        assertFalse(preSignedValidator.revokeHash(hash, true));

        bytes32 hashRevokedSig = keccak256("HashRevoked(address,bytes32)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(entries[i].topics[0] != hashRevokedSig, "unexpected HashRevoked");
        }
        assertFalse(preSignedValidator.isSigned(address(this), hash));
    }

    function test_ApproveHash_DuplicateTransientNoop() public {
        bytes32 hash = keccak256("hash-transient-approve");
        assertTrue(preSignedValidator.approveHash(hash, false));

        vm.recordLogs();
        assertFalse(preSignedValidator.approveHash(hash, false));

        bytes32 hashSignedSig = keccak256("HashSigned(address,bytes32)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(entries[i].topics[0] != hashSignedSig, "unexpected HashSigned");
        }
        assertTrue(preSignedValidator.isSigned(address(this), hash));
    }

    function test_RevokeHash_DuplicateTransientNoop() public {
        bytes32 hash = keccak256("hash-transient-revoke");
        assertTrue(preSignedValidator.approveHash(hash, false));
        assertTrue(preSignedValidator.revokeHash(hash, false));

        vm.recordLogs();
        assertFalse(preSignedValidator.revokeHash(hash, false));

        bytes32 hashRevokedSig = keccak256("HashRevoked(address,bytes32)");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            assertTrue(entries[i].topics[0] != hashRevokedSig, "unexpected HashRevoked");
        }
        assertFalse(preSignedValidator.isSigned(address(this), hash));
    }

}
