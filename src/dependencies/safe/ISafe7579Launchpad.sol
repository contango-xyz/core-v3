// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ISafe7579Launchpad {

    type ModeCode is bytes32;

    struct InitData {
        address singleton;
        address[] owners;
        uint256 threshold;
        address setupTo;
        bytes setupData;
        address safe7579;
        ModuleInit[] validators;
        bytes callData;
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

    error InvalidEntryPoint();
    error InvalidInitHash();
    error InvalidSetup();
    error InvalidSignature();
    error InvalidUserOperationData();
    error OnlyDelegatecall();
    error OnlyProxy();
    error PreValidationSetupFailed();
    error Safe7579LaunchpadAlreadyInitialized();

    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    function REGISTRY() external view returns (address);
    function SUPPORTED_ENTRYPOINT() external view returns (address);
    function accountId() external pure returns (string memory accountImplementationId);
    function addSafe7579(address safe7579, ModuleInit[] memory modules, address[] memory attesters, uint8 threshold) external;
    function domainSeparator() external view returns (bytes32);
    function getInitHash() external view returns (bytes32 value);
    function getSafeOp(PackedUserOperation memory userOp, address entryPoint)
        external
        view
        returns (bytes memory operationData, uint48 validAfter, uint48 validUntil, bytes memory signatures);
    function hash(InitData memory data) external pure returns (bytes32);
    function initSafe7579(address safe7579, ModuleInit[] memory modules, address[] memory attesters, uint8 threshold) external;
    function preValidationSetup(bytes32 initHash, address to, bytes memory preInit) external;
    function predictSafeAddress(
        address singleton,
        address safeProxyFactory,
        bytes memory creationCode,
        bytes32 salt,
        bytes memory factoryInitializer
    ) external pure returns (address safeProxy);
    function setupSafe(InitData memory initData) external;
    function supportsExecutionMode(ModeCode encodedMode) external pure returns (bool supported);
    function supportsModule(uint256 moduleTypeId) external pure returns (bool);
    function validateUserOp(PackedUserOperation memory userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData);

}
