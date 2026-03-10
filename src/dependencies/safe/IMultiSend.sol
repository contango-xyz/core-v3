// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMultiSend {

    function multiSend(bytes memory transactions) external payable;

}
