//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { UD60x18 } from "@prb/math/UD60x18.sol";

uint256 constant ACCOUNT_BALANCE = type(uint256).max;
uint256 constant DEBT_BALANCE = type(uint256).max - 1;
uint256 constant COLLATERAL_BALANCE = type(uint256).max - 2;

bytes4 constant EIP_1271_VALIDATION_FAILED = 0xFFFFFFFF;
uint256 constant MODULE_TYPE_STATELESS_VALIDATOR = 7;

uint256 constant RAY = 1e27;
uint256 constant WAD = 1e18;

UD60x18 constant DAYS_PER_YEAR = UD60x18.wrap(365e18);
UD60x18 constant SECONDS_PER_DAY = UD60x18.wrap(1 days * WAD);

uint256 constant SELECTOR_SIZE = 4;
uint256 constant ADDRESS_SIZE = 20;
uint256 constant WORD_SIZE = 32;
