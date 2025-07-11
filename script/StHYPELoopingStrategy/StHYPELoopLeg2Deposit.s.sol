// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/* solhint-disable no-console */
import {StHypeLoopBase} from "./StHYPELoopBase.s.sol";
import {console} from "forge-std/console.sol";

/**
 * @title StHypeLoopLeg2DepositToFelix
 * @notice Executes leg 2 of the stHYPE Loop: deposits stHYPE to Felix as collateral
 *
 * To run on testnet:
 * forge script script/StHypeLoopingStrategy/StHypeLoopLeg2DepositToFelix.s.sol:StHypeLoopLeg2DepositToFelixScript --rpc-url $RPC_URL --broadcast --skip-simulation --legacy
 */
contract StHypeLoopLeg2DepositToFelixScript is StHypeLoopBase {
    function setUp() internal {
        initChainSetup();
        loadDeployedContracts();
        setupMerkleProofs(); // generates all proofs, we’ll just extract the last one
    }

    function run() external {
        console.log("Starting StHype Loop Strategy - Leg 2 (Deposit to Felix)");

        setUp();

        // We're only executing the 3rd operation: supplyCollateral
        uint256 index = 2;

        bytes32 ;
        felixProofs[0] = manageProofs[index];

        address ;
        felixTargets[0] = targets[index];

        bytes ;
        felixPayloads[0] = targetData[index];

        address ;
        felixDecoders[0] = decodersAndSanitizers[index];

        uint256 ;
        felixValues[0] = valueAmounts[index];

        console.log("Depositing to Felix...");
        vm.startBroadcast();

        try manager.manageVaultWithMerkleVerification(
            felixProofs,
            felixDecoders,
            felixTargets,
            felixPayloads,
            felixValues
        ) {
            console.logString("Deposited stHYPE to Felix successfully");
        } catch (bytes memory err) {
            console.logString("Deposit to Felix failed:");
            logError(err);
        }

        vm.stopBroadcast();
    }

    function askUserToConfirm(string memory message) internal view virtual override returns (bool) {
        console.logString("CONFIRMATION REQUIRED:");
        console.logString(message);
        return true; // Auto-confirm for now
    }
}