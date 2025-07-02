// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ITBPositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {PancakeSwapV3FullDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PancakeSwapV3FullDecoderAndSanitizer.sol";
import {AerodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {OnlyKarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyKarakDecoderAndSanitizer.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";
import {OnlyHyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyHyperlaneDecoderAndSanitizer.sol";
import {SwellEtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/SwellEtherFiLiquidEthDecoderAndSanitizer.sol";
import {sBTCNMaizenetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNMaizenetDecoderAndSanitizer.sol";
import {UniBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UniBTCDecoderAndSanitizer.sol";
import {EdgeCapitalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EdgeCapitalDecoderAndSanitizer.sol";
import {EtherFiLiquidBtcDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidBtcDecoderAndSanitizer.sol";
import {SonicMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicEthMainnetDecoderAndSanitizer.sol";
import {AaveV3FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV3FullDecoderAndSanitizer.sol"; 
import {LombardBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBtcDecoderAndSanitizer.sol"; 
import {StakedSonicUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StakedSonicUSDDecoderAndSanitizer.sol"; 
import {BtcCarryDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BtcCarryDecoderAndSanitizer.sol";
import {StHYPELoopDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StHYPELoopDecoderAndSanitizer.sol";

import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */

contract DeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x12afE7fc906f8CeBc14df974A86cc4dc1a732D26);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        // vm.createSelectFork("sonicMainnet");
        // setSourceChainName(sonicMainnet);
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        // creationCode = type(AerodromeDecoderAndSanitizer).creationCode;
        // constructorArgs =
        //     abi.encode(0xf0bb20865277aBd641a307eCe5Ee04E79073416C, 0x416b433906b1B72FA758e166e239c43d68dC6F29);
        // deployer.deployContract(EtherFiLiquidEthAerodromeDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(OnlyKarakDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault);
        // deployer.deployContract(EtherFiLiquidEthDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(PancakeSwapV3FullDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault, pancakeSwapV3NonFungiblePositionManager, pancakeSwapV3MasterChefV3);
        // deployer.deployContract(LombardPancakeSwapDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(eEigen);
        // deployer.deployContract(
        //     "ITB Eigen Position Manager Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0
        // );
        // creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(liquidUsd);
        // deployer.deployContract(ItbPositionDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(EtherFiLiquidUsdDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager);
        //deployer.deployContract(EtherFiLiquidUsdDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(OnlyHyperlaneDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(address(0));
        //deployer.deployContract("Hyperlane Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(sBTCNMaizenetDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault);
        //version is not synced w/ current deployed version anymore
        //deployer.deployContract("Staked BTCN Decoder and Sanitizer V0.4", creationCode, constructorArgs, 0);

        //creationCode = type(SwellEtherFiLiquidEthDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault);
        //deployer.deployContract("EtherFi Liquid ETH Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        //creationCode = type(sBTCNMaizenetDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault);
        //version is synced w/ current deployed version
        //deployer.deployContract("Staked BTCN Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);

        //creationCode = type(UniBTCDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Bedrock BTC DeFi Vault Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(EdgeCapitalDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(ultraUSDBoringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Ultra Yield Stablecoin Vault Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(SonicMainnetDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        // deployer.deployContract("Sonic ETH Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(EtherFiLiquidBtcDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("EtherFi Liquid BTC Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(LombardBtcDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager); 
        //deployer.deployContract("Lombard BTC Decoder And Sanitizer V0.2", creationCode, constructorArgs, 0);
        
        // address univ3 = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"); 
        // if (univ3 == address(0)) revert("fail"); 

        // creationCode = type(StakedSonicUSDDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(univ3); 
        // deployer.deployContract("Staked Sonic USD Decoder And Sanitizer V0.2", creationCode, constructorArgs, 0);

        // creationCode = type(BtcCarryDecoderAndSanitizer).creationCode;
        // constructorArgs = hex""; 
        // address btcCarry = deployer.deployContract("BTC Carry Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.logString("BTC Carry Decoder And Sanitizer V0.0 deployed at");
        // console.logAddress(btcCarry);

        creationCode = type(StHYPELoopDecoderAndSanitizer).creationCode;
        constructorArgs = hex""; 
        address sthypeDecoder = deployer.deployContract("StHYPELoop Decoder And Sanitizer V0.5", creationCode, constructorArgs, 0);
        console.logString("StHYPELoopDecoderAndSanitizer deployed at");
        console.logAddress(sthypeDecoder);

        vm.stopBroadcast();
    }
}
