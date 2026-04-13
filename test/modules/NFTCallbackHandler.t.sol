//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { MODULE_TYPE_FALLBACK } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

import { NFTCallbackHandler } from "../../src/modules/NFTCallbackHandler.sol";

contract NFTCallbackHandlerTest is Test {

    NFTCallbackHandler internal nftCallbackHandler;

    function setUp() public {
        nftCallbackHandler = new NFTCallbackHandler();
    }

    function test_ModuleType_ReturnsTrueForFallback() public view {
        assertTrue(nftCallbackHandler.isModuleType(MODULE_TYPE_FALLBACK));
    }

    function test_ModuleType_ReturnsFalseForUnsupportedType() public view {
        assertFalse(nftCallbackHandler.isModuleType(type(uint256).max));
    }

    function test_SupportsInterface_ReturnsTrueForIERC165() public view {
        assertTrue(nftCallbackHandler.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterface_ReturnsTrueForIERC721Receiver() public view {
        assertTrue(nftCallbackHandler.supportsInterface(type(IERC721Receiver).interfaceId));
    }

    function test_SupportsInterface_ReturnsTrueForIERC1155Receiver() public view {
        assertTrue(nftCallbackHandler.supportsInterface(type(IERC1155Receiver).interfaceId));
    }

    function test_SupportsInterface_ReturnsFalseForUnsupportedInterface() public view {
        assertFalse(nftCallbackHandler.supportsInterface(0xffffffff));
    }

}
