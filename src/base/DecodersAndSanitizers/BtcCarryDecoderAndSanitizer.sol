// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

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

contract BtcCarryDecoderAndSanitizer is BaseDecoderAndSanitizer {

    // Extract addresses for openTrove for BTC carry strategy using individual parameters
    function openTrove(
        address owner,
        uint256,  // ownerIndex
        uint256,  // ETHAmount
        uint256,  // boldAmount
        uint256,  // upperHint
        uint256,  // lowerHint
        uint256,  // annualInterestRate
        uint256,  // maxUpfrontFee
        address addManager,
        address removeManager,
        address receiver
    )
        external
        pure
        returns (bytes memory addressesFound)
    {
        // For openTrove, we extract the addresses: owner, addManager, removeManager, and receiver
        addressesFound = abi.encodePacked(owner, addManager, removeManager, receiver);
    }

    // For the functions below, no address parameters exist so we return an empty bytes array.

    function addColl(uint256, uint256)  // troveId, ETHAmount
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function withdrawColl(uint256, uint256)  // troveId, amount
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function withdrawBold(uint256, uint256, uint256)  // troveId, amount, maxUpfrontFee
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function repayBold(uint256, uint256)  // troveId, amount
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function closeTrove(uint256)  // troveId
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function adjustTrove(
        uint256,  // troveId
        uint256,  // collChange
        bool,     // isCollIncrease
        uint256,  // debtChange
        bool,     // isDebtIncrease
        uint256   // maxUpfrontFee
    )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function applyPendingDebt(uint256, uint256, uint256)  // troveId, lowerHint, upperHint
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function claimCollateral()
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function shutdown()
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function exchange(int128, int128, uint256, uint256) 
        external 
        pure  
        returns (bytes memory addressesFound) 
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // For sendVaultTransfer: extract the vault address
    function sendVaultTransfer(address vault, bool, uint64)  // isDeposit, usd
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vault);
    }

    // For sendTokenDelegate: extract the validator address
    function sendTokenDelegate(address validator, uint64, bool)  // _wei, isUndelegate
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(validator);
    }

    // For sendSpot: extract the destination address
    function sendSpot(address destination, uint64, uint64)  // token, _wei
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(destination);
    }

    // For sendIocOrder: no address parameters, so return empty bytes
    function sendIocOrder(uint16, bool, uint64, uint64)  // perp, isBuy, limitPx, sz
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    // For sendCDeposit: no address parameters, so return empty bytes
    function sendCDeposit(uint64)  // _wei
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    // For sendCWithdrawal: no address parameters, so return empty bytes
    function sendCWithdrawal(uint64)  // _wei
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    // For sendUsdClassTransfer: no address parameters, so return empty bytes
    function sendUsdClassTransfer(uint64, bool)  // ntl, toPerp
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }
} 