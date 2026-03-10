// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface ICurveV2PoolEvents {

    event TokenExchange(address indexed buyer, int128 sold_id, uint256 tokens_sold, int128 bought_id, uint256 tokens_bought);
    event TokenExchangeUnderlying(address indexed buyer, int128 sold_id, uint256 tokens_sold, int128 bought_id, uint256 tokens_bought);

}

interface ICurveV2PoolEventsOverload {

    event TokenExchange(
        address indexed buyer,
        uint256 sold_id,
        uint256 tokens_sold,
        uint256 bought_id,
        uint256 tokens_bought,
        uint256 fee,
        uint256 packed_price_scale
    );

}
