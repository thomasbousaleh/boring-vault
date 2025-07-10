// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/* solhint-disable no-console */    
import {StHypeLoopBase} from "./StHYPELoopBase.s.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IHintHelpers} from "src/interfaces/Liquity/IHintHelpers.sol";
import {IBorrowerOperations} from "src/interfaces/Liquity/IBorrowerOperations.sol";
import {IPriceFeedTestnet} from "src/interfaces/Liquity/TestInterfaces/IPriceFeedTestnet.sol";
import {PriceFeedTestnet} from "src/interfaces/Liquity/TestInterfaces/PriceFeedTestnet.sol";

/**
 * @title StHypeLoopLeg1Stake
 * @notice Script to execute the first leg of the StHype Loop strategy: StHype operations
 * @dev This script borrows stakes Hype into stHype as collateral through the StakedHype protocol
 *
 * To run on testnet:
 * forge script script/StHypeLoopingStrategy/StHypeLoopLeg1Stake.s.sol:StHypeLoopLeg1StakeScript --rpc-url $RPC_URL --broadcast --skip-simulation --legacy
 *
 * To run on mainnet:
 * forge script script/StHypeLoopingStrategy/StHypeLoopLeg1Stake.s.sol:StHypeLoopLeg1StakeScript --rpc-url $MAINNET_RPC_URL --broadcast --skip-simulation --legacy --verify
 */

interface IOverseer {
    function mint(address to, string calldata communityCode) external payable returns (uint256);
}

contract StHypeLoopLeg1StakeScript is StHypeLoopBase {

    function setUp() internal {
        // Initialize basic setup
        initChainSetup();
        loadDeployedContracts();
        setupMerkleProofs();
    }

    function run() external {
        console.log("Starting StHype Loop Strategy - Leg 1 (Stake)");

        setUp();

        // These were already set in setupMerkleProofs()
        bytes32[][] memory stakeProofs = manageProofs;
        address[] memory  stakeTargets = targets;
        bytes[] memory    stakePayloads = targetData;
        address[] memory  stakeDecoders = decodersAndSanitizers;
        uint256[] memory  stakeValues = valueAmounts;

        for (uint256 i = 0; i < stakeProofs.length; i++) {
            for (uint256 j = 0; j < stakeProofs[i].length; j++) {
                console.log("stakeProofs[%s][%s] =", i, j);
                console.logBytes32(stakeProofs[i][j]);
            }
        }

        for (uint256 i = 0; i < stakeTargets.length; i++) {
            console.log("stakeTargets[%s] =", i);
            console.logAddress(stakeTargets[i]);
        }

        for (uint256 i = 0; i < stakePayloads.length; i++) {
            console.log("stakePayloads[%s] =", i);
            console.logBytes(stakePayloads[i]);
        }

        for (uint256 i = 0; i < stakeDecoders.length; i++) {
            console.log("stakeDecoders[%s] =", i);
            console.logAddress(stakeDecoders[i]);
        }

        for (uint256 i = 0; i < stakeValues.length; i++) {
            console.log("stakeValues[%s] =", i);
            console.logUint(stakeValues[i]);
        }

        vm.startBroadcast();

        try manager.manageVaultWithMerkleVerification(
            stakeProofs,
            stakeDecoders,
            stakeTargets,
            stakePayloads,
            stakeValues
        ) {
            console.logString("Staked HYPE to stHYPE successfully");
        } catch (bytes memory err) {
            console.logString("Stake via manager failed:");
            logError(err);
        }

        vm.stopBroadcast();
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