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
import {IMorpho} from "./interfaces/IMorpho.sol";

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
    IMorpho public morpho;

    // Helper struct
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    
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
        address morphoAddress = 0x68e37dE8d93d3496ae143F2E900490f6280C57cD;

        manager = ManagerWithMerkleVerification(managerAddress);
        boringVault = BoringVault(payable(boringVaultAddress));
        rolesAuthority = RolesAuthority(rolesAuthorityAddress);
        rawDataDecoderAndSanitizer = 0xdA62790BD3A2bb957C9B00b00EC0c860418AA487;
        morpho = IMorpho(morphoAddress);
        setAddress(true, sourceChain, "boringVault", boringVaultAddress);
        setAddress(true, sourceChain, "rolesAuthority", rolesAuthorityAddress);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(true, sourceChain, "morpho", morphoAddress);
        setAddress(true, "hyperliquid", "Overseer", 0xB96f07367e69e86d6e9C3F29215885104813eeAE);
        setAddress(true, sourceChain, "wHYPE", 0x5555555555555555555555555555555555555555);
        setAddress(true, sourceChain, "wstHYPE", 0x94e8396e0869c9F2200760aF0621aFd240E1CF38);
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

        uint8 approveIndex = 24;
        leafs[approveIndex] = ManageLeaf(
            getAddress(sourceChain, "wstHYPE"), // target
            false,
            "approve(address,uint256)",         // function signature
            new address[](1),                   // argumentAddresses
            "Approve FelixMarket to spend wstHYPE from Vault",
            rawDataDecoderAndSanitizer
        );

        leafs[approveIndex].argumentAddresses[0] = 0x68e37dE8d93d3496ae143F2E900490f6280C57cD; // FelixMarket

        console.log("wstHYPE:", ERC20(getAddress(sourceChain, "wstHYPE")).balanceOf(address(boringVault)));

        MarketParams memory depositParams = MarketParams({
            loanToken:      0x5555555555555555555555555555555555555555,
            collateralToken:0x94e8396e0869c9F2200760aF0621aFd240E1CF38,
            oracle:         0xD767818Ef397e597810cF2Af6b440B1b66f0efD3,
            irm:            0xD4a426F010986dCad727e8dd6eed44cA4A9b7483,
            lltv:           860000000000000000
        });

        uint256 depositAmount = ERC20(getAddress(sourceChain, "wstHYPE")).balanceOf(address(boringVault))/10;
        console.log("Deposit amount:", depositAmount);

        uint8 supplyCollateralIndex = 25; // or any unused index
        leafs[supplyCollateralIndex] = ManageLeaf(
            0x68e37dE8d93d3496ae143F2E900490f6280C57cD,
            false,
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            new address[](5),
            "Supply stHYPE/wstHYPE as collateral to Felix",
            rawDataDecoderAndSanitizer
        );

        console.log("Supply leaf created");

        leafs[supplyCollateralIndex].argumentAddresses[0] = 0x5555555555555555555555555555555555555555;
        leafs[supplyCollateralIndex].argumentAddresses[1] = 0x94e8396e0869c9F2200760aF0621aFd240E1CF38;
        leafs[supplyCollateralIndex].argumentAddresses[2] = 0xD767818Ef397e597810cF2Af6b440B1b66f0efD3;
        leafs[supplyCollateralIndex].argumentAddresses[3] = 0xD4a426F010986dCad727e8dd6eed44cA4A9b7483;
        leafs[supplyCollateralIndex].argumentAddresses[4] = address(boringVault);

        MarketParams memory borrowParams = MarketParams({
            loanToken:      0x5555555555555555555555555555555555555555,
            collateralToken:0x94e8396e0869c9F2200760aF0621aFd240E1CF38,
            oracle:         0xD767818Ef397e597810cF2Af6b440B1b66f0efD3,
            irm:            0xD4a426F010986dCad727e8dd6eed44cA4A9b7483,
            lltv:           860000000000000000
        });

        uint256 borrowAmount = 1000000; //ERC20(getAddress(sourceChain, "wstHYPE")).balanceOf(address(boringVault));
        console.log("Borrow amount:", borrowAmount);

        uint8 borrowIndex = 26; // or any unused index
        leafs[borrowIndex] = ManageLeaf(
            0x68e37dE8d93d3496ae143F2E900490f6280C57cD,
            false,
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            "Borrow from Felix",
            rawDataDecoderAndSanitizer
        );

        console.log("Borrow leaf created");

        leafs[borrowIndex].argumentAddresses[0] = 0x5555555555555555555555555555555555555555;
        leafs[borrowIndex].argumentAddresses[1] = 0x94e8396e0869c9F2200760aF0621aFd240E1CF38;
        leafs[borrowIndex].argumentAddresses[2] = 0xD767818Ef397e597810cF2Af6b440B1b66f0efD3;
        leafs[borrowIndex].argumentAddresses[3] = 0xD4a426F010986dCad727e8dd6eed44cA4A9b7483;
        leafs[borrowIndex].argumentAddresses[4] = address(boringVault);
        leafs[borrowIndex].argumentAddresses[5] = address(boringVault);

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
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[WHYPE_UNWRAP_INDEX]; // unwrap first
        manageLeafs[1] = leafs[sthypeMintIndex];
        manageLeafs[2] = leafs[approveIndex];
        manageLeafs[3] = leafs[supplyCollateralIndex];
        manageLeafs[4] = leafs[borrowIndex];

        manageProofs = _getProofsUsingTree(manageLeafs, merkleTree);
        console.logString("manageProofs generated");

        targets = new address[](5);
        targets[0] = manageLeafs[0].target;
        targets[1] = manageLeafs[1].target;
        targets[2] = manageLeafs[2].target;
        targets[3] = manageLeafs[3].target;
        targets[4] = manageLeafs[4].target;

        targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", unwrapAmount);
        targetData[1] = abi.encodeWithSignature("mint(address)", address(boringVault));
        targetData[2] = abi.encodeWithSignature( // 👈 approve
            "approve(address,uint256)",
            0x68e37dE8d93d3496ae143F2E900490f6280C57cD,
            type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            depositParams,   // pass actual struct instance
            depositAmount,         // uint256 assets
            address(boringVault),
            bytes("")       // empty data
        );
        targetData[4] = abi.encodeWithSignature(
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            borrowParams,
            borrowAmount,         // assets
            0,                    // minOut or slippage buffer (if needed)
            address(boringVault), // onBehalf
            address(boringVault)  // receiver
        );

        // Use exact decoders from the leafs 
        decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = address(rawDataDecoderAndSanitizer); // For withdraw
        decodersAndSanitizers[1] = address(rawDataDecoderAndSanitizer); // For mint
        decodersAndSanitizers[2] = address(rawDataDecoderAndSanitizer);
        decodersAndSanitizers[3] = address(rawDataDecoderAndSanitizer);
        decodersAndSanitizers[4] = address(rawDataDecoderAndSanitizer);

        valueAmounts = new uint256[](5);
        valueAmounts[0] = 0;
        valueAmounts[1] = unwrapAmount;
        valueAmounts[2] = 0;
        valueAmounts[3] = 0;
        valueAmounts[4] = 0;
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