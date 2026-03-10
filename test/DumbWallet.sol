//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract DumbWallet {

    using Address for address;

    function delegate(address target, bytes calldata data) external payable returns (bytes memory) {
        return target.functionDelegateCall(data);
    }

    receive() external payable { }

}
