// SPDX-License-Identifier: CC0
pragma solidity >=0.6.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Specification for flash lenders compatible with ERC-7399
interface IERC7399 {

    /// @dev The amount of currency available to be lent.
    /// @param asset The loan currency.
    /// @return The amount of `asset` that can be borrowed.
    function maxFlashLoan(IERC20 asset) external view returns (uint256);

    /// @dev The fee to be charged for a given loan.
    /// @param asset The loan currency.
    /// @param amount The amount of assets lent.
    /// @return The amount of `asset` to be charged for the loan, on top of the returned principal.
    function flashFee(IERC20 asset, uint256 amount) external view returns (uint256);

    /// @dev Initiate a flash loan.
    /// @param loanReceiver The address receiving the flash loan
    /// @param asset The asset to be loaned
    /// @param amount The amount to loaned
    /// @param data The ABI encoded user data
    /// @param callback The address and signature of the callback function
    /// @return result ABI encoded result of the callback
    function flash(
        address loanReceiver,
        IERC20 asset,
        uint256 amount,
        bytes calldata data,
        /// @dev callback. This is a combination of the callback receiver address, and the signature of callback
        /// function. It is encoded packed as 20 bytes + 4 bytes.
        /// @dev the return of the callback function is not encoded in the parameter, but must be `returns (bytes
        /// memory)` for compliance with the standard.
        /// @param initiator The address that called this function
        /// @param paymentReceiver The address that needs to receive the amount plus fee at the end of the callback
        /// @param asset The asset to be loaned
        /// @param amount The amount to loaned
        /// @param fee The fee to be paid
        /// @param data The ABI encoded data to be passed to the callback
        /// @return result ABI encoded result of the callback
        function(address, address, IERC20, uint256, uint256, bytes memory) external returns (bytes memory) callback
    ) external returns (bytes memory);

}
