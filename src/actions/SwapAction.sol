//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { ERC20Lib, IERC20, Address } from "../libraries/ERC20Lib.sol";
import { BytesLib } from "../libraries/BytesLib.sol";
import { ACCOUNT_BALANCE } from "../constants.sol";

contract SwapAction {

    using ERC20Lib for IERC20;
    using Address for address;
    using BytesLib for bytes;

    event SwapPartExecuted(
        IERC20 indexed tokenToSell, IERC20 indexed tokenToBuy, uint256 amountIn, uint256 amountOut, string spotMarketName
    );
    event SwapExecuted(IERC20 indexed tokenToSell, IERC20 indexed tokenToBuy, uint256 amountIn, uint256 amountOut);

    error InsufficientAmountOut(uint256 minExpected, uint256 actual);
    error EmptySwapArray();
    error OffsetsRequired();

    struct Swap {
        IERC20 tokenToSell;
        uint256 amountIn;
        IERC20 tokenToBuy;
        uint256 minAmountOut;
        address router;
        address spender;
        bytes swapBytes;
        string spotMarketName;
        uint256[] offsets;
    }

    function executeSwap(Swap memory swap) public returns (uint256 amountIn_, uint256 amountOut_) {
        (amountIn_, amountOut_) = _executeSwap(swap, swap.amountIn);
        emit SwapExecuted(swap.tokenToSell, swap.tokenToBuy, amountIn_, amountOut_);
    }

    function executeSwaps(Swap[] memory swaps) public returns (uint256 amountIn_, uint256 amountOut_) {
        require(swaps.length > 0, EmptySwapArray());

        uint256 amountIn;
        for (uint256 i = 0; i < swaps.length; i++) {
            (amountIn, amountOut_) = _executeSwap(swaps[i], i == 0 ? swaps[0].amountIn : amountOut_);
            if (i == 0) amountIn_ = amountIn;
        }
        emit SwapExecuted(swaps[0].tokenToSell, swaps[swaps.length - 1].tokenToBuy, amountIn_, amountOut_);
    }

    function _executeSwap(Swap memory swap, uint256 amountInArg) internal returns (uint256 amountIn_, uint256 amountOut_) {
        amountIn_ = amountInArg = _amountIn(swap, amountInArg);
        swap.tokenToSell.forceApprove(swap.spender, amountInArg);

        uint256 balanceBefore = swap.tokenToBuy.myBalance();
        swap.router.functionCall(swap.swapBytes);
        amountOut_ = swap.tokenToBuy.myBalance() - balanceBefore;

        require(amountOut_ >= swap.minAmountOut, InsufficientAmountOut(swap.minAmountOut, amountOut_));

        emit SwapPartExecuted(swap.tokenToSell, swap.tokenToBuy, amountIn_, amountOut_, swap.spotMarketName);
    }

    function _amountIn(Swap memory swap, uint256 amountInArg) internal view returns (uint256 amountIn_) {
        amountIn_ = amountInArg == ACCOUNT_BALANCE ? swap.tokenToSell.myBalance() : amountInArg;
        require(amountIn_ == swap.amountIn || swap.offsets.length > 0, OffsetsRequired());

        for (uint256 i = 0; i < swap.offsets.length; i++) {
            swap.swapBytes.set(swap.offsets[i], amountIn_);
        }
    }

}
