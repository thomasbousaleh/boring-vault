// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

/**
 * @title DepositToVault
 * @notice Script to deposit ERC20 tokens into the BoringVault via the Teller
 * 
 * To run:
 * forge script script/BtcCarryStrategy/DepositToVault.s.sol:DepositToVaultScript --sig "run(address,uint256)" <TOKEN_ADDRESS> <AMOUNT> --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 */
contract DepositToVaultScript is Script {
    function run() external {
        console.logString("Starting Deposit to Vault via Teller");
        console.logString("Token Address: 0x90DEC465dFCEa455EDC2DF66b04591e147B59C8b");
        console.logString("Amount: 1e18");
        uint256 amount = 1e18;

        // Get deployment details from env variables
        address tellerAddress = 0xe8b75fB8208cC4d3054fE9793D9748fb3D34D450;
        address vaultAddress = 0x208EeF7B7D1AcEa7ED4964d3C5b0c194aDf17412;
        
        // Load contracts
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(tellerAddress);
        BoringVault vault = BoringVault(payable(vaultAddress));
        ERC20 token = ERC20(0x90DEC465dFCEa455EDC2DF66b04591e147B59C8b);
        
        // Check token balance
        uint256 pk = vm.envUint("BORING_DEVELOPER");
        address sender = vm.addr(pk);
        uint256 balance = token.balanceOf(sender);
        
        console.log("Your Balance:", balance);
        
        if (balance < amount) {
            console.log("ERROR: Insufficient token balance");
            return;
        }
        
        // Check if token is accepted by teller
        (bool allowDeposits,,) = teller.assetData(token);
        if (!allowDeposits) {
            console.log("ERROR: Token not enabled for deposits in teller");
            return;
        }
        
        // Start broadcasting transactions
        vm.startBroadcast(pk);
        
        // Approve tokens to teller
        console.log("Approving tokens to teller");
        token.approve(vaultAddress, amount);
        
        // Deposit via teller
        console.log("Depositing via teller");
        teller.deposit(token, amount, 0);
        
        vm.stopBroadcast();
        
        // Verify deposit
        uint256 vaultBalance = token.balanceOf(vaultAddress);
        uint256 shareBalance = vault.balanceOf(sender);
        
        console.log("Vault token balance:", vaultBalance);
        console.log("Your share balance:", shareBalance);
        console.log("Deposit completed");
    }
}