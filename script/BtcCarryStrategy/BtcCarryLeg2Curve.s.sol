// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/* solhint-disable no-console */
import {BtcCarryBase} from "./BtcCarryBase.s.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

interface ICurvePool {
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

/**
 * @title BtcCarryLeg2CurveSwap
 * @notice Script to execute the second leg of the BTC Carry strategy: Curve swap
 * @dev This script swaps feUSD to USDC via Curve
 *
 * To run on testnet:
 * forge script script/BtcCarryStrategy/BtcCarryLeg2CurveSwap.s.sol:BtcCarryLeg2CurveSwapScript --rpc-url $RPC_URL --broadcast
 *
 * To run on mainnet:
 * forge script script/BtcCarryStrategy/BtcCarryLeg2CurveSwap.s.sol:BtcCarryLeg2CurveSwapScript --rpc-url $MAINNET_RPC_URL --broadcast --verify
 */
contract BtcCarryLeg2CurveSwapScript is BtcCarryBase {
    // Curve swap constants
    int128 internal constant FEUSD_INDEX = 0;
    int128 internal constant USDC_INDEX = 1;
    uint256 internal constant SLIPPAGE_TOLERANCE = 50; // 0.5%
    
    function setUp() external {
        // Initialize basic setup
        initChainSetup();
        loadDeployedContracts();
        setupMerkleProofs();
    }

    function run() external {
        console.log("Starting BTC Carry Strategy - Leg 2 (Curve Swap)");
        
        // Log initial balances
        logTokenBalances("Before Curve Swap");

        ERC20 feUSD = ERC20(getAddress(sourceChain, "feUSD"));
        
        // Check if vault has sufficient feUSD balance
        uint256 feUSDBalance = feUSD.balanceOf(address(boringVault));
        if (feUSDBalance == 0) {
            console.logString("ERROR: Vault has no feUSD balance - ensure Leg 1 was executed first");
            return;
        }
        
        // Prepare for transaction
        uint256 pk = getPrivateKey();
        vm.startBroadcast(pk);
        
        // Execute Curve swap operations
        executeCurveSwap();
        
        vm.stopBroadcast();
        
        // Log final balances
        logTokenBalances("After Curve Swap");
    }

    /**
     * @notice Execute the Curve swap leg of the strategy
     * @dev Swaps feUSD to USDC via Curve
     */
    function executeCurveSwap() public {
        console.log("Executing Curve swap operations...");
        
        // Create new arrays with only the Curve operations (operations 1 and 2 in the base)
        bytes32[][] memory curveProofs = new bytes32[][](2);
        address[] memory curveTargets = new address[](2);
        bytes[] memory curveData = new bytes[](2);
        address[] memory curveDecodersAndSanitizers = new address[](2);
        uint256[] memory curveValueAmounts = new uint256[](2);

        address swap = getAddress(sourceChain, "curveUsdcFeUSDPool");
        ERC20 feUSD = ERC20(getAddress(sourceChain, "feUSD"));
        ERC20 usdc = ERC20(getAddress(sourceChain, "USDC"));

        // Copy the Curve operations from the base arrays (indices 1 and 2, which are feUSD approval and swap)
        for (uint8 i = 0; i < 2; i++) {
            curveProofs[i] = manageProofs[i+1];
            curveTargets[i] = targets[i+1];
            curveDecodersAndSanitizers[i] = decodersAndSanitizers[i+1];
            curveValueAmounts[i] = valueAmounts[i+1];
        }
        
        // Get the current feUSD balance
        uint256 feUSDBalance = feUSD.balanceOf(address(boringVault));
        
        // Calculate the minimum expected USDC output with slippage tolerance
        uint256 expectedUsdcAmount;
        uint256 minDy;
        
        try ICurvePool(swap).get_dy(FEUSD_INDEX, USDC_INDEX, feUSDBalance) returns (uint256 amount) {
            expectedUsdcAmount = amount;
            
            // Apply slippage tolerance (0.5% default)
            minDy = expectedUsdcAmount * (10000 - SLIPPAGE_TOLERANCE) / 10000;
        } catch {
            // Use a conservative default (95% of feUSD value, assuming 6 decimal places for USDC vs 18 for feUSD)
            minDy = (feUSDBalance * 95 / 100) / 10**12;
        }
        
        // feUSD approval for Curve pool
        curveData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            swap, 
            type(uint256).max
        );
        
        // Curve swap (feUSD to USDC)
        curveData[1] = abi.encodeWithSignature(
            "exchange(int128,int128,uint256,uint256)",
            FEUSD_INDEX, // i - feUSD index
            USDC_INDEX,  // j - USDC index
            feUSDBalance, // dx - amount to swap
            minDy       // min_dy - minimum acceptable output with slippage
        );
        
        console.logString("Curve swap transaction data prepared");
        
        // Execute transactions
        try manager.manageVaultWithMerkleVerification(
            curveProofs, 
            curveDecodersAndSanitizers, 
            curveTargets, 
            curveData, 
            curveValueAmounts
        ) {
            uint256 usdcBalance = usdc.balanceOf(address(boringVault));
            
            // Check if the output is below expectations
            if (usdcBalance < minDy) {
                console.logString("WARNING: USDC output is below expected minimum");
            }
        } catch (bytes memory errorData) {
            console.logString("Curve swap error: ");
            logError(errorData);
            revert("Curve swap failed");
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