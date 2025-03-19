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
    address public boringVault = 0x208EeF7B7D1AcEa7ED4964d3C5b0c194aDf17412;
    address public managerAddress = 0x97b087906781D9CBf1a22E7B3e4Af3c7e4802AC4;
    address public accountantAddress = 0x567fca0423b8fb84E151Cd2fA954555D2323622e;
    address public rawDataDecoderAndSanitizer = 0x831D9337Eb3926A3C1869145C967E3B9Ec4d24A0;

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

        // Add feUSD approval and curve swap leaves
        uint feUSDApprovalIndex = 20; 
        leafs[feUSDApprovalIndex] = ManageLeaf(
            getAddress(sourceChain, "feUSD"), 
            false, 
            "approve(address,uint256)", 
            new address[](1), 
            string.concat("Approve Curve pool to spend feUSD"), 
            getAddress(sourceChain, "rawDataDecoderAndSanitizer") 
        );
        leafs[feUSDApprovalIndex].argumentAddresses[0] = getAddress(sourceChain, "curveUsdcFeUSDPool");
        
        uint curveSwapIndex = 21; 
        leafs[curveSwapIndex] = ManageLeaf(
            getAddress(sourceChain, "curveUsdcFeUSDPool"), 
            false, 
            "exchange(int128,int128,uint256,uint256)", 
            new address[](0), 
            string.concat("Swap feUSD to USDC using Curve pool with fixed amount"), 
            getAddress(sourceChain, "rawDataDecoderAndSanitizer") 
        );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Hyperliquid/hyperBtcCarryAdminLeafs.json";
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
} 