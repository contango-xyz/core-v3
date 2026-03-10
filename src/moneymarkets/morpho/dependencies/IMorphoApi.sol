// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @title IMorphoApi
/// @author Contango
/// @notice Fake interface to define synthetic events that represent data coming from Morpho/s GraphQL API
interface IMorphoApi {

    type MarketId is bytes32;

    event MarketWhitelisted(MarketId indexed marketId);
    event MarketBlacklisted(MarketId indexed marketId);

}
