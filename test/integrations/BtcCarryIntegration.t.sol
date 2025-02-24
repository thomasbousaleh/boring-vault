pragma solidity 0.8.21;
// SPDX-License-Identifier: UNLICENSED

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol"; 
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {FelixDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FelixDecoderAndSanitizer.sol";
import {HyperliquidL1DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HyperliquidL1DecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {IBorrowerOperations} from "src/interfaces/Liquity/IBorrowerOperations.sol";
import {IL1Write} from "src/interfaces/Hyperliquid/IL1Write.sol";


contract SwapMock {
    function swap(uint256 feUSDAmount) external pure returns (uint256) {
        return feUSDAmount;
    }
}

// --- Test Contract ---

contract BtcCarryIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    address public btcCarryUser;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    address public wBTCOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public feUSDOracle = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    
    ERC20 public wBTC;
    ERC20 public feUSD;

    address public felix;
    address public swap;
    address public l1Hyperliquid;
    address internal vault;

    function setUp() external {
        // Set source chain name to "hyperliquid" explicitly.
        setSourceChainName("hyperliquid");

        // Start a fork using the hyperliquid RPC URL and a specified block.
        string memory rpcKey = "HYPERLIQUID_RPC_URL";
        uint256 blockNumber = 18619251; 
        _startFork(rpcKey, blockNumber);

        // Retrieve deployed protocol addresses on hyperliquid.
        felix = getAddress(sourceChain, "WBTC_borrowerOperations");
        swap = getAddress(sourceChain, "curveUsdcFeUSDPool");
        l1Hyperliquid = getAddress(sourceChain, "hlp");

        wBTC = getERC20(sourceChain, "WBTC");
        feUSD = getERC20(sourceChain, "feUSD");
        vault = getAddress(sourceChain, "vault");

        // Create the BoringVault
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        // Deploy the manager contract.
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FelixDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);
    }
    
    function testBtcCarryStrategyExecution() external {
        console.logString("testBtcCarryStrategyExecution started");

        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 1_000e18);
        console.logString("WBTC balance set");

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        _addFelixLeafs(leafs);
        // _addHyperliquidLeafs(leafs);
        console.logString("leafs generated");

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        _generateTestLeafs(leafs, manageTree);
        console.logString("manageRoot set");

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        // manageLeafs[1] = leafs[1];
        // manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
        console.logString("manageProofs generated");

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "WBTC");
        // targets[1] = getAddress(sourceChain, "WBTC_borrowerOperations");
        // targets[2] = getAddress(sourceChain, "hlp");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "strategyManager"), type(uint256).max
        );
        // targetData[1] = abi.encodeWithSignature(
        //     "openTrove(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,address,address)",
        //     address(this), 0, 1_000e18, 1_00e18, 0, 0, 0, 0, address(this), address(this), address(this)
        // );
        // targetData[2] = abi.encodeWithSignature(
        //     "sendVaultTransfer(address,bool,uint64)", l1Hyperliquid, true, 1_000e18
        // );
        console.logString("targetData generated");

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        console.logString("decodersAndSanitizers generated");

        uint256[] memory values = new uint256[](1);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        console.logString("manageVaultWithMerkleVerification complete");

        console.logString("testBtcCarryStrategyExecution complete");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function withdraw(uint256 amount) external {
        boringVault.enter(address(0), ERC20(address(0)), 0, address(this), amount);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
} 