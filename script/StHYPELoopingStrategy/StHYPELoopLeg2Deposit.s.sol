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
contract StHypeLoopLeg2DepositScript is StHypeLoopBase {
    function setUp() internal {
        initChainSetup();
        loadDeployedContracts();
        setupMerkleProofs(); // generates all proofs, we’ll just extract the last one
    }

    function run() external {
        console.log("Starting StHype Loop Strategy - Leg 2 (Deposit to Felix)");

        setUp();

        // Declare arrays
        bytes32[][] memory depositProofs;
        address[] memory   depositTargets;
        bytes[] memory     depositPayloads;
        address[] memory   depositDecoders;
        uint256[] memory   depositValues;
        uint256[] memory   selected;
        
        depositProofs   = new bytes32[][](2);
        depositTargets  = new address[](2);
        depositPayloads = new bytes[](2);
        depositDecoders = new address[](2);
        depositValues   = new uint256[](2);
        selected        = new uint256[](2);
        
        selected[0] = 0; // setManageRoot
        selected[1] = 2; // supplyCollateral

        // We're only executing the 3rd operation: supplyCollateral
        for (uint256 i = 0; i < 2; i++) {
            uint256 idx = selected[i];
            depositProofs[i] = manageProofs[idx];
            depositTargets[i] = targets[idx];
            depositPayloads[i] = targetData[idx];
            depositDecoders[i] = decodersAndSanitizers[idx];
            depositValues[i] = valueAmounts[idx];
        }

        for (uint256 i = 0; i < depositProofs.length; i++) {
            for (uint256 j = 0; j < depositProofs[i].length; j++) {
                console.log("depositProofs[%s][%s] =", i, j);
                console.logBytes32(depositProofs[i][j]);
            }
        }

        for (uint256 i = 0; i < depositTargets.length; i++) {
            console.log("depositTargets[%s] =", i);
            console.logAddress(depositTargets[i]);
        }

        for (uint256 i = 0; i < depositPayloads.length; i++) {
            console.log("depositPayloads[%s] =", i);
            console.logBytes(depositPayloads[i]);
        }

        for (uint256 i = 0; i < depositDecoders.length; i++) {
            console.log("depositDecoders[%s] =", i);
            console.logAddress(depositDecoders[i]);
        }

        for (uint256 i = 0; i < depositValues.length; i++) {
            console.log("depositValues[%s] =", i);
            console.logUint(depositValues[i]);
        }

        console.log("Depositing to Felix...");
        vm.startBroadcast();

        try manager.manageVaultWithMerkleVerification(
            depositProofs,
            depositDecoders,
            depositTargets,
            depositPayloads,
            depositValues
        ) {
            console.logString("Deposited stHYPE to Felix successfully");
        } catch (bytes memory err) {
            console.logString("Deposit to Felix failed:");
            logError(err);

            if (err.length >= 68) {
                bytes memory revertData = slice(err, 4, err.length - 4);
                string memory reason = abi.decode(revertData, (string));
                console.logString(reason);
            }
        }

        vm.stopBroadcast();
    }

    function askUserToConfirm(string memory message) internal view virtual override returns (bool) {
        console.logString("CONFIRMATION REQUIRED:");
        console.logString(message);
        return true; // Auto-confirm for now
    }

    function slice(bytes memory data, uint256 start, uint256 len) internal pure returns (bytes memory) {
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[i + start];
        }
        return result;
    }
}