//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { Solarray } from "solarray/Solarray.sol";

import { ISafeProxyFactory } from "../src/dependencies/safe/ISafeProxyFactory.sol";
import { ISafe7579Launchpad } from "../src/dependencies/safe/ISafe7579Launchpad.sol";
import { ISafe } from "../src/dependencies/safe/ISafe.sol";

import { INexusAccountFactory } from "../src/dependencies/nexus/INexusAccountFactory.sol";
import { INexusBootstrap } from "../src/dependencies/nexus/INexusBootstrap.sol";

contract AccountFactory {

    using Solarray for *;

    struct SafeContracts {
        address safeSingleton;
        address safeProxyFactory;
        address safe7579;
        address launchpad;
        address fallbackHandler;
    }

    struct NexusContracts {
        address nexusAccountFactory;
        address nexusBootstrap;
    }

    struct Modules {
        address ownableValidator;
        address ownableExecutor;
        address preSignedValidator;
        address erc1271Executor;
        address nftCallbackHandler;
    }

    struct ModuleInit {
        address module;
        bytes initData;
        uint256 moduleType;
    }

    enum WalletType {
        SAFE,
        NEXUS
    }

    event NewContangoAccount(address indexed account, address indexed owner, string name, WalletType indexed walletType);

    error AccountAddressMismatch(address account, address predictedAccount);

    address public immutable SAFE_SINGLETON;
    ISafeProxyFactory public immutable SAFE_PROXY_FACTORY;
    address public immutable SAFE_7579;
    address public immutable LAUNCHPAD;
    address public immutable FALLBACK_HANDLER;

    address public immutable OWNABLE_VALIDATOR;
    address public immutable OWNABLE_EXECUTOR;
    address public immutable PRE_SIGNED_VALIDATOR;
    address public immutable ERC1271_EXECUTOR;
    address public immutable NFT_CALLBACK_HANDLER;

    INexusAccountFactory public immutable NEXUS_ACCOUNT_FACTORY;
    INexusBootstrap public immutable NEXUS_BOOTSTRAP;

    constructor(Modules memory modules, SafeContracts memory safeContracts, NexusContracts memory nexusContracts) {
        OWNABLE_VALIDATOR = modules.ownableValidator;
        OWNABLE_EXECUTOR = modules.ownableExecutor;
        PRE_SIGNED_VALIDATOR = modules.preSignedValidator;
        ERC1271_EXECUTOR = modules.erc1271Executor;
        NFT_CALLBACK_HANDLER = modules.nftCallbackHandler;

        SAFE_SINGLETON = safeContracts.safeSingleton;
        SAFE_PROXY_FACTORY = ISafeProxyFactory(safeContracts.safeProxyFactory);
        SAFE_7579 = safeContracts.safe7579;
        LAUNCHPAD = safeContracts.launchpad;
        FALLBACK_HANDLER = safeContracts.fallbackHandler;

        NEXUS_ACCOUNT_FACTORY = INexusAccountFactory(nexusContracts.nexusAccountFactory);
        NEXUS_BOOTSTRAP = INexusBootstrap(nexusContracts.nexusBootstrap);
    }

    function newAccount(
        WalletType walletType,
        address owner,
        string calldata name,
        ModuleInit[] calldata modules,
        address expectedAccountAddress
    ) public returns (address accountAddress) {
        // Unconventional, but we wanna discover the account before we create it, so indexing is easier
        emit NewContangoAccount(expectedAccountAddress, owner, name, walletType);

        if (walletType == WalletType.SAFE) accountAddress = newSafeAccount(owner, name, modules);
        else if (walletType == WalletType.NEXUS) accountAddress = newNexusAccount(name, modules);

        require(accountAddress == expectedAccountAddress, AccountAddressMismatch(accountAddress, expectedAccountAddress));
    }

    function newSafeAccount(address owner, string calldata name, ModuleInit[] calldata modules) private returns (address) {
        return SAFE_PROXY_FACTORY.createProxyWithNonce(SAFE_SINGLETON, safeInitialiserData(owner, modules), _salt(name));
    }

    function newNexusAccount(string calldata name, ModuleInit[] calldata modules) private returns (address) {
        return NEXUS_ACCOUNT_FACTORY.createAccount(nexusInitialiserData(modules), keccak256(abi.encodePacked(name)));
    }

    function predictAccountAddress(WalletType walletType, address owner, string calldata name, ModuleInit[] calldata modules)
        public
        view
        returns (address)
    {
        if (walletType == WalletType.SAFE) return predictSafeAddress(owner, name, modules);
        else return predictNexusAddress(name, modules);
    }

    function predictSafeAddress(address owner, string calldata name, ModuleInit[] calldata modules) public view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            SAFE_PROXY_FACTORY,
                            keccak256(abi.encodePacked(keccak256(safeInitialiserData(owner, modules)), _salt(name))),
                            keccak256(abi.encodePacked(SAFE_PROXY_FACTORY.proxyCreationCode(), uint256(uint160(SAFE_SINGLETON))))
                        )
                    )
                )
            )
        );
    }

    function predictNexusAddress(string calldata name, ModuleInit[] calldata modules) public view returns (address) {
        return NEXUS_ACCOUNT_FACTORY.computeAccountAddress(nexusInitialiserData(modules), keccak256(abi.encodePacked(name)));
    }

    function safeInitialiserData(address owner, ModuleInit[] calldata modules) public view returns (bytes memory) {
        bytes memory launchpadCalldata =
            abi.encodeWithSelector(ISafe7579Launchpad.addSafe7579.selector, SAFE_7579, modules, new address[](0), 0);
        return abi.encodeCall(
            ISafe.setup, (owner.addresses(), 1, LAUNCHPAD, launchpadCalldata, FALLBACK_HANDLER, address(0), 0, payable(address(0)))
        );
    }

    function nexusInitialiserData(ModuleInit[] calldata modules) public view returns (bytes memory) {
        uint256 validatorsCount;
        uint256 executorsCount;
        uint256 fallbacksCount;
        uint256 hooksCount;

        for (uint256 i = 0; i < modules.length; i++) {
            if (modules[i].moduleType == MODULE_TYPE_VALIDATOR) validatorsCount++;
            else if (modules[i].moduleType == MODULE_TYPE_EXECUTOR) executorsCount++;
            else if (modules[i].moduleType == MODULE_TYPE_FALLBACK) fallbacksCount++;
            else if (modules[i].moduleType == MODULE_TYPE_HOOK) hooksCount++;
        }

        if (hooksCount > 1) revert("Only one hook allowed on Nexus");

        INexusBootstrap.BootstrapConfig[] memory validators = new INexusBootstrap.BootstrapConfig[](validatorsCount);
        INexusBootstrap.BootstrapConfig[] memory executors = new INexusBootstrap.BootstrapConfig[](executorsCount);
        INexusBootstrap.BootstrapConfig[] memory fallbacks = new INexusBootstrap.BootstrapConfig[](fallbacksCount);
        INexusBootstrap.BootstrapConfig memory hook;
        INexusBootstrap.BootstrapPreValidationHookConfig[] memory preValidationHooks;

        validatorsCount = executorsCount = fallbacksCount = hooksCount = 0;

        for (uint256 i = 0; i < modules.length; i++) {
            if (modules[i].moduleType == MODULE_TYPE_VALIDATOR) {
                validators[validatorsCount++] = INexusBootstrap.BootstrapConfig(modules[i].module, modules[i].initData);
            } else if (modules[i].moduleType == MODULE_TYPE_EXECUTOR) {
                executors[executorsCount++] = INexusBootstrap.BootstrapConfig(modules[i].module, modules[i].initData);
            } else if (modules[i].moduleType == MODULE_TYPE_FALLBACK) {
                fallbacks[fallbacksCount++] = INexusBootstrap.BootstrapConfig(modules[i].module, modules[i].initData);
            } else if (modules[i].moduleType == MODULE_TYPE_HOOK) {
                hook = INexusBootstrap.BootstrapConfig(modules[i].module, modules[i].initData);
            }
        }

        return abi.encode(
            NEXUS_BOOTSTRAP,
            abi.encodeCall(INexusBootstrap.initNexusNoRegistry, (validators, executors, hook, fallbacks, preValidationHooks))
        );
    }

    function _salt(string calldata name) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(name)));
    }

}
