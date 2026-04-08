//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { ERC7579Module } from "../../src/modules/base/ERC7579Module.sol";

contract ERC7579ModuleTest is Test {

    MockModule internal module_;
    address internal account = makeAddr("account");

    function setUp() public {
        module_ = new MockModule();
    }

    function test_RevertWhen_InstallAlreadyInstalled() public {
        vm.prank(account);
        module_.onInstall("init");

        vm.expectRevert(ERC7579Module.ModuleAlreadyInstalled.selector);
        vm.prank(account);
        module_.onInstall("init");
    }

    function test_RevertWhen_UninstallNotInstalled() public {
        vm.expectRevert(ERC7579Module.ModuleNotInstalled.selector);
        vm.prank(account);
        module_.onUninstall("");
    }

    function test_InstallThenUninstallThenInstallAgain() public {
        vm.prank(account);
        module_.onInstall("init");

        vm.prank(account);
        module_.onUninstall("");

        vm.prank(account);
        module_.onInstall("reinstall");
    }

}

contract MockModule is ERC7579Module {

    function isModuleType(uint256) external pure override returns (bool) {
        return true;
    }

}
