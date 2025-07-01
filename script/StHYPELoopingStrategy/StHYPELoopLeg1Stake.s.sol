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
 * forge script script/StHypeLoopingStrategy/StHypeLoopLeg1Stakex.s.sol:StHypeLoopLeg1StakeScript --rpc-url $MAINNET_RPC_URL --broadcast --skip-simulation --legacy --verify
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

        IOverseer overseer = IOverseer(getAddress(sourceChain, "Overseer"));
        string memory validatorCode = "stHYPE";   // MUST match the leaf
        uint256 hypeToStake = 1;

        // Suppose manageProofs is a bytes32[] in storage, with N proofs:
        uint256 N = manageProofs.length;

        // 1) Allocate all your memory arrays to length N
        bytes32[][] memory stakeProofs = new bytes32[][](N);
        address[] memory  targets    = new address[](N);
        bytes[]   memory  payloads   = new bytes[](N);
        address[] memory  decoders   = new address[](N);
        uint256[] memory  values     = new uint256[](N);

        // 2) Loop to populate them
        for (uint256 i = 0; i < N; i++) {
            stakeProofs[i] = manageProofs[i];         // the i-th Merkle proof
            targets[i]     = address(overseer);       // or whatever varies per call
            payloads[i]    = abi.encodeWithSignature(
                                "mint(address,string)",
                                vm.addr(pk),
                                validatorCode
                            );
            decoders[i]    = address(0x010e148d8EAEad41559F1677e8abf50Fdb8b4C00);              // if you don’t need a decoder
            values[i]      = hypeToStake;             // same stake each time, or vary
        }

        console.logString("decoders[0] ="); console.logAddress(decoders[0]);
        console.logString("targets[0]  ="); console.logAddress(targets[0]);

        vm.startBroadcast(pk);

        try manager.manageVaultWithMerkleVerification(
            stakeProofs,
            decoders,
            targets,
            payloads,
            values
        ) {
            // success
            console.logString("Staked HYPE to stHYPE successfully");
        } catch (bytes memory err) {
            // failure
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