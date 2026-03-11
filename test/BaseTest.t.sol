//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Solarray } from "solarray/Solarray.sol";
import { console } from "forge-std/console.sol";

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Packing } from "@openzeppelin/contracts/utils/Packing.sol";
import {
    IERC7579Execution,
    IERC7579ModuleConfig,
    IERC7579Module,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC7579Utils } from "@openzeppelin/contracts/account/utils/draft-ERC7579Utils.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

import { PermitSigner } from "./PermitUtils.t.sol";
import { OracleUtils } from "./OracleUtils.t.sol";
import { SpotMarket } from "./SpotMarket.sol";
import { PortoAccount, PortoAccountWithPk } from "./dependencies/Porto.sol";

import { Enum } from "../src/dependencies/safe/Enum.sol";
import { IMultiSend } from "../src/dependencies/safe/IMultiSend.sol";
import { IWETH9 } from "../src/dependencies/IWETH9.sol";
import { ActionExecutor } from "../src/modules/ActionExecutor.sol";
import { FlashLoanAction } from "../src/flashloan/FlashLoanAction.sol";
import { TokenAction } from "../src/actions/TokenAction.sol";
import { SwapAction } from "../src/actions/SwapAction.sol";
import { PreSignedValidator } from "../src/modules/PreSignedValidator.sol";
import { Action, PackedAction } from "../src/types/Action.sol";
import { ActionLib } from "./ActionLib.sol";

import { OwnableExecutor } from "../src/modules/OwnableExecutor.sol";
import { ERC1271Executor } from "../src/modules/ERC1271Executor.sol";
import { NFTCallbackHandler } from "../src/modules/NFTCallbackHandler.sol";

import { AccountFactory } from "./AccountFactory.sol";

contract BaseTest is Test, PermitSigner, OracleUtils {

    using Solarray for *;
    using Packing for *;
    using MessageHashUtils for *;
    using ActionLib for *;

    AccountFactory internal accountFactory;

    SpotMarket internal spotMarket;

    AccessManager internal authority;
    ActionExecutor internal actionExecutor;

    SwapAction internal swapAction;
    TokenAction internal tokenAction;
    FlashLoanAction internal flashLoanAction;

    address private safeSingleton = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
    address private safeProxyFactory = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address private fallbackHandler = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;
    address private safe7579 = 0x7579f2AD53b01c3D8779Fe17928e0D48885B0003;
    address private launchpad = 0x75798463024Bda64D83c94A64Bc7D7eaB41300eF;

    address internal ownableValidator = 0x2483DA3A338895199E5e538530213157e931Bf06;

    address internal portoAccount = 0xa928ab21caB2366d5E0EF73C68F85A6DC7D0cb9e;

    address internal nexusAccountFactory = 0x0000000000679A258c64d2F20F310e12B64b7375;
    address internal nexusBootstrap = 0x00000000006eFb61D8c9546FF1B500de3f244EA7;

    OwnableExecutor internal ownableExecutor;
    ERC1271Executor internal erc1271Executor;
    PreSignedValidator internal preSignedValidator;
    NFTCallbackHandler internal nftCallbackHandler;

    mapping(uint256 => uint256) internal safeNonce;
    mapping(uint256 => uint256) internal erc1271Nonce;
    uint256 internal spread = 0; // make this 0.001e18; // 0.1%

    function setUp() public virtual {
        setUp(IWETH9(address(0)));
    }

    function setUp(IWETH9 nativeToken) internal virtual {
        authority = new AccessManager(address(this));
        spotMarket = new SpotMarket(spread);

        actionExecutor = new ActionExecutor{ salt: "test" }();
        swapAction = new SwapAction{ salt: "test" }();
        tokenAction = new TokenAction{ salt: "test" }(nativeToken);
        flashLoanAction = new FlashLoanAction{ salt: "test" }();

        preSignedValidator = new PreSignedValidator{ salt: "test" }();
        ownableExecutor = new OwnableExecutor{ salt: "test" }(actionExecutor);
        erc1271Executor = new ERC1271Executor{ salt: "test" }(actionExecutor);
        nftCallbackHandler = new NFTCallbackHandler{ salt: "test" }();

        accountFactory = new AccountFactory(
            AccountFactory.Modules(
                ownableValidator,
                address(ownableExecutor),
                address(preSignedValidator),
                address(erc1271Executor),
                address(nftCallbackHandler)
            ),
            AccountFactory.SafeContracts(safeSingleton, safeProxyFactory, safe7579, launchpad, fallbackHandler),
            AccountFactory.NexusContracts(nexusAccountFactory, nexusBootstrap)
        );
    }

    function walletType() internal view returns (AccountFactory.WalletType) {
        string memory _walletType = vm.envOr("WALLET_TYPE", string("SAFE"));
        if (keccak256(abi.encodePacked(_walletType)) == keccak256(abi.encodePacked("SAFE"))) return AccountFactory.WalletType.SAFE;
        else if (keccak256(abi.encodePacked(_walletType)) == keccak256(abi.encodePacked("NEXUS"))) return AccountFactory.WalletType.NEXUS;

        revert("Invalid wallet type");
    }

    function predictAccountAddress(address owner, string memory name) internal view returns (address) {
        return accountFactory.predictSafeAddress(owner, name, modules(owner));
    }

    function newPortoAccount(string memory name) public returns (PortoAccountWithPk memory) {
        (address accountAddress, uint256 pk) = makeAddrAndKey(name);
        vm.signAndAttachDelegation(portoAccount, pk);
        return PortoAccountWithPk(PortoAccount(payable(accountAddress)), accountAddress, pk);
    }

    function newAccount(address owner) public returns (address accountAddress) {
        return newAccount(owner, "Account");
    }

    function newAccount(address owner, string memory name) public returns (address accountAddress) {
        AccountFactory.ModuleInit[] memory _modules = modules(owner);
        AccountFactory.WalletType _walletType = walletType();
        address predictedAccountAddress = accountFactory.predictAccountAddress(_walletType, owner, name, _modules);
        accountAddress = accountFactory.newAccount(_walletType, owner, name, _modules, predictedAccountAddress);

        vm.label(accountAddress, name);
        // console.log("%s: %s", name, accountAddress);
    }

    function modules(address owner) internal view returns (AccountFactory.ModuleInit[] memory _modules) {
        _modules = new AccountFactory.ModuleInit[](5);

        _modules[0] = AccountFactory.ModuleInit({
            module: ownableValidator, initData: abi.encode(1, owner.addresses()), moduleType: MODULE_TYPE_VALIDATOR
        });
        _modules[1] = AccountFactory.ModuleInit({ module: address(preSignedValidator), initData: "", moduleType: MODULE_TYPE_VALIDATOR });
        _modules[2] = AccountFactory.ModuleInit({
            module: address(ownableExecutor), initData: abi.encodePacked(owner), moduleType: MODULE_TYPE_EXECUTOR
        });
        _modules[3] = AccountFactory.ModuleInit({ module: address(erc1271Executor), initData: "", moduleType: MODULE_TYPE_EXECUTOR });
        _modules[4] = AccountFactory.ModuleInit({
            module: address(nftCallbackHandler),
            initData: abi.encode(IERC721Receiver.onERC721Received.selector, ERC7579Utils.CALLTYPE_SINGLE, ""),
            moduleType: MODULE_TYPE_FALLBACK
        });
    }

    function delegate(address account, address owner, address target, bytes memory data) public {
        vm.prank(owner);
        ownableExecutor.delegate(IERC7579Execution(account), target, data);
    }

    function _executeActions(address account, address owner, Action[] memory actions) public {
        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function _executeAction(address account, address owner, Action memory action) public {
        vm.prank(owner);
        ownableExecutor.executeAction(IERC7579Execution(account), action.pack());
    }

    function encodeDelegate(address account, uint256 ownerPk, address target, bytes memory data) public returns (address, bytes memory) {
        bytes memory accountData = abi.encodePacked(target, data);
        uint256 nonce = erc1271Nonce[block.chainid]++;
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        return (
            address(erc1271Executor), abi.encodeCall(ERC1271Executor.delegate, (IERC7579Execution(account), target, data, signature, nonce))
        );
    }

    function _encodeActions(address account, uint256 ownerPk, Action[] memory actions) public returns (address, bytes memory) {
        PackedAction[] memory packedActions = actions.pack();
        bytes memory accountData = abi.encode(packedActions);
        uint256 nonce = erc1271Nonce[block.chainid]++;
        bytes32 hash = erc1271Executor.digest(IERC7579Execution(account), accountData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, hash.toEthSignedMessageHash());
        bytes memory signature = abi.encodePacked(ownableValidator, r, s, v);

        return (
            address(erc1271Executor),
            abi.encodeCall(ERC1271Executor.executeActions, (IERC7579Execution(account), packedActions, signature, nonce))
        );
    }

    function installModule(address account, address owner, address module, bytes memory data) public {
        for (uint256 i = 1; i < 5; i++) {
            if (IERC7579Module(module).isModuleType(i)) {
                if (i == MODULE_TYPE_HOOK) data = abi.encode(0, 0, data);

                if (IERC7579ModuleConfig(account).isModuleInstalled(i, module, data)) continue;

                installModule(account, owner, i, module, data);
            }
        }
    }

    function installModule(address account, address owner, uint256 moduleType, address module, bytes memory data) public {
        vm.prank(owner);
        ownableExecutor.execute(
            IERC7579Execution(account), account, abi.encodeCall(IERC7579ModuleConfig.installModule, (moduleType, module, data))
        );
    }

    function uninstallModule(address account, address owner, uint256 moduleType, address module, bytes memory data) public {
        vm.prank(owner);
        ownableExecutor.execute(
            IERC7579Execution(account), account, abi.encodeCall(IERC7579ModuleConfig.uninstallModule, (moduleType, module, data))
        );
    }

    function skipWithBlock(uint256 time) internal {
        skip(time);
        vm.roll(block.number + time / 12);
    }

}

function searchAndReplace(bytes memory data, bytes20 target, bytes20 replacement) pure returns (bytes memory) {
    require(data.length >= 20, "Data length is too short.");

    // Iterate through the data to find the target bytes20
    for (uint256 i = 0; i <= data.length - 20; i++) {
        bool isMatch = true;

        // Check each byte for a match
        for (uint256 j = 0; j < 20; j++) {
            if (data[i + j] != target[j]) {
                isMatch = false;
                break;
            }
        }

        // If a match is found, replace the bytes
        if (isMatch) {
            for (uint256 j = 0; j < 20; j++) {
                data[i + j] = replacement[j];
            }
            // If you want to replace only the first occurrence, uncomment the next line
            // break;
        }
    }

    return data;
}
