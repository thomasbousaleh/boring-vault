// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/* solhint-disable no-console */
import {Script, console} from "forge-std/Script.sol";
import {stdStorage, StdStorage} from "@forge-std/Test.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";

// Interfaces for strategy execution
interface IHyperliquidVault {
    function getVaultBalance(address account) external view returns (uint256);
    function sendVaultTransfer(address target, bool isDeposit, uint64 amount) external;
}

contract StHypeLoopBase is Script, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // Common variables
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    
    // Variables for merkle proofs
    bytes32[] public manageRoot;

    // Storage variables for execution
    bytes32[][] internal manageProofs;
    address[] internal targets;
    bytes[] internal targetData;
    address[] internal decodersAndSanitizers;
    uint256[] internal valueAmounts;
    
    // Deploy using a private key from environment
    function getPrivateKey() internal view returns (uint256) {
        return vm.envUint("BORING_DEVELOPER");
    }
    
    // Initialize chain-specific values
    function initChainSetup() internal {
        // Set source chain to "hyperliquid"
        sourceChain = "hyperliquid";
    }
    
    // Load deployed contracts
    function loadDeployedContracts() internal {
        // Load addresses of deployed contracts
        address managerAddress = 0x37a76F45f76DDd5E512533975Aa12ABB352b4e04;
        address boringVaultAddress = 0x486367D6aBEe6dB736aa193d9e3B3cd94b865B76;
        address rolesAuthorityAddress = 0x01415E10bEDe2dEC8e60D3a1Ea741C41ceaF3E2a;
        
        manager = ManagerWithMerkleVerification(managerAddress);
        boringVault = BoringVault(payable(boringVaultAddress));
        rolesAuthority = RolesAuthority(rolesAuthorityAddress);
        rawDataDecoderAndSanitizer = 0x831D9337Eb3926A3C1869145C967E3B9Ec4d24A0;
        setAddress(true, sourceChain, "boringVault", boringVaultAddress);
        setAddress(true, sourceChain, "rolesAuthority", rolesAuthorityAddress);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
    }
    
    // Helper functions for generating merkle proofs
    function setupMerkleProofs() internal {
        // Reset leaf index in MerkleTreeHelper
        resetLeafIndex();
        
        // Setup merkle tree
        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        
        // Generate the usual leafs without modifying anything
        _addFelixLeafs(leafs);
        _addHyperliquidLeafs(leafs);
        
        console.logString("leafs generated");
        
        // Generate the merkle tree 
        bytes32[][] memory merkleTree = _generateMerkleTree(leafs);
        
        console.log("Manager address:", address(manager));
        console.log("Signer:", vm.addr(getPrivateKey()));

        // Only set manage root if manager is initialized
        if (address(manager) != address(0)) {
            uint256 pk = getPrivateKey();
            vm.startBroadcast(pk);
            manager.setManageRoot(address(0x5FB7587be4c51E56163e4A2ee1E9393DC2d1a361), merkleTree[merkleTree.length - 1][0]);
            vm.stopBroadcast();
            console.logString("manageRoot set");
        }

        // Choose the specific leafs we want to use 
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[0]; // WBTC approval
        manageLeafs[1] = leafs[1]; // WHYPE approval
        manageLeafs[2] = leafs[2]; // openTrove
        manageLeafs[3] = leafs[12]; // hlp transfer       
        manageLeafs[4] = leafs[19]; // hlp class transfer
        manageLeafs[5] = leafs[13]; // hlp deposit
        
        manageProofs = _getProofsUsingTree(manageLeafs, merkleTree);
        console.logString("manageProofs generated");

        targets = new address[](8);
        targets[0] = manageLeafs[0].target;
        targets[1] = manageLeafs[1].target;
        targets[2] = manageLeafs[2].target;
        targets[3] = manageLeafs[3].target;
        targets[4] = manageLeafs[4].target;
        targets[5] = manageLeafs[5].target;

        targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "WBTC_borrowerOperations"), 
            type(uint256).max
        );
        
        // Add WHYPE approval
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "WBTC_borrowerOperations"), 
            type(uint256).max
        );

        // Use exact decoders from the leafs 
        decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = manageLeafs[0].decoderAndSanitizer;
        decodersAndSanitizers[1] = manageLeafs[1].decoderAndSanitizer;
        decodersAndSanitizers[2] = manageLeafs[2].decoderAndSanitizer;
        decodersAndSanitizers[3] = manageLeafs[3].decoderAndSanitizer;
        decodersAndSanitizers[4] = manageLeafs[4].decoderAndSanitizer;
        decodersAndSanitizers[5] = manageLeafs[5].decoderAndSanitizer;

        valueAmounts = new uint256[](8);
        valueAmounts[0] = manageLeafs[0].canSendValue ? 1 : 0; // WBTC approval
        valueAmounts[1] = manageLeafs[1].canSendValue ? 1 : 0; // WHYPE approval
        valueAmounts[2] = manageLeafs[2].canSendValue ? 1 : 0; // openTrove
        valueAmounts[3] = manageLeafs[3].canSendValue ? 1 : 0; // hlp transfer
        valueAmounts[4] = manageLeafs[4].canSendValue ? 1 : 0; // hlp class transfer
        valueAmounts[5] = manageLeafs[5].canSendValue ? 1 : 0; // hlp deposit
    }

    /**
     * @notice Reset leaf index in MerkleTreeHelper
     * @dev Added to avoid index overflow issues
     */
    function resetLeafIndex() internal {
        leafIndex = type(uint256).max;
    }

    /**
     * @notice Log token balances
     * @dev Helper function to print current token balances
     */
    function logTokenBalances(string memory /*context*/) internal view {
        ERC20 wBTC = ERC20(getAddress(sourceChain, "WBTC"));
        ERC20 feUSD = ERC20(getAddress(sourceChain, "feUSD"));
        ERC20 usdc = ERC20(getAddress(sourceChain, "USDC"));
        console.logString("Token balances:");
        console.logUint(wBTC.balanceOf(address(boringVault)));
        console.logUint(feUSD.balanceOf(address(boringVault)));
        console.logUint(usdc.balanceOf(address(boringVault)));
    }
    
    /**
     * @notice Log error data
     * @dev Helper function to print error data
     */
    function logError(bytes memory errorData) internal view virtual {
        if (errorData.length >= 4) {
            bytes4 errorSelector = bytes4(errorData);
            console.logString("Error selector:");
            console.logBytes4(errorSelector);
        }
    }
    
    /**
     * @notice Simple helper to ask for user confirmation
     * @dev In a real implementation, this would wait for user input
     */
    function askUserToConfirm(string memory message) internal view virtual returns (bool) {
        console.logString("CONFIRMATION REQUIRED:");
        console.logString(message);
        return true; // Auto-confirm for now
    }
}