// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import { Vm } from "forge-std/Vm.sol";

import { IWETH9 } from "../src/dependencies/IWETH9.sol";

enum Network {
    Mainnet,
    Arbitrum,
    Optimism,
    Polygon,
    PolygonZK,
    Gnosis,
    Base,
    Bsc,
    Linea,
    Scroll,
    Avalanche
}

library NetworkLib {

    function isArbitrum(Network network) internal pure returns (bool) {
        return network == Network.Arbitrum;
    }

    function isOptimism(Network network) internal pure returns (bool) {
        return network == Network.Optimism;
    }

    function isPolygon(Network network) internal pure returns (bool) {
        return network == Network.Polygon;
    }

    function isMainnet(Network network) internal pure returns (bool) {
        return network == Network.Mainnet;
    }

    function isGnosis(Network network) internal pure returns (bool) {
        return network == Network.Gnosis;
    }

    function isBase(Network network) internal pure returns (bool) {
        return network == Network.Base;
    }

    function isPolygonZK(Network network) internal pure returns (bool) {
        return network == Network.PolygonZK;
    }

    function isBsc(Network network) internal pure returns (bool) {
        return network == Network.Bsc;
    }

    function isLinea(Network network) internal pure returns (bool) {
        return network == Network.Linea;
    }

    function isScroll(Network network) internal pure returns (bool) {
        return network == Network.Scroll;
    }

    function isAvalanche(Network network) internal pure returns (bool) {
        return network == Network.Avalanche;
    }

    function chainId(Network network) internal pure returns (uint256) {
        if (isMainnet(network)) return 1;
        if (isOptimism(network)) return 10;
        if (isBsc(network)) return 56;
        if (isGnosis(network)) return 100;
        if (isPolygon(network)) return 137;
        if (isPolygonZK(network)) return 1101;
        if (isBase(network)) return 8453;
        if (isArbitrum(network)) return 42_161;
        if (isAvalanche(network)) return 43_114;
        if (isLinea(network)) return 59_144;
        if (isScroll(network)) return 534_352;

        revert("Unsupported network");
    }

    function toString(Network network) internal pure returns (string memory) {
        if (network == Network.Arbitrum) return "arbitrum-one";
        if (network == Network.Optimism) return "optimism";
        if (network == Network.Polygon) return "matic";
        if (network == Network.Mainnet) return "mainnet";
        if (network == Network.PolygonZK) return "polygon-zk";
        if (network == Network.Gnosis) return "gnosis";
        if (network == Network.Base) return "base";
        if (network == Network.Bsc) return "bsc";
        if (network == Network.Linea) return "linea";
        if (network == Network.Scroll) return "scroll";
        if (network == Network.Avalanche) return "avalanche";
        revert("Unsupported network");
    }

    function currentNetwork() internal view returns (Network) {
        return networkFromChainId(block.chainid);
    }

    function networkFromChainId(uint256 _chainId) internal pure returns (Network) {
        if (_chainId == 1) return Network.Mainnet;
        if (_chainId == 10) return Network.Optimism;
        if (_chainId == 56) return Network.Bsc;
        if (_chainId == 100) return Network.Gnosis;
        if (_chainId == 137) return Network.Polygon;
        if (_chainId == 1101) return Network.PolygonZK;
        if (_chainId == 8453) return Network.Base;
        if (_chainId == 42_161) return Network.Arbitrum;
        if (_chainId == 43_114) return Network.Avalanche;
        if (_chainId == 59_144) return Network.Linea;
        if (_chainId == 534_352) return Network.Scroll;
        revert(
            string.concat("Unsupported network, chainId=", Vm(address(uint160(uint256(keccak256("hevm cheat code"))))).toString(_chainId))
        );
    }

    function nativeToken(Network network) internal pure returns (IWETH9) {
        if (isMainnet(network)) return IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        if (isOptimism(network) || isBase(network)) return IWETH9(0x4200000000000000000000000000000000000006);
        if (isArbitrum(network)) return IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        revert("Unknown native token");
    }

}

using NetworkLib for Network global;
