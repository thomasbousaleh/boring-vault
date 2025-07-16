// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

/// @notice Interface for call-data sanitizers used by ManagerWithMerkleVerification
interface ICallDataSanitizer {
    /// @notice Checks and (optionally) transforms raw calldata before execution
    /// @param data The raw calldata to sanitize
    /// @return The sanitized calldata (must match the payload for identity)
    function sanitize(bytes calldata data) external view returns (bytes memory);
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

/// @title StHYPE-Loop & BTC-Carry Combined Decoder/Sanitizer
/// @dev Registers as a single decoder with ManagerWithMerkleVerification
contract StHYPELoopDecoderAndSanitizer is BaseDecoderAndSanitizer, ICallDataSanitizer {

    /* ──────────────────────────────────────── StHYPE Loop (no-op) ─────────────────────────────────────── */

    error StHYPELoopDecoderAndSanitizer__CallbackNotSupported();

    /// @notice Extracts address touched by mint call for whitelist check
    /// @dev For StHYPE Loop we don’t need to mutate or inspect calldata,
    ///      so we simply echo it back unchanged.
    // Add anywhere inside the contract
    function sanitize(bytes calldata data)
        external
        pure
        override(ICallDataSanitizer)
        returns (bytes memory)
    {
        return data;
    }

    function withdraw(uint256) external pure returns (bytes memory) {
        return abi.encodePacked(); // No address to whitelist, but needed for Manager compatibility
    }

    function mint(address to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(to);
    }

    function supplyCollateral(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (bytes memory addressesFound) {
        // Sanitize raw data
        if (data.length > 0) revert StHYPELoopDecoderAndSanitizer__CallbackNotSupported();

        // Return addresses found
        addressesFound = abi.encodePacked(params.loanToken, params.collateralToken, params.oracle, params.irm, onBehalf);
    }

    function borrow(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (bytes memory addressesFound) {
        addressesFound =
            abi.encodePacked(params.loanToken, params.collateralToken, params.oracle, params.irm, onBehalf, receiver);
    }

    /* ─────────────────────────────────────── BTC-Carry helper enums ──────────────────────────────────── */

    enum HyperliquidOperation {
        DepositUSDC,
        SendVaultTransfer,
        SendTokenDelegate,
        SendSpot,
        SendIocOrder,
        SendCDeposit,
        SendCWithdrawal,
        SendUsdClassTransfer
    }

    enum FelixOperation {
        CreateTrove,
        AddColl,
        WithdrawColl,
        WithdrawBold,
        RepayBold,
        CloseTrove,
        AdjustTrove,
        ApplyPendingDebt,
        ClaimCollateral,
        Shutdown
    }

    /* ───────────────────────────────────── BTC-Carry address extractors ───────────────────────────────── */

    // openTrove: owner, addManager, removeManager, receiver
    function openTrove(
        address owner,
        uint256,          /* ownerIndex      */
        uint256,          /* ETHAmount       */
        uint256,          /* boldAmount      */
        uint256,          /* upperHint       */
        uint256,          /* lowerHint       */
        uint256,          /* annualInterestRate */
        uint256,          /* maxUpfrontFee   */
        address addManager,
        address removeManager,
        address receiver
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(owner, addManager, removeManager, receiver);
    }

    /*  Every helper below either packs specific addresses or, when no address params
        exist, returns an empty bytes array.  Nothing else changed from your original file. */

    function addColl(uint256, uint256) external pure returns (bytes memory) { return abi.encodePacked(); }

    function withdrawColl(uint256, uint256) external pure returns (bytes memory) { return abi.encodePacked(); }

    function withdrawBold(uint256, uint256, uint256) external pure returns (bytes memory) { return abi.encodePacked(); }

    function repayBold(uint256, uint256) external pure returns (bytes memory) { return abi.encodePacked(); }

    function closeTrove(uint256) external pure returns (bytes memory) { return abi.encodePacked(); }

    function adjustTrove(uint256, uint256, bool, uint256, bool, uint256)
        external pure returns (bytes memory) { return abi.encodePacked(); }

    function applyPendingDebt(uint256, uint256, uint256)
        external pure returns (bytes memory) { return abi.encodePacked(); }

    function claimCollateral() external pure returns (bytes memory) { return abi.encodePacked(); }

    function shutdown() external pure returns (bytes memory) { return abi.encodePacked(); }

    function exchange(int128, int128, uint256, uint256)
        external pure returns (bytes memory) { return ""; }

    // Hyperliquid helpers
    function sendVaultTransfer(address vault, bool, uint64)
        external pure returns (bytes memory) { return abi.encodePacked(vault); }

    function sendTokenDelegate(address validator, uint64, bool)
        external pure returns (bytes memory) { return abi.encodePacked(validator); }

    function sendSpot(address destination, uint64, uint64)
        external pure returns (bytes memory) { return abi.encodePacked(destination); }

    function sendIocOrder(uint16, bool, uint64, uint64)
        external pure returns (bytes memory) { return abi.encodePacked(); }

    function sendCDeposit(uint64) external pure returns (bytes memory) { return abi.encodePacked(); }

    function sendCWithdrawal(uint64) external pure returns (bytes memory) { return abi.encodePacked(); }

    function sendUsdClassTransfer(uint64, bool)
        external pure returns (bytes memory) { return abi.encodePacked(); }
}