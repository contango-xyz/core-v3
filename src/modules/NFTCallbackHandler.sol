//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MODULE_TYPE_FALLBACK } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

import { ERC7579Module } from "./base/ERC7579Module.sol";
import { BytesLib } from "../libraries/BytesLib.sol";

/// @custom:security-contact security@contango.xyz
contract NFTCallbackHandler is ERC7579Module, IERC721Receiver, IERC1155Receiver {

    using BytesLib for bytes;

    /**
     * @notice Handles ERC-721 token receipts.
     * @dev Automatically executes any function calls encoded in the `data` parameter.
     * @param data Optional callback data.
     */
    function onERC721Received(address, address, uint256, bytes calldata data) external override returns (bytes4) {
        _handleNftCallback(data);
        return this.onERC721Received.selector;
    }

    /**
     * @notice Handles ERC-1155 token receipts.
     * @dev Automatically executes any function calls encoded in the `data` parameter.
     * @param data Optional callback data.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata data) external override returns (bytes4) {
        _handleNftCallback(data);
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Handles ERC-1155 batch receipts.
     * @dev Automatically executes any function calls encoded in the `data` parameter.
     * @param data Optional callback data.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        _handleNftCallback(data);
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Internal handler for NFT callbacks.
     * @dev Executes any function call encoded in the `data` parameter if it's at least 24 bytes long.
     * @dev The data layout expected is [20 bytes target contract + X bytes calldata].
     * @dev This is inherently safe as it is validated by the account's executor.
     * @param data The data containing the optional callback.
     */
    function _handleNftCallback(bytes calldata data) internal {
        if (data.length >= 24) data.functionCall();
    }

    function isModuleType(uint256 moduleTypeId) public pure override returns (bool) {
        return moduleTypeId == MODULE_TYPE_FALLBACK;
    }

    /**
     * @notice Checks whether an interface is supported.
     * @param interfaceId The ERC-165 interface identifier.
     * @return True when the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155Receiver).interfaceId;
    }

}
