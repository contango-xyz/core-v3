// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface INexusBootstrap {

    type CallType is bytes1;

    struct BootstrapConfig {
        address module;
        bytes data;
    }

    struct BootstrapPreValidationHookConfig {
        uint256 hookType;
        address module;
        bytes data;
    }

    struct RegistryConfig {
        address registry;
        address[] attesters;
        uint8 threshold;
    }

    error CanNotRemoveLastValidator();
    error DefaultValidatorAlreadyInstalled();
    error EmergencyUninstallSigError();
    error EnableModeSigError();
    error FallbackAlreadyInstalledForSelector(bytes4 selector);
    error FallbackCallTypeInvalid();
    error FallbackHandlerUninstallFailed();
    error FallbackNotInstalledForSelector(bytes4 selector);
    error FallbackSelectorForbidden();
    error HookAlreadyInstalled(address currentHook);
    error HookPostCheckFailed();
    error InvalidInput();
    error InvalidModule(address module);
    error InvalidModuleTypeId(uint256 moduleTypeId);
    error InvalidNonce();
    error LinkedList_AlreadyInitialized();
    error LinkedList_EntryAlreadyInList(address entry);
    error LinkedList_InvalidEntry(address entry);
    error LinkedList_InvalidPage();
    error MismatchModuleTypeId();
    error MissingFallbackHandler(bytes4 selector);
    error ModuleAddressCanNotBeZero();
    error ModuleAlreadyInstalled(uint256 moduleTypeId, address module);
    error ModuleNotInstalled(uint256 moduleTypeId, address module);
    error NoValidatorInstalled();
    error PrevalidationHookAlreadyInstalled(address currentPreValidationHook);
    error UnauthorizedOperation(address operator);
    error UnsupportedCallType(CallType callType);
    error ValidatorNotInstalled(address module);

    event ERC7484RegistryConfigured(address indexed registry);
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

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
    function getActiveHook() external view returns (address hook);
    function getExecutorsPaginated(address cursor, uint256 size) external view returns (address[] memory array, address next);
    function getFallbackHandlerBySelector(bytes4 selector) external view returns (CallType, address);
    function getRegistry() external view returns (address);
    function getValidatorsPaginated(address cursor, uint256 size) external view returns (address[] memory array, address next);
    function initNexus(
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        BootstrapPreValidationHookConfig[] memory preValidationHooks,
        RegistryConfig memory registryConfig
    ) external payable;
    function initNexusNoRegistry(
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        BootstrapPreValidationHookConfig[] memory preValidationHooks
    ) external payable;
    function initNexusScoped(BootstrapConfig[] memory validators, BootstrapConfig memory hook, RegistryConfig memory registryConfig)
        external
        payable;
    function initNexusScopedNoRegistry(BootstrapConfig[] memory validators, BootstrapConfig memory hook) external payable;
    function initNexusWithDefaultValidator(bytes memory data) external payable;
    function initNexusWithDefaultValidatorAndOtherModules(
        bytes memory defaultValidatorInitData,
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        BootstrapPreValidationHookConfig[] memory preValidationHooks,
        RegistryConfig memory registryConfig
    ) external payable;
    function initNexusWithDefaultValidatorAndOtherModulesNoRegistry(
        bytes memory defaultValidatorInitData,
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        BootstrapPreValidationHookConfig[] memory preValidationHooks
    ) external payable;
    function initNexusWithSingleValidator(address validator, bytes memory data, RegistryConfig memory registryConfig) external payable;
    function initNexusWithSingleValidatorNoRegistry(address validator, bytes memory data) external payable;
    function installModule(uint256 moduleTypeId, address module, bytes memory initData) external payable;
    function isModuleInstalled(uint256 moduleTypeId, address module, bytes memory additionalContext) external view returns (bool installed);
    function uninstallModule(uint256 moduleTypeId, address module, bytes memory deInitData) external payable;

}
