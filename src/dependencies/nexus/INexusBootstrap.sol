// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IERC7484 } from "../IERC7484.sol";

interface INexusBootstrap {

    type CallType is bytes1;

    struct BootstrapConfig {
        address module;
        bytes data;
    }

    error CanNotRemoveLastValidator();
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
    error LinkedList_EntryAlreadyInList(address entry);
    error LinkedList_InvalidEntry(address entry);
    error LinkedList_InvalidPage();
    error MismatchModuleTypeId(uint256 moduleTypeId);
    error MissingFallbackHandler(bytes4 selector);
    error ModuleAddressCanNotBeZero();
    error ModuleAlreadyInstalled(uint256 moduleTypeId, address module);
    error ModuleNotInstalled(uint256 moduleTypeId, address module);
    error NoValidatorInstalled();
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
    function getInitNexusCalldata(
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        IERC7484 registry,
        address[] memory attesters,
        uint8 threshold
    ) external view returns (bytes memory init);
    function getInitNexusScopedCalldata(
        BootstrapConfig[] memory validators,
        BootstrapConfig memory hook,
        address registry,
        address[] memory attesters,
        uint8 threshold
    ) external view returns (bytes memory init);
    function getInitNexusWithSingleValidatorCalldata(
        BootstrapConfig memory validator,
        address registry,
        address[] memory attesters,
        uint8 threshold
    ) external view returns (bytes memory init);
    function getValidatorsPaginated(address cursor, uint256 size) external view returns (address[] memory array, address next);
    function initNexus(
        BootstrapConfig[] memory validators,
        BootstrapConfig[] memory executors,
        BootstrapConfig memory hook,
        BootstrapConfig[] memory fallbacks,
        IERC7484 registry,
        address[] memory attesters,
        uint8 threshold
    ) external;
    function initNexusScoped(
        BootstrapConfig[] memory validators,
        BootstrapConfig memory hook,
        IERC7484 registry,
        address[] memory attesters,
        uint8 threshold
    ) external;
    function initNexusWithSingleValidator(
        address validator,
        bytes memory data,
        IERC7484 registry,
        address[] memory attesters,
        uint8 threshold
    ) external;
    function registry() external view returns (address);

}
