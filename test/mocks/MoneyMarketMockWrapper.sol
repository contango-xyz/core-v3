//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { MoneyMarketMock } from "./MoneyMarketMock.sol";

contract MoneyMarketMockWrapper {

    using SafeERC20 for IERC20;

    MoneyMarketMock public immutable MONEY_MARKET;

    constructor(uint256 initialApy) {
        MONEY_MARKET = new MoneyMarketMock(initialApy);
    }

    function supply(uint256 amount, IERC20 token) external returns (uint256 supplied) {
        token.forceApprove(address(MONEY_MARKET), amount);
        supplied = MONEY_MARKET.supply(token, amount);
    }

    function withdraw(uint256 amount, IERC20 token, address to) external returns (uint256 withdrawn) {
        withdrawn = MONEY_MARKET.withdraw(token, amount, to);
    }

    function collateralBalance(address user, IERC20 token) external view returns (uint256) {
        return MONEY_MARKET.collateralBalance(user, token);
    }

    function supplyCap(IERC20 token) external view returns (uint256) {
        uint256 _supplyCap = MONEY_MARKET.supplyCaps(token);
        if (_supplyCap == 0) return type(uint256).max;
        uint256 _tokenBalance = MONEY_MARKET.tokenBalances(token);
        return _tokenBalance >= _supplyCap ? 0 : _supplyCap - _tokenBalance;
    }

}
