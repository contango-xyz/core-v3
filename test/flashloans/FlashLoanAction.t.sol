//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BaseTest } from "../BaseTest.t.sol";
import { FlashLoanProvider } from "../FlashLoanProvider.t.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC7579Execution } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { Solarray } from "solarray/Solarray.sol";

import { Action, PackedAction } from "../../src/types/Action.sol";
import { ActionLib } from "../ActionLib.sol";
import { ERC1271Executor } from "../../src/modules/ERC1271Executor.sol";
import { PreSignedValidator } from "../../src/modules/PreSignedValidator.sol";

import { FlashLoanAction } from "../../src/flashloan/FlashLoanAction.sol";
import { TokenAction } from "../../src/actions/TokenAction.sol";
import { IERC7399 } from "../../src/flashloan/dependencies/IERC7399.sol";
import { IERC3156FlashLender, IERC3156FlashBorrower } from "../../src/flashloan/dependencies/IERC3156.sol";
import { IPoolAddressesProvider } from "../../src/moneymarkets/aave/dependencies/IPoolAddressesProvider.sol";
import { IFlashLoaner } from "../../src/flashloan/dependencies/Balancer.sol";
import { IMorpho } from "../../src/moneymarkets/morpho/dependencies/IMorpho.sol";
import { IUniswapV3Pool } from "../../src/flashloan/dependencies/UniswapV3.sol";
import { IAlgebraPool } from "../../src/dependencies/dex/Algebra.sol";
import { ISolidlyPool } from "../../src/flashloan/dependencies/Solidly.sol";
import { IEulerVault } from "../../src/moneymarkets/euler/dependencies/IEulerVault.sol";
import { IPendleMarketV3 } from "../../src/dependencies/dex/Pendle.sol";

contract FlashLoanActionTest is BaseTest {

    using ActionLib for *;
    using Solarray for *;

    IERC20 internal weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 internal dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 internal usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address internal owner;
    address internal account;

    Action[] internal actions;

    function setUp() public override {
        vm.createSelectFork("mainnet", 24_627_639);
        super.setUp();

        owner = makeAddr("owner");
        account = newAccount(owner, "account");
    }

    function test_FlashLoan7399() public {
        address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        IERC7399 balancerProvider = IERC7399(0x9E092cb431e5F1aa70e47e052773711d2Ba4917E);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (weth, 1e18, balancer))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanERC7399,
                        (
                            balancerProvider,
                            weth,
                            1e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanERC3156() public {
        IERC3156FlashLender makerFlash = IERC3156FlashLender(0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100e18, address(flashLoanAction)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanERC3156,
                        (
                            makerFlash,
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_RevertWhen_FlashLoanERC3156ReturnsFalse() public {
        MockERC3156LenderReturnsFalse lender = new MockERC3156LenderReturnsFalse();
        vm.expectRevert(FlashLoanAction.FlashLoanFailed.selector);
        flashLoanAction.flashLoanERC3156(lender, dai, 100e18, "", account);
    }

    function test_FlashLoanAave() public {
        IPoolAddressesProvider pap = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        deal(address(dai), account, 0.05e18); // 0.05 DAI for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100.05e18, address(flashLoanAction)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanAave,
                        (
                            pap.getPool(),
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanBalancer() public {
        IFlashLoaner balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100e18, address(balancer)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanBalancer,
                        (
                            balancer,
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanMorpho() public {
        IMorpho morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100e18, address(flashLoanAction)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanMorpho,
                        (
                            morpho,
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanUniswapV3_Token0() public {
        IUniswapV3Pool pool = IUniswapV3Pool(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
        deal(address(dai), account, 0.01e18); // 0.01 DAI for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100.01e18, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanUniswapV3,
                        (
                            pool,
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanUniswapV3_Token1() public {
        IUniswapV3Pool pool = IUniswapV3Pool(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
        deal(address(usdc), account, 0.01e6); // 0.01 USDC for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 100.01e6, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanUniswapV3,
                        (
                            pool,
                            usdc,
                            100e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanAlgebra_Token0() public {
        vm.createSelectFork("arbitrum", 440_349_333);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        IAlgebraPool pool = IAlgebraPool(0x45FaE8D0D2acE73544baab452f9020925AfCCC75);
        usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

        deal(address(usdc), account, 0.01e6); // 0.01 USDC for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 100.01e6, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanAlgebra,
                        (
                            pool,
                            usdc,
                            100e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanAlgebra_Token1() public {
        vm.createSelectFork("arbitrum", 440_349_333);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        IAlgebraPool pool = IAlgebraPool(0x45FaE8D0D2acE73544baab452f9020925AfCCC75);
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

        deal(address(dai), account, 0.01e18); // 0.01 DAI for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100.01e18, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanAlgebra,
                        (
                            pool,
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanSolidly_Token0() public {
        vm.createSelectFork("base", 43_181_672);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        ISolidlyPool pool = ISolidlyPool(0x67b00B46FA4f4F24c03855c5C8013C0B938B3eEc);
        dai = IERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);

        deal(address(dai), account, 0.050025012506253126e18); // 0.050025012506253126 DAI for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100.050025012506253126e18, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanSolidly,
                        (
                            pool,
                            dai,
                            100e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanSolidly_Token1() public {
        vm.createSelectFork("base", 43_181_672);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        ISolidlyPool pool = ISolidlyPool(0x67b00B46FA4f4F24c03855c5C8013C0B938B3eEc);
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        deal(address(usdc), account, 0.050025e6); // 0.050025 USDC for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 100.050025e6, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanSolidly,
                        (
                            pool,
                            usdc,
                            100e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoanEuler() public {
        IEulerVault vault = IEulerVault(0xe0a80d35bB6618CBA260120b279d357978c42BCE);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 100e6, address(vault)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoanEuler,
                        (
                            vault,
                            usdc,
                            100e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoansAave() public {
        IPoolAddressesProvider pap = IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
        deal(address(dai), account, 0.05e18); // 0.05 DAI for fees
        deal(address(usdc), account, 0.05e6); // 0.05 USDC for fees

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100.05e18, address(flashLoanAction)))));
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 100.05e6, address(flashLoanAction)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoansAave,
                        (
                            pap.getPool(),
                            toArray(dai, usdc),
                            Solarray.uint256s(100e18, 100e6),
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashLoansBalancer() public {
        IFlashLoaner balancer = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 100e18, address(balancer)))));
        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 100e6, address(balancer)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashLoansBalancer,
                        (
                            balancer,
                            toArray(dai, usdc),
                            Solarray.uint256s(100e18, 100e6),
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());
    }

    function test_FlashSwapUniswapV3_Token0Token1() public {
        IUniswapV3Pool pool = IUniswapV3Pool(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
        deal(address(dai), account, 1000e18);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 1000e18, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapUniswapV3,
                        (
                            pool,
                            dai,
                            1000e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(dai.balanceOf(account), 0, 18, "DAI balance should be 0");
        assertEqDecimal(usdc.balanceOf(account), 999.816855e6, 6, "USDC balance should be 999.816855");
    }

    function test_FlashSwapUniswapV3_Token1Token0() public {
        IUniswapV3Pool pool = IUniswapV3Pool(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
        deal(address(usdc), account, 1000e6);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 1000e6, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapUniswapV3,
                        (
                            pool,
                            usdc,
                            1000e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(usdc.balanceOf(account), 0, 6, "USDC balance should be 0");
        assertEqDecimal(dai.balanceOf(account), 999.983053014355823306e18, 18, "DAI balance should be 999.983053014355823306");
    }

    function test_FlashSwapPendle_PtForSy() public {
        IERC20 PT_Ethena_sUSDE_7MAY2026 = IERC20(0x3de0ff76E8b528C092d47b9DaC775931cef80F49);
        IERC20 SY = IERC20(0xBF98480425A29197e5d99D003017f63a1e595D02);
        IPendleMarketV3 market = IPendleMarketV3(0x8dAe8ECe668cf80d348873F23D456448E8694883);

        deal(address(PT_Ethena_sUSDE_7MAY2026), account, 1000e18);

        actions.push(
            address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (PT_Ethena_sUSDE_7MAY2026, 1000e18, address(market))))
        );

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapPendle,
                        (
                            market,
                            1000e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(PT_Ethena_sUSDE_7MAY2026.balanceOf(account), 0, 18, "PTsUSDe31JUL2025 balance should be 0");
        assertEqDecimal(SY.balanceOf(account), 811.558681261637220739e18, 18, "SY balance should be 811.558681261637220739");
    }

    function test_FlashSwapAlgebra_Token0Token1() public {
        vm.createSelectFork("arbitrum", 440_349_333);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        IAlgebraPool pool = IAlgebraPool(0x45FaE8D0D2acE73544baab452f9020925AfCCC75);
        usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

        deal(address(usdc), account, 1000e6);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 1000e6, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapAlgebra,
                        (
                            pool,
                            usdc,
                            1000e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(usdc.balanceOf(account), 0, 6, "USDC balance should be 0");
        assertEqDecimal(dai.balanceOf(account), 999.902743502071640735e18, 18, "DAI balance should be 999.902743502071640735");
    }

    function test_FlashSwapAlgebra_Token1() public {
        vm.createSelectFork("arbitrum", 440_349_333);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        IAlgebraPool pool = IAlgebraPool(0x45FaE8D0D2acE73544baab452f9020925AfCCC75);
        usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

        deal(address(dai), account, 1000e18);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 1000e18, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapAlgebra,
                        (
                            pool,
                            dai,
                            1000e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(dai.balanceOf(account), 0, 18, "DAI balance should be 0");
        assertEqDecimal(usdc.balanceOf(account), 999.992224e6, 6, "USDC balance should be 999.992224");
    }

    function test_FlashSwapSolidly_Token0Token1() public {
        vm.createSelectFork("base", 43_181_672);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        ISolidlyPool pool = ISolidlyPool(0x67b00B46FA4f4F24c03855c5C8013C0B938B3eEc);
        dai = IERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        deal(address(dai), account, 1000e18);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (dai, 1000e18, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapSolidly,
                        (
                            pool,
                            dai,
                            1000e18,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(dai.balanceOf(account), 0, 18, "DAI balance should be 0");
        assertEqDecimal(usdc.balanceOf(account), 995.030924e6, 6, "USDC balance should be 995.030924");
    }

    function test_FlashSwapSolidly_Token1Token0() public {
        vm.createSelectFork("base", 43_181_672);
        super.setUp();
        owner = makeAddr("owner");
        account = newAccount(owner, "account");

        ISolidlyPool pool = ISolidlyPool(0x67b00B46FA4f4F24c03855c5C8013C0B938B3eEc);
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        dai = IERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);

        deal(address(usdc), account, 1000e6);

        actions.push(address(tokenAction).delegateAction(abi.encodeCall(TokenAction.push, (usdc, 1000e6, address(pool)))));

        PackedAction[] memory packedCalls = actions.pack();
        uint256 innerNonce = erc1271Nonce[block.chainid]++;
        bytes32 digest = erc1271Executor.digest(IERC7579Execution(account), abi.encode(packedCalls), innerNonce);
        bytes memory signature = abi.encodePacked(preSignedValidator);

        delete actions;
        actions.push(address(preSignedValidator).action(abi.encodeCall(PreSignedValidator.approveHash, (digest, false))));
        actions.push(
            address(flashLoanAction)
                .action(
                    abi.encodeCall(
                        FlashLoanAction.flashSwapSolidly,
                        (
                            pool,
                            usdc,
                            1000e6,
                            abi.encodePacked(
                                erc1271Executor,
                                abi.encodeCall(
                                    ERC1271Executor.executeActions, (IERC7579Execution(account), packedCalls, signature, innerNonce)
                                )
                            ),
                            account
                        )
                    )
                )
        );

        vm.prank(owner);
        ownableExecutor.executeActions(IERC7579Execution(account), actions.pack());

        assertEqDecimal(usdc.balanceOf(account), 0, 6, "USDC balance should be 0");
        assertEqDecimal(dai.balanceOf(account), 993.928935051802237306e18, 18, "DAI balance should be 993.928935051802237306");
    }

}

contract MockERC3156LenderReturnsFalse is IERC3156FlashLender {

    function maxFlashLoan(IERC20) external pure returns (uint256) {
        return type(uint256).max;
    }

    function flashFee(IERC20, uint256) external pure returns (uint256) {
        return 0;
    }

    function flashLoan(IERC3156FlashBorrower, IERC20, uint256, bytes calldata) external pure returns (bool) {
        return false;
    }

}

function toArray(IERC20 a, IERC20 b) pure returns (IERC20[] memory arr) {
    arr = new IERC20[](2);
    arr[0] = a;
    arr[1] = b;
}
