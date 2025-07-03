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
    address[] internal args;
    
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
        address managerAddress = 0x2405e2e378cD0C932D3f112735Ba61435f724433;
        address boringVaultAddress = 0xE2Ab074556a97EC8691cC881Ec69a60ceacfF132;
        address rolesAuthorityAddress = 0x24C3FE2C3bB6864CF7F54Bb0bCa02eB7047aA3e6;
        
        manager = ManagerWithMerkleVerification(managerAddress);
        boringVault = BoringVault(payable(boringVaultAddress));
        rolesAuthority = RolesAuthority(rolesAuthorityAddress);
        rawDataDecoderAndSanitizer = 0x8d6eD169E736F5dD583059243f29e326532fF0E2;
        setAddress(true, sourceChain, "boringVault", boringVaultAddress);
        setAddress(true, sourceChain, "rolesAuthority", rolesAuthorityAddress);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(true, "hyperliquid", "Overseer", 0xB96f07367e69e86d6e9C3F29215885104813eeAE);
        setAddress(true, sourceChain, "wHYPE", 0x5555555555555555555555555555555555555555);
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

        uint8 WHYPE_UNWRAP_INDEX = 22;
        leafs[WHYPE_UNWRAP_INDEX] = ManageLeaf(
            getAddress(sourceChain, "wHYPE"),
            false, // canSendValue doesn't matter for this
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wHYPE into native HYPE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        uint256 unwrapAmount = ERC20(getAddress(sourceChain, "wHYPE")).balanceOf(address(boringVault));
        console.log("Unwrap amount:", unwrapAmount);

        uint8 sthypeMintIndex = 23;
        leafs[sthypeMintIndex] = ManageLeaf(
            getAddress(sourceChain, "Overseer"), // target
            true,                                // canSendValue
            "mint(address)",              // function signature
            new address[](1),                    // argumentAddresses
            "Stake HYPE into stHYPE via Overseer", // description
            rawDataDecoderAndSanitizer // deployed decoder
        );
        
        leafs[sthypeMintIndex].argumentAddresses[0] = address(boringVault);

        console.logString("leafs generated");
        
        // Generate the merkle tree 
        bytes32[][] memory merkleTree = _generateMerkleTree(leafs);

        /*
        for (uint256 level = 0; level < merkleTree.length; level++) {
            for (uint256 i = 0; i < merkleTree[level].length; i++) {
            console.log("Tree[%s][%s]:", level, i);
            console.logBytes32(merkleTree[level][i]);
                }
        }
        */

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
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[WHYPE_UNWRAP_INDEX]; // unwrap first
        manageLeafs[1] = leafs[sthypeMintIndex];

        manageProofs = _getProofsUsingTree(manageLeafs, merkleTree);
        console.logString("manageProofs generated");

        targets = new address[](2);
        targets[0] = manageLeafs[0].target;
        targets[1] = manageLeafs[1].target;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", unwrapAmount);
        targetData[1] = abi.encodeWithSignature("mint(address)", address(boringVault));

        // Use exact decoders from the leafs 
        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = address(rawDataDecoderAndSanitizer); // For withdraw
        decodersAndSanitizers[1] = address(rawDataDecoderAndSanitizer); // For mint

        valueAmounts = new uint256[](2);
        valueAmounts[0] = 0;
        valueAmounts[1] = unwrapAmount;
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