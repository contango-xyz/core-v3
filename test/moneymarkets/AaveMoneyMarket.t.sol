//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AaveMoneyMarket } from "../../src/moneymarkets/aave/AaveMoneyMarket.sol";
import { DataTypes } from "../../src/moneymarkets/aave/dependencies/DataTypes.sol";
import { IAToken } from "../../src/moneymarkets/aave/dependencies/IAToken.sol";
import { IFlashLoanReceiver } from "../../src/moneymarkets/aave/dependencies/IFlashLoanReceiver.sol";
import { IPool } from "../../src/moneymarkets/aave/dependencies/IPool.sol";

contract MockScaledBalanceToken {

    function scaledBalanceOf(address) external pure returns (uint256) {
        return 0;
    }

}

contract MockAavePoolForFlashBorrowMany {

    IAToken internal immutable mockDebtToken;
    uint256[] internal _lastInterestRateModes;

    constructor(IAToken debtToken_) {
        mockDebtToken = debtToken_;
    }

    function flashLoan(
        IFlashLoanReceiver,
        IERC20[] memory assets,
        uint256[] memory,
        uint256[] memory interestRateModes,
        address,
        bytes memory,
        uint16
    ) external {
        require(interestRateModes.length == assets.length, "mode length mismatch");
        _lastInterestRateModes = interestRateModes;
    }

    function getReserveData(IERC20) external view returns (DataTypes.ReserveDataLegacy memory data) {
        data.variableDebtTokenAddress = mockDebtToken;
    }

    function getReserveNormalizedVariableDebt(IERC20) external pure returns (uint256) {
        return 1e27;
    }

    function lastInterestRateModes() external view returns (uint256[] memory) {
        return _lastInterestRateModes;
    }

}

contract AaveMoneyMarketTest is Test {

    AaveMoneyMarket internal moneyMarket;
    MockAavePoolForFlashBorrowMany internal pool;

    function setUp() public {
        moneyMarket = new AaveMoneyMarket();
        pool = new MockAavePoolForFlashBorrowMany(IAToken(address(new MockScaledBalanceToken())));
    }

    function test_flashBorrowMany_supportsMultipleAssets() public {
        IERC20[] memory assets = new IERC20[](2);
        assets[0] = IERC20(address(0x1));
        assets[1] = IERC20(address(0x2));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 2e6;

        moneyMarket.flashBorrowMany(assets, amounts, "", IPool(address(pool)));

        uint256[] memory modes = pool.lastInterestRateModes();
        assertEq(modes.length, 2, "interest rate mode length");
        assertEq(modes[0], uint8(DataTypes.InterestRateMode.VARIABLE), "first mode");
        assertEq(modes[1], uint8(DataTypes.InterestRateMode.VARIABLE), "second mode");
    }

}
