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
import {IHintHelpers} from "src/interfaces/Liquity/IHintHelpers.sol";
import {ITroveManager} from "src/interfaces/Liquity/ITroveManager.sol";
import {ITroveManagerTester} from "src/interfaces/Liquity/TestInterfaces/ITroveManagerTester.sol";
import {IPriceFeed} from "src/interfaces/Liquity/IPriceFeed.sol";
import {IPriceFeedTestnet} from "src/interfaces/Liquity/TestInterfaces/IPriceFeedTestnet.sol";
import {IWSTETHPriceFeed} from "src/interfaces/Liquity/IWSTETHPriceFeed.sol";
import {IBorrowerOperationsTester} from "src/interfaces/Liquity/TestInterfaces/IBorrowerOperationsTester.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISortedTroves} from "src/interfaces/Liquity/ISortedTroves.sol";
import {IBoldToken} from "src/interfaces/Liquity/IBoldToken.sol";
import {PriceFeedTestnet} from "src/interfaces/Liquity/TestInterfaces/PriceFeedTestnet.sol";
// --- Test Contract ---

contract BtcCarryIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    address public btcCarryUser;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    address public hyperliquidL1DecoderAndSanitizer;
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
    
    // Storage variables for execution
    bytes32[][] internal manageProofs;
    address[] internal targets;
    bytes[] internal targetData;
    address[] internal decodersAndSanitizers;
    uint256[] internal valueAmounts;
    uint256 internal annualInterestRate;
    uint256 internal upfrontFee;
    uint256 internal collAmount;
    uint256 internal boldAmount;

    function setUp() external {
        // Set source chain name to "hyperliquid" explicitly.
        setSourceChainName("hyperliquid");

        // Start a fork using the hyperliquid RPC URL and a specified block.
        string memory rpcKey = "HYPERLIQUID_RPC_URL";
        uint256 blockNumber = 18925147; // Update to a more recent block number
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
        hyperliquidL1DecoderAndSanitizer = address(new HyperliquidL1DecoderAndSanitizer());
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "hyperliquidL1DecoderAndSanitizer", hyperliquidL1DecoderAndSanitizer);
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

    // Helper function that sets up balances
    function _setupBalances() internal {
        // Setup initial balances
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WHYPE"), address(boringVault), 1_000e18);
    }

    // Helper function to create merkle tree
    function _setupMerkleTree() internal {
        // Setup merkle tree
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addFelixLeafs(leafs);
        console.logString("leafs generated");

        bytes32[][] memory merkleTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), merkleTree[merkleTree.length - 1][0]);
        console.logString("manageRoot set");

        // Choose the specific leafs we want to use 
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; // WBTC approval
        manageLeafs[1] = leafs[1]; // WHYPE approval
        manageLeafs[2] = leafs[2]; // openTrove

        manageProofs = _getProofsUsingTree(manageLeafs, merkleTree);
        console.logString("manageProofs generated");

        // Use the exact leaf targets for our targets
        targets = new address[](3);
        targets[0] = manageLeafs[0].target;
        targets[1] = manageLeafs[1].target;
        targets[2] = manageLeafs[2].target;

        targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "WBTC_borrowerOperations"), 
            type(uint256).max
        );
        
        // Add WHYPE approval
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "WBTC_borrowerOperations"), 
            type(uint256).max
        );

        // Use exact decoders from the leafs for consistency 
        decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = manageLeafs[0].decoderAndSanitizer;
        decodersAndSanitizers[1] = manageLeafs[1].decoderAndSanitizer;
        decodersAndSanitizers[2] = manageLeafs[2].decoderAndSanitizer;

        valueAmounts = new uint256[](3);
        valueAmounts[0] = manageLeafs[0].canSendValue ? 1 : 0; // Set value based on canSendValue
        valueAmounts[1] = manageLeafs[1].canSendValue ? 1 : 0; // WHYPE approval
        valueAmounts[2] = manageLeafs[2].canSendValue ? 1 : 0; // openTrove
    }

    // Helper function to gather diagnostics
    function _gatherDiagnostics() internal {
        console.logString("--- DIAGNOSTICS SECTION ---");
        
        address troveManagerAddress = getAddress(sourceChain, "WBTC_troveManager");
        address hintHelpersAddress = getAddress(sourceChain, "hintHelpers");
        address borrowerOperationsAddress = getAddress(sourceChain, "WBTC_borrowerOperations");

        IBorrowerOperations borrowerOperations = IBorrowerOperations(borrowerOperationsAddress);
        
        // Get number of troves in the system using ITroveManagerTester
        ITroveManager troveManagerTester = ITroveManager(troveManagerAddress);
        uint256 troveCount = troveManagerTester.getTroveIdsCount();
        console.logString("Number of troves in system:");
        console.logUint(troveCount);
        
        annualInterestRate = 1e17;

        // Get CCR and MCR using ITroveManagerTester
        try borrowerOperations.CCR() returns (uint256 ccr) {
            console.logString("Critical Collateral Ratio (CCR):");
            console.logUint(ccr);
        } catch {
            console.logString("Failed to get CCR");
        }
        
        try borrowerOperations.MCR() returns (uint256 mcr) {
            console.logString("Minimum Collateral Ratio (MCR):");
            console.logUint(mcr);
        } catch {
            console.logString("Failed to get MCR");
        }

        // Setup loan parameters - use highly over-collateralized amount
        collAmount = 1e18; // 1 WBTC
        boldAmount = 3000e18;  // Minimum debt requirement is 2k 
        
        // Check for SCR using ITroveManagerTester
        try borrowerOperations.SCR() returns (uint256 scr) {
            console.logString("Security Collateral Ratio (SCR):");
            console.logUint(scr);
        } catch {
            console.logString("Failed to get SCR");
        }

        // Get upfront fee
        try IHintHelpers(hintHelpersAddress).predictOpenTroveUpfrontFee(
            0, // WBTC index is likely 0
            collAmount,
            annualInterestRate
        ) returns (uint256 fee) {
            upfrontFee = fee;
            console.logString("Predicted upfront fee for opening trove:");
            console.logUint(upfrontFee);
        } catch {
            // Use a higher default fee if prediction fails
            upfrontFee = 5000000; 
            console.logString("Using default upfront fee:");
            console.logUint(upfrontFee);
        }
        
        console.logString("--- END DIAGNOSTICS ---");
    }
    
    function testBtcCarryStrategyExecution() external {
        console.logString("testBtcCarryStrategyExecution started");

        // Setup in phases to avoid stack-too-deep
        _setupBalances();
        _setupMerkleTree();
        _gatherDiagnostics();
        
        // Try fetching the price 
        address priceFeedAddress = getAddress(sourceChain, "WBTC_priceFeed");

        uint256 lastGoodPrice = 3761200000000000000000; // Use a known good price from previous runs
        try IPriceFeedTestnet(priceFeedAddress).lastGoodPrice() returns (uint256 price) {
            lastGoodPrice = price;
            console.logString("Last good price:");
            console.logUint(lastGoodPrice);
        } catch {
            console.logString("Failed to get lastGoodPrice");
            // Use a reasonable default if we can't get the last good price
            console.logString("Using default price:");
            console.logUint(lastGoodPrice);
        }
        
        PriceFeedTestnet priceFeed = new PriceFeedTestnet();
        vm.etch(priceFeedAddress, address(priceFeed).code);

        try IPriceFeedTestnet(priceFeedAddress).setPrice(lastGoodPrice * 110 / 100) returns (bool /* success */) {
            console.logString("Price feed set successfully");
        } catch (bytes memory err) {
            console.logString("Error setting price feed:");
            console.logBytes(err);
        }

        // Verify the mocking worked
        try IPriceFeedTestnet(priceFeedAddress).lastGoodPrice() returns (uint256 mockedPrice) {
            console.logString("Mocked price feed call result:");
            console.logUint(mockedPrice);
        } catch (bytes memory err) {
            console.logString("Error calling mocked regular price feed:");
            console.logBytes(err);
        }
        
        // Verify fetchPrice also works
        try IPriceFeed(priceFeedAddress).fetchPrice() returns (uint256 newPrice, bool success) {
            console.logString("Mocked fetchPrice call result:");
            console.logString("Success:");
            console.logBool(success);
            console.logString("Price:");
            console.logUint(newPrice);
        } catch (bytes memory err) {
            console.logString("Error calling mocked fetchPrice:");
            console.logBytes(err);
        }

        // Prepare transaction data for trove creation
        targetData[2] = abi.encodeWithSignature(
            "openTrove(address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,address,address)",
            getAddress(sourceChain, "boringVault"),     // _owner
            0,                                          // _ownerIndex
            collAmount,                                 // _ETHAmount
            boldAmount,                                 // _boldAmount
            0,                                          // _upperHint
            0,                                          // _lowerHint
            annualInterestRate,                         // _annualInterestRate
            type(uint256).max,                          // _maxUpfrontFee (higher than predicted)
            getAddress(sourceChain, "boringVault"),     // _addManager
            getAddress(sourceChain, "boringVault"),     // _removeManager
            getAddress(sourceChain, "boringVault")      // _receiver
        );

        console.logString("targetData generated");
        console.logString("decodersAndSanitizers generated");

        uint256 wbtcBalanceBefore = ERC20(getAddress(sourceChain, "WBTC")).balanceOf(address(boringVault));
        uint256 feusdBalanceBefore = feUSD.balanceOf(address(boringVault));

        // Execute transaction
        try manager.manageVaultWithMerkleVerification(
            manageProofs, 
            decodersAndSanitizers, 
            targets, 
            targetData, 
            valueAmounts
        ) {
            console.logString("manageVaultWithMerkleVerification completed successfully");
        } catch (bytes memory errorData) {
            console.logString("Low-level error: ");
            console.logBytes(errorData);
        }

        console.logString("Test execution complete");

        uint256 wbtcBalanceAfter = ERC20(getAddress(sourceChain, "WBTC")).balanceOf(address(boringVault));
        uint256 feusdBalanceAfter = feUSD.balanceOf(address(boringVault));
        console.logString("Final WBTC balance:");
        console.logUint(wbtcBalanceAfter);
        console.logString("Final feUSD balance:");
        console.logUint(feusdBalanceAfter);
        
        assertEq(wbtcBalanceAfter, wbtcBalanceBefore - collAmount, "WBTC balance after should have been reduced by the collateral amount");
        assertEq(feusdBalanceAfter, feusdBalanceBefore + boldAmount, "feUSD balance after should have increased by the boldAmount");

        console.logString("testBtcCarryStrategyExecution complete");
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}