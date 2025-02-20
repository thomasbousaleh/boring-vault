// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract FelixDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // Extract addresses for openTrove for BTC carry strategy using individual parameters
    function openTrove(
        address owner,
        uint256 ownerIndex,
        uint256 ETHAmount,
        uint256 boldAmount,
        uint256 upperHint,
        uint256 lowerHint,
        uint256 annualInterestRate,
        uint256 maxUpfrontFee,
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

    function addColl(uint256 troveId, uint256 ETHAmount)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function withdrawColl(uint256 troveId, uint256 amount)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function withdrawBold(uint256 troveId, uint256 amount, uint256 maxUpfrontFee)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function repayBold(uint256 troveId, uint256 amount)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function closeTrove(uint256 troveId)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function adjustTrove(
        uint256 troveId,
        uint256 collChange,
        bool isCollIncrease,
        uint256 debtChange,
        bool isDebtIncrease,
        uint256 maxUpfrontFee
    )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    function applyPendingDebt(uint256 troveId, uint256 lowerHint, uint256 upperHint)
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
} 