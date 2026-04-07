//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC7579Module } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

abstract contract ERC7579Module is IERC7579Module {

    event ModuleInstalled(address indexed account, bytes data);
    event ModuleUninstalled(address indexed account, bytes data);
    error ModuleAlreadyInstalled();
    error ModuleNotInstalled();

    mapping(address account => bool installed) private _installed;

    /**
     * @notice Initializes the module for a given account.
     * @dev Reverts when already installed for `msg.sender`.
     * @param data Optional initialization data.
     */
    function onInstall(bytes calldata data) external virtual override {
        require(!_isInstalled(msg.sender), ModuleAlreadyInstalled());
        _setInstalled(msg.sender, true);
        emit ModuleInstalled(msg.sender, data);
    }

    /**
     * @notice Uninstalls the module for a given account.
     * @dev Reverts when not installed for `msg.sender`.
     * @param data Optional uninstallation data.
     */
    function onUninstall(bytes calldata data) external virtual override {
        require(_isInstalled(msg.sender), ModuleNotInstalled());
        _setInstalled(msg.sender, false);
        emit ModuleUninstalled(msg.sender, data);
    }

    function _isInstalled(address account) internal view virtual returns (bool) {
        return _installed[account];
    }

    function _setInstalled(address account, bool installed) internal virtual {
        _installed[account] = installed;
    }

}
