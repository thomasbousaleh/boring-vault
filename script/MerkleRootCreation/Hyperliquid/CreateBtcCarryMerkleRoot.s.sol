// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

contract CreateBtcCarryMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // Updated common addresses for Hyperliquid testnet
    address public boringVault = 0x1111111111111111111111111111111111111111;
    address public managerAddress = 0x2222222222222222222222222222222222222222;
    address public accountantAddress = 0x3333333333333333333333333333333333333333;
    address public rawDataDecoderAndSanitizer = 0x4444444444444444444444444444444444444444;

    // Added swap contract address for btc carry strategy
    address public swap = 0x9999999999999999999999999999999999999999;

    function setUp() external {}

    function run() external {
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(hyperliquid);
        setAddress(false, hyperliquid, "boringVault", boringVault);
        setAddress(false, hyperliquid, "managerAddress", managerAddress);
        setAddress(false, hyperliquid, "accountantAddress", accountantAddress);
        setAddress(false, hyperliquid, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // Initialize leaf array
        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // Add Felix leaves
        _addFelixLeafs(leafs);

        // Add Hyperliquid leaves
        _addHyperliquidLeafs(leafs);

        // Add swap leaf
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            swap,
            false,
            "swap(uint256)",
            new address[](0),
            "BTC Carry: perform swap",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Hyperliquid/hyperBtcCarryAdminLeafs.json";
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
} 