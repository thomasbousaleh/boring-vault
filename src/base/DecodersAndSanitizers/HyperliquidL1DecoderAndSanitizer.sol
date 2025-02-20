// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract HyperliquidL1DecoderAndSanitizer is BaseDecoderAndSanitizer {
    // For sendVaultTransfer: extract the vault address
    function sendVaultTransfer(address vault, bool /*isDeposit*/, uint64 /*usd*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vault);
    }

    // For sendTokenDelegate: extract the validator address
    function sendTokenDelegate(address validator, uint64 /*_wei*/, bool /*isUndelegate*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(validator);
    }

    // For sendSpot: extract the destination address
    function sendSpot(address destination, uint64 /*token*/, uint64 /*_wei*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(destination);
    }

    // For sendIocOrder: no address parameters, so return empty bytes
    function sendIocOrder(uint16 /*perp*/, bool /*isBuy*/, uint64 /*limitPx*/, uint64 /*sz*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    // For sendCDeposit: no address parameters, so return empty bytes
    function sendCDeposit(uint64 /*_wei*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    // For sendCWithdrawal: no address parameters, so return empty bytes
    function sendCWithdrawal(uint64 /*_wei*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }

    // For sendUsdClassTransfer: no address parameters, so return empty bytes
    function sendUsdClassTransfer(uint64 /*ntl*/, bool /*toPerp*/)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked();
    }
} 