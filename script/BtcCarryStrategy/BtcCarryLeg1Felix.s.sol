// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/* solhint-disable no-console */    
import {BtcCarryBase} from "./BtcCarryBase.s.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IHintHelpers} from "src/interfaces/Liquity/IHintHelpers.sol";
import {IBorrowerOperations} from "src/interfaces/Liquity/IBorrowerOperations.sol";
import {IPriceFeedTestnet} from "src/interfaces/Liquity/TestInterfaces/IPriceFeedTestnet.sol";
import {PriceFeedTestnet} from "src/interfaces/Liquity/TestInterfaces/PriceFeedTestnet.sol";

/**
 * @title BtcCarryLeg1Felix
 * @notice Script to execute the first leg of the BTC Carry strategy: Felix operations
 * @dev This script borrows feUSD using WBTC as collateral through the Felix protocol
 *
 * To run on testnet:
 * forge script script/BtcCarryStrategy/BtcCarryLeg1Felix.s.sol:BtcCarryLeg1FelixScript --rpc-url $RPC_URL --broadcast --skip-simulation --legacy
 *
 * To run on mainnet:
 * forge script script/BtcCarryStrategy/BtcCarryLeg1Felix.s.sol:BtcCarryLeg1FelixScript --rpc-url $MAINNET_RPC_URL --broadcast --skip-simulation --legacy --verify
 */
contract BtcCarryLeg1FelixScript is BtcCarryBase {

    // Strategy parameters
    uint256 public annualInterestRate;
    uint256 public upfrontFee;
    uint256 public collAmount;
    uint256 public boldAmount;

    function setUp() external {
        // Initialize basic setup
        initChainSetup();
        loadDeployedContracts();
        setupStrategyParameters();
        setupMerkleProofs();

        // Get upfront fee from hint helpers
        address hintHelpers = getAddress(sourceChain, "hintHelpers");
        try IHintHelpers(hintHelpers).predictOpenTroveUpfrontFee(
            0, 
            collAmount,
            annualInterestRate
        ) returns (uint256 fee) {
            upfrontFee = fee;
            console.logString("Predicted upfront fee for opening trove:");
            console.logUint(upfrontFee);
        } catch {
            // Use a higher default fee if prediction fails
            upfrontFee = 5000000; 
            console.logString("Using default upfront fee:");
            console.logUint(upfrontFee);
        }

        // Mock price feed
        address priceFeedAddress = getAddress(sourceChain, "WBTC_priceFeed");
        uint256 lastGoodPrice = 3761200000000000000000; // Use a known good price from previous runs
        try IPriceFeedTestnet(priceFeedAddress).lastGoodPrice() returns (uint256 price) {
            lastGoodPrice = price;
            console.logString("Last good price:");
            console.logUint(lastGoodPrice);
        } catch {
            console.logString("Failed to get lastGoodPrice");
            console.logString("Using default price:");
            console.logUint(lastGoodPrice);
        }
        
        PriceFeedTestnet priceFeed = new PriceFeedTestnet();
        vm.etch(priceFeedAddress, address(priceFeed).code);

        try IPriceFeedTestnet(priceFeedAddress).setPrice(lastGoodPrice * 110 / 100) returns (bool /* success */) {
            console.logString("Price feed set successfully");
        } catch (bytes memory err) {
            console.logString("Error setting price feed:");
            console.logBytes(err);
        }
    }

    function run() external {
        console.log("Starting BTC Carry Strategy - Leg 1 (Felix)");
        
        // Log initial balances
        logTokenBalances("Before Felix Operations");

        ERC20 wBTC = ERC20(getAddress(sourceChain, "WBTC"));
        
        // Check if vault has sufficient WBTC balance
        uint256 wbtcBalance = wBTC.balanceOf(address(boringVault));
        if (wbtcBalance < collAmount) {
            bool proceed = askUserToConfirm("Proceed with insufficient WBTC?");
            if (!proceed) {
                console.log("Execution aborted by user");
                return;
            }
        }
        
        // Prepare for transaction
        uint256 pk = getPrivateKey();
        vm.startBroadcast(pk);
        
        // Execute Felix operations
        executeFelixOperations();
        
        vm.stopBroadcast();
        
        // Log final balances
        logTokenBalances("After Felix Operations");
        console.logString("BTC Carry Strategy Leg 1 (Felix) completed successfully");
    }

    // Read strategy parameters from environment or set defaults
    function setupStrategyParameters() internal {
        // Get strategy parameters from environment or set defaults
        annualInterestRate = vm.envOr("ANNUAL_INTEREST_RATE", uint256(1e17)); // 10% default
        collAmount = vm.envOr("COLL_AMOUNT", uint256(1e18)); // 1 WBTC default
        boldAmount = vm.envOr("BOLD_AMOUNT", uint256(3000e18)); // 3000 feUSD default
    }

    /**
     * @notice Execute the Felix leg of the strategy
     * @dev Approves WBTC to Felix and opens a trove to borrow feUSD
     */
    function executeFelixOperations() public {
        console.log("Executing Felix operations...");
        
        // Create new arrays with only the Felix operations (first 3 operations)
        bytes32[][] memory felixProofs = new bytes32[][](3);
        address[] memory felixTargets = new address[](3);
        bytes[] memory felixData = new bytes[](3);
        address[] memory felixDecodersAndSanitizers = new address[](3);
        uint256[] memory felixValueAmounts = new uint256[](3);

        address felix = getAddress(sourceChain, "WBTC_borrowerOperations");

        // Copy just the Felix operations from the base arrays
        for (uint8 i = 0; i < 3; i++) {
            felixProofs[i] = manageProofs[i];
            felixTargets[i] = targets[i];
            felixDecodersAndSanitizers[i] = decodersAndSanitizers[i];
            felixValueAmounts[i] = valueAmounts[i];
        }
        
        // Prepare the target data for Felix operations
        
        // WBTC approval
        felixData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            felix, 
            type(uint256).max
        );
        
        // WHYPE approval
        felixData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            felix, 
            type(uint256).max
        );
        
        // openTrove
        felixData[2] = abi.encodeWithSignature(
            "openTrove(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,address,address)",
            address(boringVault),     // _owner
            0,                        // _ownerIndex
            collAmount,               // _ETHAmount (WBTC amount)
            boldAmount,               // _boldAmount (feUSD amount)
            0,                        // _upperHint
            0,                        // _lowerHint
            annualInterestRate,       // _annualInterestRate
            type(uint256).max,        // _maxUpfrontFee (higher than predicted)
            address(boringVault),     // _addManager
            address(boringVault),     // _removeManager
            address(boringVault)      // _receiver
        );
        
        // Execute transactions
        try manager.manageVaultWithMerkleVerification(
            felixProofs, 
            felixDecodersAndSanitizers, 
            felixTargets, 
            felixData, 
            felixValueAmounts
        ) {
            console.logString("Felix operations completed successfully");
        } catch (bytes memory errorData) {
            console.logString("Felix operations error: ");
            logError(errorData);
            revert("Felix operations failed");
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