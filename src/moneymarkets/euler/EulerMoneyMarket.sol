//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { ACCOUNT_BALANCE, DEBT_BALANCE, COLLATERAL_BALANCE, WAD, RAY } from "../../constants.sol";
import { ERC20Lib } from "../../libraries/ERC20Lib.sol";
import { IEthereumVaultConnector } from "./dependencies/IEthereumVaultConnector.sol";
import { IEulerVault } from "./dependencies/IEulerVault.sol";
import { BytesLib } from "../../libraries/BytesLib.sol";

/// @custom:security-contact security@contango.xyz
contract EulerMoneyMarket {

    using ERC20Lib for IERC20;
    using BytesLib for bytes;

    error VaultAssetMismatch();

    event EulerSupply(IEulerVault indexed vault, IERC20 indexed asset, uint256 amount, uint256 shares, uint256 index);
    event EulerBorrow(IEulerVault indexed vault, IERC20 indexed asset, uint256 amount, uint256 index, address to);
    event EulerRepay(IEulerVault indexed vault, IERC20 indexed asset, uint256 amount, uint256 index);
    event EulerWithdraw(IEulerVault indexed vault, IERC20 indexed asset, uint256 amount, uint256 shares, uint256 index, address to);
    event EulerFlashBorrow(IEulerVault indexed vault, IERC20 indexed asset, uint256 amount, address fundsReceiver);
    event EulerFlashWithdraw(IEulerVault indexed vault, IERC20 indexed asset, uint256 amount, address fundsReceiver);

    IERC20 public constant USD = IERC20(0x0000000000000000000000000000000000000348);

    address private immutable SELF = address(this);

    /**
     * @notice Supplies tokens to an Euler vault.
     * @param amount The amount of tokens to supply. Use `ACCOUNT_BALANCE` for the entire balance.
     * @param asset The ERC20 token to supply (must match the vault's asset).
     * @param vault The Euler vault.
     * @return supplied The actual amount of tokens supplied.
     */
    function supply(uint256 amount, IERC20 asset, IEulerVault vault) public returns (uint256 supplied) {
        vault.validateAsset(asset);
        if (amount == ACCOUNT_BALANCE) amount = asset.myBalance();
        if (amount == 0) return 0;

        asset.forceApprove(address(vault), amount);
        uint256 shares = vault.deposit(amount, address(this));
        supplied = vault.convertToAssets(shares);

        emit EulerSupply(vault, asset, supplied, shares, vault.supplyIndex());
    }

    /**
     * @notice Borrows tokens from an Euler vault.
     * @param amount The amount of tokens to borrow.
     * @param asset The ERC20 token to borrow (must match the vault's asset).
     * @param to The address that will receive the borrowed tokens.
     * @param vault The Euler vault.
     * @return borrowed The actual amount of tokens borrowed.
     */
    function borrow(uint256 amount, IERC20 asset, address to, IEulerVault vault) public returns (uint256 borrowed) {
        vault.validateAsset(asset);
        if (amount == 0) return 0;

        borrowed = vault.borrow(amount, to);

        emit EulerBorrow(vault, asset, borrowed, vault.interestAccumulator(), to);
    }

    /**
     * @notice Repays a borrow on an Euler vault.
     * @param amount The amount of tokens to repay. Use `ACCOUNT_BALANCE` or `DEBT_BALANCE`.
     * @param asset The ERC20 token to repay.
     * @param vault The Euler vault.
     * @return repaid The actual amount of tokens repaid.
     */
    function repay(uint256 amount, IERC20 asset, IEulerVault vault) public returns (uint256 repaid) {
        vault.validateAsset(asset);
        if (amount == ACCOUNT_BALANCE) amount = asset.myBalance();
        uint256 debt = debtBalance(address(this), asset, vault);
        if (amount == DEBT_BALANCE || amount > debt) amount = debt;
        if (amount == 0) return 0;

        asset.forceApprove(address(vault), amount);
        repaid = vault.repay(amount, address(this));

        emit EulerRepay(vault, asset, repaid, vault.interestAccumulator());
    }

    /**
     * @notice Withdraws tokens from an Euler vault.
     * @param amount The amount of tokens to withdraw. Use `COLLATERAL_BALANCE` for all.
     * @param asset The ERC20 token to withdraw.
     * @param to The address that will receive the withdrawn tokens.
     * @param vault The Euler vault.
     * @return withdrawn The actual amount of tokens withdrawn.
     */
    function withdraw(uint256 amount, IERC20 asset, address to, IEulerVault vault) public returns (uint256 withdrawn) {
        vault.validateAsset(asset);
        if (amount == COLLATERAL_BALANCE) amount = vault.collateralBalanceOf(address(this));
        if (amount == 0) return 0;

        uint256 shares = vault.withdraw(amount, to, address(this));
        withdrawn = vault.convertToAssets(shares);

        emit EulerWithdraw(vault, asset, withdrawn, shares, vault.supplyIndex(), to);
    }

    /**
     * @notice Gets the debt balance of an account in an Euler vault.
     * @param account The account to query.
     * @param asset The asset of the vault.
     * @param vault The Euler vault.
     * @return The current debt balance.
     */
    function debtBalance(address account, IERC20 asset, IEulerVault vault) public view returns (uint256) {
        vault.validateAsset(asset);
        return vault.debtOf(account);
    }

    /**
     * @notice Gets the collateral balance of an account in an Euler vault.
     * @param account The account to query.
     * @param asset The asset of the vault.
     * @param vault The Euler vault.
     * @return The current collateral balance.
     */
    function collateralBalance(address account, IERC20 asset, IEulerVault vault) public view returns (uint256) {
        vault.validateAsset(asset);
        return vault.collateralBalanceOf(account);
    }

    function oraclePrice(IERC20 asset, IEulerVault vault) public view returns (uint256) {
        vault.validateAsset(asset);
        IERC20 unitOfAccount = vault.unitOfAccount();

        return vault.oracle().getQuote(asset.unit(), asset, unitOfAccount);
    }

    function oracleUnit(IEulerVault vault) public view returns (uint256) {
        IERC20 unitOfAccount = vault.unitOfAccount();
        return address(unitOfAccount) == address(USD) ? WAD : unitOfAccount.unit();
    }

    function supplyRate(IERC20, IEulerVault) public pure returns (uint256) {
        revert("not implemented");
    }

    function borrowRate(IERC20, IEulerVault) public pure returns (uint256) {
        revert("not implemented");
    }

    // =============================== Flash Borrowing ===============================

    /**
     * @notice Performs a flash borrow from an Euler vault using the Ethereum Vault Connector (EVC).
     * @dev Executes a `batch` call on the EVC that borrows from the vault and then executes arbitrary data.
     * @dev The `data` layout expected is [20 bytes target + X bytes callData].
     * @param evc The Ethereum Vault Connector contract.
     * @param vault The Euler vault to borrow from.
     * @param amount The amount to borrow.
     * @param data Encoded data for the callback [0:20 bytes target, 20:+ bytes callData].
     */
    function flashBorrow(IEthereumVaultConnector evc, IEulerVault vault, uint256 amount, bytes calldata data) public {
        address account = address(this);

        IEthereumVaultConnector.BatchItem[] memory batchItems = new IEthereumVaultConnector.BatchItem[](2);

        batchItems[0] = IEthereumVaultConnector.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: account,
            value: 0,
            data: abi.encodeCall(IEulerVault.borrow, (amount, account))
        });

        (address target, bytes calldata callData) = data.asFunctionCall();
        batchItems[1] = IEthereumVaultConnector.BatchItem({ targetContract: target, onBehalfOfAccount: account, value: 0, data: callData });

        evc.batch(batchItems);
        emit EulerFlashBorrow(vault, vault.asset(), amount, account);
    }

    /**
     * @notice Performs a flash withdrawal from an Euler vault using the Ethereum Vault Connector (EVC).
     * @dev Executes a `batch` call on the EVC that withdraws from the vault and then executes arbitrary data.
     * @dev The `data` layout expected is [20 bytes target + X bytes callData].
     * @param evc The Ethereum Vault Connector contract.
     * @param vault The Euler vault to withdraw from.
     * @param amount The amount to withdraw. Use `COLLATERAL_BALANCE` for all.
     * @param data Encoded data for the callback [0:20 bytes target, 20:+ bytes callData].
     */
    function flashWithdraw(IEthereumVaultConnector evc, IEulerVault vault, uint256 amount, bytes calldata data) public {
        address account = address(this);
        if (amount == COLLATERAL_BALANCE) amount = vault.collateralBalanceOf(account);

        IEthereumVaultConnector.BatchItem[] memory batchItems = new IEthereumVaultConnector.BatchItem[](2);

        batchItems[0] = IEthereumVaultConnector.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: account,
            value: 0,
            data: abi.encodeCall(IEulerVault.withdraw, (amount, account, account))
        });

        (address target, bytes calldata callData) = data.asFunctionCall();
        batchItems[1] = IEthereumVaultConnector.BatchItem({ targetContract: target, onBehalfOfAccount: account, value: 0, data: callData });

        evc.batch(batchItems);
        emit EulerFlashWithdraw(vault, vault.asset(), amount, account);
    }

}

library EulerMoneyMarketLib {

    function supplyIndex(IEulerVault vault) internal view returns (uint256) {
        uint256 shares = vault.totalSupply();
        if (shares == 0) return 0;

        uint256 assets = vault.totalAssets();
        return Math.mulDiv(assets, RAY, shares);
    }

    function collateralBalanceOf(IEulerVault vault, address account) internal view returns (uint256) {
        return vault.convertToAssets(vault.balanceOf(account));
    }

    function validateAsset(IEulerVault vault, IERC20 asset) internal view {
        if (address(vault.asset()) != address(asset)) revert EulerMoneyMarket.VaultAssetMismatch();
    }

}

using EulerMoneyMarketLib for IEulerVault;
