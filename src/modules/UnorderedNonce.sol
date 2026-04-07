//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract UnorderedNonce {

    // ================================ Taken from Permit2 ================================
    // https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol

    error InvalidNonce();

    /// @notice A map from token owner address and a caller specified word index to a bitmap. Used to set bits in the bitmap to prevent against signature replay protection
    /// @dev Uses unordered nonces so that permit messages do not need to be spent in a certain order
    /// @dev The mapping is indexed first by the token owner, then by an index specified in the nonce
    /// @dev It returns a uint256 bitmap
    /// @dev The index, or wordPosition is capped at type(uint248).max

    mapping(address account => mapping(uint256 wordPos => uint256 bitPos)) public nonceBitmap;

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces
    /// @param nonce The nonce to get the associated word and bit positions
    /// @return wordPos The word position or index into the nonceBitmap
    /// @return bitPos The bit position
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap
    /// @dev The last 8 bits of the nonce value is the position of the bit in the bitmap
    /**
     * @notice Returns the index of the bitmap and the bit position within the bitmap for a given nonce.
     * @param nonce The nonce to get the associated word and bit positions.
     * @return wordPos The word position or index into the nonceBitmap.
     * @return bitPos The bit position.
     */
    function bitmapPositions(uint256 nonce) private pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = nonce >> 8;
        bitPos = nonce & type(uint8).max;
    }

    /// @notice Checks whether a nonce is taken and sets the bit at the bit position in the bitmap at the word position
    /// @param from The address to use the nonce at
    /// @param nonce The nonce to spend
    /**
     * @notice Checks whether a nonce is taken and sets the bit in the bitmap.
     * @dev Reverts if the nonce has already been used.
     * @param from The address to use the nonce at.
     * @param nonce The nonce to spend.
     */
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bit = uint256(1) << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^= bit;

        if (flipped & bit == 0) revert InvalidNonce();
    }

    // ================================ Extra code by Contango ================================

    /// @notice Checks whether a nonce is taken
    /// @param from The address to check the nonce for
    /// @param nonce The nonce to check
    /// @return wasUsed Whether the nonce was used
    /**
     * @notice Checks whether a nonce has already been used.
     * @param from The address to check the nonce for.
     * @param nonce The nonce to check.
     * @return wasUsed True if the nonce was used, false otherwise.
     */
    function _wasNonceUsed(address from, uint256 nonce) internal view returns (bool) {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bit = uint256(1) << bitPos;
        return nonceBitmap[from][wordPos] & bit != 0;
    }

    /// @notice Uses a nonce
    /// @param nonce The nonce to use
    /**
     * @notice Uses a nonce for the caller.
     * @param nonce The nonce to use.
     */
    function useUnorderedNonce(uint256 nonce) public {
        _useUnorderedNonce(msg.sender, nonce);
    }

}
