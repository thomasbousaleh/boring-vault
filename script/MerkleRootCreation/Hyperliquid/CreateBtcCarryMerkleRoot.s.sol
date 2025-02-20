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

    // Updated Hyperliquid related addresses (dummy testnet values)
    address public hyperVault = 0x5555555555555555555555555555555555555555;
    address public hyperValidator = 0x6666666666666666666666666666666666666666;
    address public hyperDestination = 0x7777777777777777777777777777777777777777;
    address public hyperliquidL1DecoderAndSanitizer = 0x8888888888888888888888888888888888888888;

    // Updated Felix related addresses (dummy testnet values)
    address public felixOwner = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address public felixAddManager = 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC;
    address public felixRemoveManager = 0x00D0d0d0D0d0D0d0D0D0d0d0D0d0d0D0D0d0d0d0;
    address public felixReceiver = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public felixInterestBatchManager = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
    address public felixDelegate = 0x009a9a9A9A9A9a9A9a9a9A9a9a9a9a9A9A9a9A9a;
    address public felixDecoderAndSanitizer = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;

    // Added swap contract address for btc carry strategy
    address public swap = 0x9999999999999999999999999999999999999999;

    function setUp() external {}

    function run() external {
        generateBtcCarryMerkleRoot();
    }

    function generateBtcCarryMerkleRoot() public {
        // Updated source chain name to "hyperliquid"
        setSourceChainName("hyperliquid");
        setAddress(false, "hyperliquid", "boringVault", boringVault);
        setAddress(false, "hyperliquid", "managerAddress", managerAddress);
        setAddress(false, "hyperliquid", "accountantAddress", accountantAddress);
        setAddress(false, "hyperliquid", "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, "hyperliquid", "L1Write", 0x1234123412341234123412341234123412341234);
        setAddress(false, "hyperliquid", "hyperliquidL1DecoderAndSanitizer", hyperliquidL1DecoderAndSanitizer);
        setAddress(false, "hyperliquid", "felixDecoderAndSanitizer", felixDecoderAndSanitizer);
        setAddress(false, "hyperliquid", "IBorrowerOperations", 0x9876987698769876987698769876987698769876);

        // Allocate leaves for btc carry strategy: Felix, Swap, and Hyperliquid
        MerkleTreeHelper.ManageLeaf[] memory leafs = new MerkleTreeHelper.ManageLeaf[](3);

        // Felix leaf via helper
        _addFelixLeafs(leafs, FelixOperation.CreateTrove, felixOwner, felixAddManager, felixRemoveManager, felixReceiver, felixInterestBatchManager, felixDelegate);

        // Swap leaf manually
        leafs[1] = MerkleTreeHelper.ManageLeaf(swap, false, "swapFeUSDToUSDC(uint256)", new address[](0), "Swap feUSD to USDC", address(0));

        // Hyperliquid leaf via helper
        _addHyperliquidLeafs(leafs, HyperliquidOperation.DepositUSDC, hyperVault, hyperValidator, hyperDestination);

        string memory filePath = "./BtcCarryMerkleRoot.json";
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
} 