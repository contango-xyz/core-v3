//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC7579Module } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

abstract contract ERC7579Module is IERC7579Module {

    event ModuleInstalled(address indexed account, bytes data);
    event ModuleUninstalled(address indexed account, bytes data);

    function onInstall(bytes calldata data) external virtual override {
        emit ModuleInstalled(msg.sender, data);
    }

    function onUninstall(bytes calldata data) external virtual override {
        emit ModuleUninstalled(msg.sender, data);
    }

}
