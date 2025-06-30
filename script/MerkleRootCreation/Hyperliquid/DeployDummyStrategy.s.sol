// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { DummyStrategy } from "./DummyStrategy.sol";
import { IBoringVault } from "./IBoringVault.sol";

contract DeployDummyStrategy is Script {
    address public constant VAULT = 0x486367D6aBEe6dB736aa193d9e3B3cd94b865B76;
    address public constant WHYPE = 0x5555555555555555555555555555555555555555;

    function run() external {
        uint256 key = vm.envUint("BORING_DEVELOPER");
        vm.startBroadcast(key);

        DummyStrategy strat = new DummyStrategy(VAULT);

        // Register the strategy with the vault
        IBoringVault(VAULT).setStrategy(WHYPE, address(strat));

        vm.stopBroadcast();
    }
}