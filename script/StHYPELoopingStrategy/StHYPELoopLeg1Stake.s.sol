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
        IOverseer overseer = IOverseer(getAddress(sourceChain, "Overseer")); // Get contract

        address user = address(this); // or another recipient
        string memory validatorCode = ""; // or use "" if none

        // Ensure this contract has WHYPE balance (ETH) — WHYPE is native ETH
        uint256 hypeToStake = 1;

        // Stake into stHYPE
        uint256 stHypeMinted = overseer.mint{value: hypeToStake}(user, validatorCode);

        console.log("Minted stHYPE:", stHypeMinted);
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