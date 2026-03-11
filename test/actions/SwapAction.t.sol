//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { Solarray } from "solarray/Solarray.sol";

import { SpotMarket } from "../SpotMarket.sol";
import { DumbWallet } from "../DumbWallet.sol";

import { SwapAction } from "../../src/actions/SwapAction.sol";
import { ACCOUNT_BALANCE } from "../../src/constants.sol";

using Address for address;

contract SwapActionTest is Test {

    SwapAction private action;

    SpotMarket private spotMarket;

    IERC4626 private constant sDAI = IERC4626(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    IERC20 private constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    DumbWallet private wallet;

    function setUp() public {
        vm.createSelectFork("mainnet", 24_627_639);
        action = new SwapAction();
        spotMarket = new SpotMarket(0.01e18);
        wallet = new DumbWallet();

        vm.label(address(DAI), "DAI");
        vm.label(address(sDAI), "sDAI");
        vm.label(address(USDC), "USDC");

        deal(address(DAI), address(spotMarket), 10_000e18);
        deal(address(USDC), address(spotMarket), 10_000e6);

        deal(address(USDC), address(wallet), 1000e6);
    }

    function test_executeSwap_direct() public {
        SwapAction.Swap memory swap = SwapAction.Swap({
            tokenToSell: USDC,
            amountIn: 1000e6,
            tokenToBuy: DAI,
            minAmountOut: 0,
            router: address(spotMarket),
            spender: address(spotMarket),
            swapBytes: abi.encodeCall(SpotMarket.swap, (USDC, 1000e6, DAI, 1000e18)),
            spotMarketName: "Test Spot Market",
            offsets: new uint256[](0)
        });

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapPartExecuted(USDC, DAI, 1000e6, 990e18, "Test Spot Market");

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapExecuted(USDC, DAI, 1000e6, 990e18);

        (uint256 amountIn, uint256 amountOut) =
            abi.decode(wallet.delegate(address(action), abi.encodeCall(SwapAction.executeSwap, (swap))), (uint256, uint256));

        assertEqDecimal(amountIn, 1000e6, 6, "Amount in should be 1000");
        assertEqDecimal(amountOut, 990e18, 18, "Output should be 990");
        assertEqDecimal(DAI.balanceOf(address(wallet)), 990e18, 18, "DAI balance should be 990 after slippage");
    }

    function test_executeSwap_AccountBalance() public {
        SwapAction.Swap memory swap = SwapAction.Swap({
            tokenToSell: USDC,
            amountIn: ACCOUNT_BALANCE,
            tokenToBuy: DAI,
            minAmountOut: 0,
            router: address(spotMarket),
            spender: address(spotMarket),
            swapBytes: abi.encodeCall(SpotMarket.swap, (USDC, 1000e6, DAI, 1000e18)),
            spotMarketName: "Test Spot Market",
            offsets: Solarray.uint256s(4 + 32)
        });

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapPartExecuted(USDC, DAI, 1000e6, 990e18, "Test Spot Market");

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapExecuted(USDC, DAI, 1000e6, 990e18);

        (uint256 amountIn, uint256 amountOut) =
            abi.decode(wallet.delegate(address(action), abi.encodeCall(SwapAction.executeSwap, (swap))), (uint256, uint256));

        assertEqDecimal(amountIn, 1000e6, 6, "Amount in should be 1000");
        assertEqDecimal(amountOut, 990e18, 18, "Output should be 990");
        assertEqDecimal(DAI.balanceOf(address(wallet)), 990e18, 18, "DAI balance should be 990 after slippage");
    }

    function test_executeSwaps_erc4626_deposit() public {
        SwapAction.Swap[] memory swaps = new SwapAction.Swap[](2);
        swaps[0] = SwapAction.Swap({
            tokenToSell: USDC,
            amountIn: ACCOUNT_BALANCE,
            tokenToBuy: DAI,
            minAmountOut: 0,
            router: address(spotMarket),
            spender: address(spotMarket),
            swapBytes: abi.encodeCall(SpotMarket.swap, (USDC, 1000e6, DAI, 1000e18)),
            spotMarketName: "Test Spot Market",
            offsets: Solarray.uint256s(4 + 32)
        });

        swaps[1] = SwapAction.Swap({
            tokenToSell: DAI,
            amountIn: ACCOUNT_BALANCE,
            tokenToBuy: sDAI,
            minAmountOut: 0,
            router: address(sDAI),
            spender: address(sDAI),
            swapBytes: abi.encodeCall(IERC4626.deposit, (1000e18, address(wallet))),
            spotMarketName: "sDAI",
            offsets: Solarray.uint256s(4)
        });

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapPartExecuted(USDC, DAI, 1000e6, 990e18, "Test Spot Market");
        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapPartExecuted(DAI, sDAI, 990e18, 843.995857702612663143e18, "sDAI");

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapExecuted(USDC, sDAI, 1000e6, 843.995857702612663143e18);

        (uint256 amountIn, uint256 amountOut) =
            abi.decode(wallet.delegate(address(action), abi.encodeCall(SwapAction.executeSwaps, (swaps))), (uint256, uint256));

        assertEqDecimal(amountIn, 1000e6, 6, "Amount in should be 1000");
        assertEqDecimal(amountOut, 843.995857702612663143e18, 18, "Output should be 843.995857702612663143");
        assertEqDecimal(
            sDAI.balanceOf(address(wallet)), 843.995857702612663143e18, 18, "sDAI balance should be 843.9958577026126631430 after deposit"
        );
    }

    function test_executeSwaps_erc4626_redeem() public {
        deal(address(USDC), address(wallet), 0);
        deal(address(sDAI), address(wallet), 843.995857702612663143e18);

        SwapAction.Swap[] memory swaps = new SwapAction.Swap[](2);
        swaps[0] = SwapAction.Swap({
            tokenToSell: sDAI,
            amountIn: ACCOUNT_BALANCE,
            tokenToBuy: DAI,
            minAmountOut: 0,
            router: address(sDAI),
            spender: address(sDAI),
            swapBytes: abi.encodeCall(IERC4626.redeem, (1000e18, address(wallet), address(wallet))),
            spotMarketName: "sDAI",
            offsets: Solarray.uint256s(4)
        });

        swaps[1] = SwapAction.Swap({
            tokenToSell: DAI,
            amountIn: ACCOUNT_BALANCE,
            tokenToBuy: USDC,
            minAmountOut: 0,
            router: address(spotMarket),
            spender: address(spotMarket),
            swapBytes: abi.encodeCall(SpotMarket.swapAtPrice, (DAI, 1000e18, USDC, 1e18)),
            spotMarketName: "Test Spot Market",
            offsets: Solarray.uint256s(4 + 32)
        });

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapPartExecuted(sDAI, DAI, 843.995857702612663143e18, 989.999999999999999998e18, "sDAI");
        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapPartExecuted(DAI, USDC, 989.999999999999999998e18, 980.099999e6, "Test Spot Market");

        vm.expectEmit(true, true, true, true);
        emit SwapAction.SwapExecuted(sDAI, USDC, 843.995857702612663143e18, 980.099999e6);

        (uint256 amountIn, uint256 amountOut) =
            abi.decode(wallet.delegate(address(action), abi.encodeCall(SwapAction.executeSwaps, (swaps))), (uint256, uint256));

        assertEqDecimal(amountIn, 843.995857702612663143e18, 18, "Amount in should be 843.995857702612663143");
        assertEqDecimal(amountOut, 980.099999e6, 6, "Output should be 980.099999");
        assertEqDecimal(USDC.balanceOf(address(wallet)), 980.099999e6, 6, "USDC balance should be 980.099999 after redeem");
    }

    function test_executeSwaps_emptyArray() public {
        vm.expectRevert(abi.encodeWithSelector(SwapAction.EmptySwapArray.selector));
        wallet.delegate(address(action), abi.encodeCall(SwapAction.executeSwaps, (new SwapAction.Swap[](0))));
    }

    function test_executeSwap_offsetsRequiredForAccountBalance() public {
        vm.expectRevert(abi.encodeWithSelector(SwapAction.OffsetsRequired.selector));
        wallet.delegate(
            address(action),
            abi.encodeCall(
                SwapAction.executeSwap,
                (SwapAction.Swap({
                        tokenToSell: USDC,
                        amountIn: ACCOUNT_BALANCE,
                        tokenToBuy: DAI,
                        minAmountOut: 0,
                        router: address(spotMarket),
                        spender: address(spotMarket),
                        swapBytes: abi.encodeCall(SpotMarket.swap, (USDC, 1000e6, DAI, 1000e18)),
                        spotMarketName: "Test Spot Market",
                        offsets: new uint256[](0)
                    }))
            )
        );
    }

    function test_executeSwaps_offsetsRequiredForFollowUpSwaps() public {
        deal(address(USDC), address(wallet), 0);
        deal(address(sDAI), address(wallet), 843.995857702612663143e18);

        SwapAction.Swap[] memory swaps = new SwapAction.Swap[](2);
        swaps[0] = SwapAction.Swap({
            tokenToSell: sDAI,
            amountIn: ACCOUNT_BALANCE,
            tokenToBuy: DAI,
            minAmountOut: 0,
            router: address(sDAI),
            spender: address(sDAI),
            swapBytes: abi.encodeCall(IERC4626.redeem, (1000e18, address(wallet), address(wallet))),
            spotMarketName: "sDAI",
            offsets: Solarray.uint256s(4)
        });

        swaps[1] = SwapAction.Swap({
            tokenToSell: DAI,
            amountIn: 1000e18,
            tokenToBuy: USDC,
            minAmountOut: 0,
            router: address(spotMarket),
            spender: address(spotMarket),
            swapBytes: abi.encodeCall(SpotMarket.swapAtPrice, (DAI, 1000e18, USDC, 1e18)),
            spotMarketName: "Test Spot Market",
            offsets: new uint256[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(SwapAction.OffsetsRequired.selector));
        wallet.delegate(address(action), abi.encodeCall(SwapAction.executeSwaps, (swaps)));
    }

}
