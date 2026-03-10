// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC7484 } from "../src/dependencies/IERC7484.sol";

contract ERC7484Mock {

    type ModuleType is uint256;

    function check(address module, address[] memory attesters, uint256 threshold) external view { }

    function check(address module, ModuleType moduleType, address[] memory attesters, uint256 threshold) external view { }

    function check(address module, ModuleType moduleType) external view { }

    function check(address module) external view { }

    function checkForAccount(address smartAccount, address module) external view { }

    function checkForAccount(address smartAccount, address module, ModuleType moduleType) external view { }

}
