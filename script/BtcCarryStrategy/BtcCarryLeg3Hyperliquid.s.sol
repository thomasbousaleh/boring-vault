// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/* solhint-disable no-console */
import {BtcCarryBase} from "./BtcCarryBase.s.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IHyperliquidVault {
    function getVaultBalance(address account) external view returns (uint256);
    function sendVaultTransfer(address target, bool isDeposit, uint64 amount) external;
}

/**
 * @title BtcCarryLeg3Hyperliquid
 * @notice Script to execute the third leg of the BTC Carry strategy: Hyperliquid deposit
 * @dev This script deposits USDC into the Hyperliquid vault
 *
 * To run on testnet:
 * forge script script/BtcCarryStrategy/BtcCarryLeg3Hyperliquid.s.sol:BtcCarryLeg3HyperliquidScript --rpc-url $RPC_URL --broadcast
 *
 * To run on mainnet:
 * forge script script/BtcCarryStrategy/BtcCarryLeg3Hyperliquid.s.sol:BtcCarryLeg3HyperliquidScript --rpc-url $MAINNET_RPC_URL --broadcast --verify
 */
contract BtcCarryLeg3HyperliquidScript is BtcCarryBase {
    // Default USDC amount to deposit (will be determined at runtime)
    uint64 internal depositAmount;
    
    function setUp() external {
        // Initialize basic setup
        initChainSetup();
        loadDeployedContracts();
        setupMerkleProofs();
    }

    function run() external {
        console.log("Starting BTC Carry Strategy - Leg 3 (Hyperliquid)");
        
        // Log initial balances
        logTokenBalances("Before Hyperliquid Operations");

        ERC20 usdc = ERC20(getAddress(sourceChain, "USDC"));
        
        // Check if vault has sufficient USDC balance
        uint256 usdcBalance = usdc.balanceOf(address(boringVault));
        if (usdcBalance == 0) {
            console.logString("ERROR: Vault has no USDC balance - ensure Leg 2 was executed first");
            return;
        }
        
        // Make sure it fits in uint64 for the Hyperliquid vault
        if (usdcBalance > type(uint64).max) {
            depositAmount = type(uint64).max;
        } else {
            depositAmount = uint64(usdcBalance);
        }
        
        // Allow depositing a portion of the balance via environment variable
        uint256 depositPercentage = vm.envOr("DEPOSIT_PERCENTAGE", uint256(100)); // 100% default
        if (depositPercentage < 100) {
            uint256 adjustedAmount = uint256(depositAmount) * depositPercentage / 100;
            depositAmount = uint64(adjustedAmount);
        }
        
        
        // Prepare for transaction
        uint256 pk = getPrivateKey();
        vm.startBroadcast(pk);
        
        // Execute Hyperliquid operations
        executeHyperliquidDeposit();
        
        vm.stopBroadcast();
        
        // Log final balances
        logTokenBalances("After Hyperliquid Operations");
        console.logString("BTC Carry Strategy Leg 3 (Hyperliquid) completed successfully");
    }

    /**
     * @notice Execute the Hyperliquid leg of the strategy
     * @dev Deposits USDC into the Hyperliquid vault
     */
    function executeHyperliquidDeposit() public {
        console.log("Executing Hyperliquid deposit operations...");
        
        // Create new arrays with only the Hyperliquid operations (operations 3 and 4 in the base)
        bytes32[][] memory hyperliquidProofs = new bytes32[][](2);
        address[] memory hyperliquidTargets = new address[](2);
        bytes[] memory hyperliquidData = new bytes[](2);
        address[] memory hyperliquidDecodersAndSanitizers = new address[](2);
        uint256[] memory hyperliquidValueAmounts = new uint256[](2);

        address l1Hyperliquid = getAddress(sourceChain, "hypeL1Write");
        address hlp = getAddress(sourceChain, "HLP");

        // Copy the Hyperliquid operations from the base arrays (indices 3 and 4, which are HLP approval and deposit)
        for (uint8 i = 0; i < 2; i++) {
            hyperliquidProofs[i] = manageProofs[i+3];
            hyperliquidTargets[i] = targets[i+3];
            hyperliquidDecodersAndSanitizers[i] = decodersAndSanitizers[i+3];
            hyperliquidValueAmounts[i] = valueAmounts[i+3];
        }
        
        // Prepare target data for transactions
        
        // USDC approval for HLP
        hyperliquidData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            hlp, 
            type(uint256).max
        );
        
        // Hyperliquid vault deposit
        hyperliquidData[1] = abi.encodeWithSignature(
            "sendVaultTransfer(address,bool,uint64)",
            hlp, // target
            true, // isDeposit
            depositAmount // amount
        );
        
        // Try to get the current vault balance before deposit
        uint256 vaultBalanceBefore = 0;
        try IHyperliquidVault(l1Hyperliquid).getVaultBalance(address(manager)) returns (uint256 balance) {
            vaultBalanceBefore = balance;
        } catch {
            console.logString("Failed to get current vault balance");
        }
        
        // Execute transactions
        try manager.manageVaultWithMerkleVerification(
            hyperliquidProofs, 
            hyperliquidDecodersAndSanitizers, 
            hyperliquidTargets, 
            hyperliquidData, 
            hyperliquidValueAmounts
        ) {
            console.logString("Hyperliquid deposit completed successfully");
            
            // Try to get the updated vault balance
            try IHyperliquidVault(l1Hyperliquid).getVaultBalance(address(manager)) returns (uint256 balance) {
                console.logString("Increase in vault balance:");
                console.logUint(balance - vaultBalanceBefore);
            } catch {
                console.logString("Failed to get updated vault balance");
            }
        } catch (bytes memory errorData) {
            console.logString("Hyperliquid deposit error: ");
            logError(errorData);
            revert("Hyperliquid deposit failed");
        }
    }

    /**
     * @notice Simple helper to ask for user confirmation
     * @dev In a real implementation, this would wait for user input
     */
    function askUserToConfirm(string memory message) internal view virtual override returns (bool) {
        console.logString("CONFIRMATION REQUIRED:");
        console.logString(message);
        return true; // Auto-confirm for now
    }
} 