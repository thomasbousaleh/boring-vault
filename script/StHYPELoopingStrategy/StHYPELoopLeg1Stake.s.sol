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

    function setUp() external {
        // Initialize basic setup
        initChainSetup();
        loadDeployedContracts();
        setupMerkleProofs();
    }

    function run() external {
        console.log("Starting StHype Loop Strategy - Leg 1 (Stake)");

        uint256 pk = getPrivateKey();

        // These were already set in setupMerkleProofs()
        bytes32[][] memory stakeProofs = manageProofs;
        address[] memory  stakeTargets = targets;
        bytes[] memory    stakePayloads = targetData;
        address[] memory  stakeDecoders = decodersAndSanitizers;
        uint256[] memory  stakeValues = valueAmounts;

        bytes32 proof0 = stakeProofs[0][0];
        console.logString("stakeProofs[0][0] ="); console.logBytes32(proof0);
        console.logString("targets[0]  ="); console.logAddress(stakeTargets[0]);
        console.logString("payloads[0] ="); console.logBytes(stakePayloads[0]);
        console.logString("decoders[0] ="); console.logAddress(stakeDecoders[0]);
        console.logString("values[0] ="); console.logUint(stakeValues[0]);

        vm.startBroadcast(pk);

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