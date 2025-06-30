// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/// @title CreateStHYPELoopingMerkleRoot
/// @notice Generates a Merkle tree/JSON for the stHYPE looping strategy on Hyperliquid.
contract CreateStHYPELoopingMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // ---------------------------------------------------------------------
    // Immutable addresses for Hyperliquid deployment (configure as needed)
    // ---------------------------------------------------------------------
    address public constant boringVault       = 0x7375d28EB27c05B8248d6f507AEEBf5d97a4C50E;
    address public constant managerAddress    = 0x5FB7587be4c51E56163e4A2ee1E9393DC2d1a361;
    address public constant accountantAddress = 0x567fca0423b8fb84E151Cd2fA954555D2323622e;
    address public constant decoder           = 0x831D9337Eb3926A3C1869145C967E3B9Ec4d24A0;

    // ---------------------------------------------------------------------
    // Entry point
    // ---------------------------------------------------------------------
    function run() external {
        generateStHYPELoopMerkleRoot();
    }

    // ---------------------------------------------------------------------
    // Core logic
    // ---------------------------------------------------------------------
    function generateStHYPELoopMerkleRoot() public {
        // `hyperliquid` is assumed to be a string constant supplied by MerkleTreeHelper
        setSourceChainName(hyperliquid);
        setAddress(false, hyperliquid, "boringVault",       boringVault);
        setAddress(false, hyperliquid, "managerAddress",    managerAddress);
        setAddress(false, hyperliquid, "accountantAddress", accountantAddress);
        setAddress(false, hyperliquid, "decoder",           decoder);

        uint256 i;
        ManageLeaf[] memory leafs = new ManageLeaf[](64); // plenty of room

        // Custom helpers (provided by MerkleTreeHelper)
        _addFelixLeafs(leafs);
        _addHyperliquidLeafs(leafs);

        // 1. Approve wHYPE -> stHYPE staking
        leafs[i] = ManageLeaf(
            getAddress(hyperliquid, "wHYPE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve stHYPE staking contract to spend wHYPE",
            decoder
        );
        leafs[i++].argumentAddresses[0] = getAddress(hyperliquid, "stHYPEStaking");

        // 2. Stake wHYPE into stHYPE
        leafs[i++] = ManageLeaf(
            getAddress(hyperliquid, "stHYPEStaking"),
            false,
            "stake(uint256)",
            new address[](0),
            "Stake wHYPE into stHYPE",
            decoder
        );

        // 3. Approve stHYPE to Felix
        leafs[i] = ManageLeaf(
            getAddress(hyperliquid, "stHYPE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Felix market to spend stHYPE",
            decoder
        );
        leafs[i++].argumentAddresses[0] = getAddress(hyperliquid, "FelixVanillaMarket");

        // 4. Supply stHYPE as collateral
        leafs[i++] = ManageLeaf(
            getAddress(hyperliquid, "FelixVanillaMarket"),
            false,
            "supplyCollateral(uint256)",
            new address[](0),
            "Supply stHYPE as collateral",
            decoder
        );

        // 5. Borrow HYPE from Felix
        leafs[i++] = ManageLeaf(
            getAddress(hyperliquid, "FelixVanillaMarket"),
            false,
            "borrow(uint256)",
            new address[](0),
            "Borrow HYPE",
            decoder
        );

        // 6. Approve HYPE to wHYPE wrapper
        leafs[i] = ManageLeaf(
            getAddress(hyperliquid, "HYPE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve wrapper to wrap HYPE",
            decoder
        );
        leafs[i++].argumentAddresses[0] = getAddress(hyperliquid, "wHYPEWrapper");

        // 7. Wrap HYPE to wHYPE
        leafs[i++] = ManageLeaf(
            getAddress(hyperliquid, "wHYPEWrapper"),
            false,
            "wrap(uint256)",
            new address[](0),
            "Wrap HYPE to wHYPE",
            decoder
        );

        // ------------------------------------------------------------------
        // Final verification & file output
        // ------------------------------------------------------------------
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory tree = _generateMerkleTree(leafs);
        _generateLeafs(
            "./leafs/Hyperliquid/stHYPELoopingMerkleTree.json",
            leafs,
            tree[tree.length - 1][0],
            tree
        );
    }
}