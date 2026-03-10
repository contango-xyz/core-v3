// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MoneyMarketMock {

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error SupplyCapExceeded(IERC20 token, uint256 currentBalance, uint256 amount, uint256 supplyCap);

    // Interest rate parameters
    uint256 public constant SECONDS_PER_YEAR = 31_536_000;
    uint256 public constant SCALING_FACTOR = 1e18;
    uint256 public interestRatePerSecond;

    mapping(IERC20 => uint256) public supplyCaps;
    mapping(IERC20 => uint256) public tokenBalances;
    mapping(address => mapping(IERC20 => uint256)) public collateralBalances;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => EnumerableSet.AddressSet) private _activeTokens;

    constructor(uint256 initialAPY) {
        _setAPY(initialAPY);
    }

    function setAPY(uint256 newAPY) external {
        _setAPY(newAPY);
    }

    function _setAPY(uint256 apy) internal {
        // apy is in 1e18 format (e.g., 3.2e18 for 3.2%)
        // Convert to per-second rate
        interestRatePerSecond = SCALING_FACTOR + (apy / (100 * SECONDS_PER_YEAR));
    }

    function setSupplyCap(IERC20 token, uint256 newSupplyCap) external {
        supplyCaps[token] = newSupplyCap;
    }

    function supply(IERC20 token, uint256 amount) external returns (uint256 supplied) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        _accrueInterest(msg.sender);
        require(
            supplyCaps[token] == 0 || tokenBalances[token] + amount <= supplyCaps[token],
            SupplyCapExceeded(token, tokenBalances[token], amount, supplyCaps[token])
        );
        collateralBalances[msg.sender][token] += amount;
        tokenBalances[token] += amount;
        _activeTokens[msg.sender].add(address(token));
        supplied = amount;
    }

    function withdraw(IERC20 token, uint256 amount, address to) external returns (uint256 withdrawn) {
        _accrueInterest(msg.sender);
        require(collateralBalances[msg.sender][token] >= amount, "Insufficient balance");
        collateralBalances[msg.sender][token] -= amount;
        ensureBalance(token, amount);
        token.safeTransfer(to, amount);
        if (collateralBalances[msg.sender][token] == 0) _activeTokens[msg.sender].remove(address(token));
        withdrawn = amount;
    }

    function collateralBalance(address user, IERC20 token) external view returns (uint256) {
        return _getCurrentBalance(collateralBalances[user][token], user);
    }

    function _accrueInterest(address user) internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTime[user];
        if (timeElapsed > 0) {
            // Update all balances with accrued interest
            IERC20[] memory tokens = _getActiveTokens(user);
            for (uint256 i = 0; i < tokens.length; i++) {
                IERC20 token = tokens[i];
                collateralBalances[user][token] = _getCurrentBalance(collateralBalances[user][token], user);
            }
            lastUpdateTime[user] = block.timestamp;
        }
    }

    function _getCurrentBalance(uint256 balance, address user) internal view returns (uint256) {
        if (balance == 0) return 0;
        uint256 timeElapsed = block.timestamp - lastUpdateTime[user];
        if (timeElapsed == 0) return balance;

        // Simple interest formula: balance * (1 + r * t)
        // where r is per-second rate and t is elapsed time
        uint256 interest = (balance * (interestRatePerSecond - SCALING_FACTOR) * timeElapsed) / SCALING_FACTOR;
        return balance + interest;
    }

    function _getActiveTokens(address user) internal view returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](_activeTokens[user].length());
        for (uint256 i = 0; i < _activeTokens[user].length(); i++) {
            tokens[i] = IERC20(_activeTokens[user].at(i));
        }
        return tokens;
    }

    function ensureBalance(IERC20 token, uint256 amount) internal {
        uint256 balance = token.balanceOf(address(this));
        if (balance < amount) ERC20Mock(address(token)).mint(address(this), amount - balance);
    }

}
