//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { MODULE_TYPE_HOOK, IERC7579Hook } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

import { ERC7579Module } from "./ERC7579Module.sol";

abstract contract ERC7579Hook is ERC7579Module, IERC7579Hook {

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_HOOK;
    }

    function preCheck(address, uint256, bytes calldata) external virtual override returns (bytes memory) {
        return "";
    }

    function postCheck(bytes calldata) external virtual override { }

}
