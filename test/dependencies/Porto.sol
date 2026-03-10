// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { Vm } from "forge-std/Vm.sol";

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

struct Call {
    address to;
    uint256 value;
    bytes data;
}

enum SpendPeriod {
    Minute,
    Hour,
    Day,
    Week,
    Month,
    Year,
    Forever
}

struct CallCheckerInfo {
    address target;
    address checker;
}

struct SpendInfo {
    address token;
    SpendPeriod period;
    uint256 limit;
    uint256 spent;
    uint256 lastUpdated;
    uint256 currentSpent;
    uint256 current;
}

enum KeyType {
    P256,
    WebAuthnP256,
    Secp256k1,
    External
}

struct Key {
    uint40 expiry;
    KeyType keyType;
    bool isSuperAdmin;
    bytes publicKey;
}

interface PortoAccount {

    error BatchOfBatchesDecodingError();
    error CannotSelfExecute();
    error ExceededSpendLimit(address token);
    error ExceedsCapacity();
    error FnSelectorNotRecognized();
    error IndexOutOfBounds();
    error InvalidNonce();
    error InvalidPublicKey();
    error KeyDoesNotExist();
    error KeyHashIsZero();
    error KeyTypeCannotBeSuperAdmin();
    error NewImplementationIsZero();
    error NewSequenceMustBeLarger();
    error NoSpendPermissions();
    error OpDataError();
    error PaymasterNonceError();
    error SuperAdminCanExecuteEverything();
    error SuperAdminCanSpendAnything();
    error Unauthorized();
    error UnauthorizedCall(bytes32 keyHash, address target, bytes data);
    error UnsupportedExecutionMode();

    event Authorized(bytes32 indexed keyHash, Key key);
    event CallCheckerSet(bytes32 keyHash, address target, address checker);
    event CanExecuteSet(bytes32 keyHash, address target, bytes4 fnSel, bool can);
    event ImplementationApprovalSet(address indexed implementation, bool isApproved);
    event ImplementationCallerApprovalSet(address indexed implementation, address indexed caller, bool isApproved);
    event LabelSet(string newLabel);
    event NonceInvalidated(uint256 nonce);
    event Revoked(bytes32 indexed keyHash);
    event SignatureCheckerApprovalSet(bytes32 indexed keyHash, address indexed checker, bool isApproved);
    event SpendLimitRemoved(bytes32 keyHash, address token, SpendPeriod period);
    event SpendLimitSet(bytes32 keyHash, address token, SpendPeriod period, uint256 limit);

    fallback() external payable;

    receive() external payable;

    function ANY_FN_SEL() external view returns (bytes4);
    function ANY_KEYHASH() external view returns (bytes32);
    function ANY_TARGET() external view returns (address);
    function CALL_TYPEHASH() external view returns (bytes32);
    function DOMAIN_TYPEHASH() external view returns (bytes32);
    function EMPTY_CALLDATA_FN_SEL() external view returns (bytes4);
    function EXECUTE_TYPEHASH() external view returns (bytes32);
    function MULTICHAIN_NONCE_PREFIX() external view returns (uint16);
    function ORCHESTRATOR() external view returns (address);
    function SIGN_TYPEHASH() external view returns (bytes32);
    function approvedSignatureCheckers(bytes32 keyHash) external view returns (address[] memory);
    function authorize(Key memory key) external returns (bytes32 keyHash);
    function callCheckerInfos(bytes32 keyHash) external view returns (CallCheckerInfo[] memory results);
    function canExecute(bytes32 keyHash, address target, bytes memory data) external view returns (bool);
    function canExecutePackedInfos(bytes32 keyHash) external view returns (bytes32[] memory);
    function checkAndIncrementNonce(uint256 nonce) external payable;
    function computeDigest(Call[] memory calls, uint256 nonce) external view returns (bytes32 result);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function execute(bytes32 mode, bytes memory executionData) external payable;
    function getContextKeyHash() external view returns (bytes32);
    function getKey(bytes32 keyHash) external view returns (Key memory key);
    function getKeys() external view returns (Key[] memory keys, bytes32[] memory keyHashes);
    function getNonce(uint192 seqKey) external view returns (uint256);
    function hash(Key memory key) external pure returns (bytes32);
    function invalidateNonce(uint256 nonce) external;
    function isValidSignature(bytes32 digest, bytes memory signature) external view returns (bytes4);
    function keyAt(uint256 i) external view returns (Key memory);
    function keyCount() external view returns (uint256);
    function label() external view returns (string memory);
    function pay(uint256 paymentAmount, bytes32 keyHash, bytes32 intentDigest, bytes memory encodedIntent) external;
    function removeSpendLimit(bytes32 keyHash, address token, SpendPeriod period) external;
    function revoke(bytes32 keyHash) external;
    function setCallChecker(bytes32 keyHash, address target, address checker) external;
    function setCanExecute(bytes32 keyHash, address target, bytes4 fnSel, bool can) external;
    function setLabel(string memory newLabel) external;
    function setSignatureCheckerApproval(bytes32 keyHash, address checker, bool isApproved) external;
    function setSpendLimit(bytes32 keyHash, address token, SpendPeriod period, uint256 limit) external;
    function spendAndExecuteInfos(bytes32[] memory keyHashes)
        external
        view
        returns (SpendInfo[][] memory spends, bytes32[][] memory executes);
    function spendInfos(bytes32 keyHash) external view returns (SpendInfo[] memory results);
    function startOfSpendPeriod(uint256 unixTimestamp, SpendPeriod period) external pure returns (uint256);
    function supportsExecutionMode(bytes32 mode) external view returns (bool result);
    function unwrapAndValidateSignature(bytes32 digest, bytes memory signature) external view returns (bool isValid, bytes32 keyHash);
    function upgradeHook(bytes32 previousVersion) external returns (bool);
    function upgradeProxyAccount(address newImplementation) external;

}

struct PortoAccountWithPk {
    PortoAccount account;
    address addr;
    uint256 pk;
}

library PortoUtil {

    using MessageHashUtils for bytes32;

    Vm constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address constant RELAYER = address(0x123);
    bytes32 constant ERC7821_BATCH_EXECUTION_MODE = hex"01000000000078210001";
    bytes32 constant EIP712_DOMAIN = keccak256("EIP712Domain(address verifyingContract)");

    function execute(PortoAccountWithPk memory accountWithPk, address to, bytes memory data) public {
        Call[] memory calls = new Call[](1);
        calls[0].to = to;
        calls[0].data = data;

        PortoAccount account = accountWithPk.account;
        uint256 pk = accountWithPk.pk;

        uint256 nonce = account.getNonce(0);
        bytes32 digest = account.computeDigest(calls, nonce);
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(pk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory opData = abi.encodePacked(nonce, signature);
        bytes memory executionData = abi.encode(calls, opData);

        VM.prank(RELAYER);
        account.execute(ERC7821_BATCH_EXECUTION_MODE, executionData);
    }

    function sign(PortoAccountWithPk memory accountWithPk, bytes32 digest) public view returns (bytes memory signature) {
        PortoAccount account = accountWithPk.account;
        uint256 pk = accountWithPk.pk;

        bytes32 replaySafeDigest = keccak256(abi.encode(account.SIGN_TYPEHASH(), digest.toEthSignedMessageHash()));

        (,,,, address verifyingContract,,) = account.eip712Domain();
        bytes32 domain = keccak256(abi.encode(EIP712_DOMAIN, verifyingContract));
        replaySafeDigest = keccak256(abi.encodePacked("\x19\x01", domain, replaySafeDigest));

        (uint8 v, bytes32 r, bytes32 s) = VM.sign(pk, replaySafeDigest);
        signature = abi.encodePacked(r, s, v);
    }

}

using PortoUtil for PortoAccountWithPk global;
