// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

interface IWHYPE {
    function deposit() external payable;
    function approve(address guy, uint wad) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

contract DepositToVault is Script {
    address constant tellerAddress = 0xC1bDbfF0B7118556963B70826933297614B705C1;
    address constant W_HYPE = 0x5555555555555555555555555555555555555555;
    address constant vaultAddress = 0xE2Ab074556a97EC8691cC881Ec69a60ceacfF132;

    function run() external {
        uint256 privateKey = vm.envUint("BORING_DEVELOPER");
        address sender = vm.addr(privateKey);
        vm.startBroadcast(privateKey);

        uint256 depositAmount = 1e15;

        // Load contracts
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(tellerAddress);
        BoringVault vault = BoringVault(payable(vaultAddress));
        IWHYPE token = IWHYPE(W_HYPE);

        // Wrap native HYPE into wHYPE
        token.deposit{ value: depositAmount }();

        // Approve the teller to spend wHYPE
        token.approve(vaultAddress, depositAmount);

        // Deposit into the vault via teller
        teller.deposit(ERC20(W_HYPE), depositAmount, 0);

        vm.stopBroadcast();

        // Verify deposit
        uint256 vaultBalance = token.balanceOf(vaultAddress);
        uint256 shareBalance = vault.balanceOf(sender);
        
        console.log("Vault token balance:", vaultBalance);
        console.log("Your share balance:", shareBalance);
        console.log("Deposit completed");
    }
}