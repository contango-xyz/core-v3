//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MODULE_TYPE_FALLBACK } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

import { ERC7579Module } from "./base/ERC7579Module.sol";
import { BytesLib } from "../libraries/BytesLib.sol";

contract NFTCallbackHandler is ERC7579Module, IERC721Receiver, IERC1155Receiver {

    using BytesLib for bytes;

    function onERC721Received(address, address, uint256, bytes calldata data) external override returns (bytes4) {
        _handleNftCallback(data);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata data) external override returns (bytes4) {
        _handleNftCallback(data);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        _handleNftCallback(data);
        return this.onERC1155BatchReceived.selector;
    }

    function _handleNftCallback(bytes calldata data) internal {
        if (data.length >= 24) data.functionCall();
    }

    function isModuleType(uint256 moduleTypeId) public pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_FALLBACK;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId;
    }

}
