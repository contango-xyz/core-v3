// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ISafe7579 {

    type CallType is bytes1;
    type ExecType is bytes1;
    type ModeCode is bytes32;

    struct EmergencyUninstall {
        address hook;
        uint256 hookType;
        bytes deInitData;
        uint256 nonce;
    }

    struct ModuleInit {
        address module;
        bytes initData;
        uint256 moduleType;
    }

    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes32 gasFees;
        bytes paymasterAndData;
        bytes signature;
    }

    struct RegistryInit {
        address registry;
        address[] attesters;
        uint8 threshold;
    }

    error AccountAccessUnauthorized();
    error EmergencyTimeLockNotExpired();
    error EmergencyUninstallSigError();
    error ExecutionFailed();
    error FallbackInstalled(bytes4 msgSig);
    error HookAlreadyInstalled(address currentHook);
    error InvalidCallType(CallType callType);
    error InvalidFallbackHandler(bytes4 msgSig);
    error InvalidHookType();
    error InvalidInitData(address safe);
    error InvalidInput();
    error InvalidModule(address module);
    error InvalidModuleType(address module, uint256 moduleType);
    error InvalidNonce();
    error LinkedList_AlreadyInitialized();
    error LinkedList_EntryAlreadyInList(address entry);
    error LinkedList_InvalidEntry(address entry);
    error LinkedList_InvalidPage();
    error ModuleNotInstalled(address module, uint256 moduleType);
    error NoFallbackHandler(bytes4 msgSig);
    error PreValidationHookAlreadyInstalled(address currentHook, uint256 moduleType);
    error UnsupportedCallType(CallType callType);
    error UnsupportedExecType(ExecType execType);
    error UnsupportedModuleType(uint256 moduleTypeId);

    event ERC7484RegistryConfigured(address indexed smartAccount, address indexed registry);
    event EmergencyHookUninstallRequest(address hook, uint256 time);
    event EmergencyHookUninstallRequestReset(address hook, uint256 time);
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);
    event Safe7579Initialized(address indexed safe);
    event TryExecutionFailed(address safe, uint256 numberInBatch);
    event TryExecutionsFailed(address safe, bool[] success);

    fallback() external payable;

    receive() external payable;

    function accountId() external pure returns (string memory accountImplementationId);
    function domainSeparator() external view returns (bytes32);
    function emergencyUninstallHook(EmergencyUninstall memory data, bytes memory signature) external;
    function entryPoint() external view returns (address);
    function execute(ModeCode mode, bytes memory executionCalldata) external;
    function executeFromExecutor(ModeCode mode, bytes memory executionCalldata) external returns (bytes[] memory returnDatas);
    function getActiveHook() external view returns (address hook);
    function getExecutorsPaginated(address cursor, uint256 pageSize) external view returns (address[] memory array, address next);
    function getFallbackHandlerBySelector(bytes4 selector) external view returns (CallType, address);
    function getNonce(address safe, address validator) external view returns (uint256 nonce);
    function getPrevalidationHook(uint256 moduleType) external view returns (address hook);
    function getSafeOp(PackedUserOperation memory userOp, address entryPoint)
        external
        view
        returns (bytes memory operationData, uint48 validAfter, uint48 validUntil, bytes memory signatures);
    function getValidatorsPaginated(address cursor, uint256 pageSize) external view returns (address[] memory array, address next);
    function initializeAccount(ModuleInit[] memory modules, RegistryInit memory registryInit) external;
    function initializeAccountWithValidators(ModuleInit[] memory validators) external;
    function installModule(uint256 moduleType, address module, bytes memory initData) external;
    function isModuleInstalled(uint256 moduleType, address module, bytes memory additionalContext) external view returns (bool);
    function isValidSignature(bytes32 hash, bytes memory data) external view returns (bytes4 magicValue);
    function setRegistry(address registry, address[] memory attesters, uint8 threshold) external;
    function supportsExecutionMode(ModeCode encodedMode) external pure returns (bool supported);
    function supportsModule(uint256 moduleTypeId) external pure returns (bool);
    function uninstallModule(uint256 moduleType, address module, bytes memory deInitData) external;
    function validateUserOp(PackedUserOperation memory userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validSignature);

}
