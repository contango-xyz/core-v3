//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { Action, PackedAction } from "../src/types/Action.sol";

library ActionLib {

    using SafeCast for *;

    function action(address target, bytes memory data) internal pure returns (Action memory action_) {
        action_.target = target;
        action_.data = data;
    }

    function delegateAction(address target, bytes memory data) internal pure returns (Action memory action_) {
        action_ = action(target, data);
        action_.delegateCall = true;
    }

    function pack(Action memory _action) internal pure returns (PackedAction memory packedAction_) {
        packedAction_.data =
            abi.encodePacked(_action.target, _action.value.toUint96(), _action.delegateCall, _action.allowFailure, _action.data);
    }

    function pack(Action[] memory actions) internal pure returns (PackedAction[] memory packedActions_) {
        packedActions_ = new PackedAction[](actions.length);
        for (uint256 i = 0; i < actions.length; i++) {
            packedActions_[i] = pack(actions[i]);
        }
    }

}
