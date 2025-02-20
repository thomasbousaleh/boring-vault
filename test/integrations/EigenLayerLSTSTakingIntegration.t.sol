// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    StakingDecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/StakingDecoderAndSanitizer.sol";

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EigenLayerLSTStakingIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new StakingDecoderAndSanitizer());

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
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testEigenLayerLSTStakingIntegration() external {
        // Fund the BoringVault with 1,000 METH tokens.
        deal(getAddress(sourceChain, "METH"), address(boringVault), 1_000e18);

        // ----- Setup: Prepare ManageLeafs for operations -----
        // Create an array of 8 ManageLeaf structs for various operations (approve, deposit, withdrawal queue, etc.).
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "METH"),              // Token address (METH)
            getAddress(sourceChain, "mETHStrategy"),        // Strategy address for deposits
            getAddress(sourceChain, "strategyManager"),     // Manager for handling strategy deposits
            getAddress(sourceChain, "delegationManager"),   // Manager for handling withdrawals
            address(0),                                     // No delegation operator in this context
            getAddress(sourceChain, "eigenRewards"),        // EigenLayer rewards contract address
            address(0)                                      // No extra address parameter
        );

        // Generate a Merkle Tree from the prepared ManageLeafs
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        // Set the Merkle root in the manager contract for later verification
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // ----- Part 1: Execute initial operations (approve, deposit, and queue withdrawal) -----
        // Select the first three operations from the leafs array
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        // Generate Merkle proofs for the selected operations
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Define target contracts for the operations:
        // [0] METH token (for approving spending), [1] strategyManager (for depositing),
        // [2] delegationManager (for queuing the withdrawal request)
        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "METH");
        targets[1] = getAddress(sourceChain, "strategyManager");
        targets[2] = getAddress(sourceChain, "delegationManager");

        // Prepare encoded function calls for each target
        bytes[] memory targetData = new bytes[](3);
        // Approve the strategyManager to spend METH tokens on behalf of the caller
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "strategyManager"), type(uint256).max
        );
        // Deposit 1,000 METH tokens into the mETHStrategy via the strategyManager
        targetData[1] = abi.encodeWithSignature(
            "depositIntoStrategy(address,address,uint256)",
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "METH"),
            1_000e18
        );
        // Queue a withdrawal request: setup withdrawal parameters for later completion
        DecoderCustomTypes.QueuedWithdrawalParams[] memory queuedParams =
            new DecoderCustomTypes.QueuedWithdrawalParams[](1);
        queuedParams[0].strategies = new address[](1);
        queuedParams[0].strategies[0] = getAddress(sourceChain, "mETHStrategy");
        queuedParams[0].shares = new uint256[](1);
        queuedParams[0].shares[0] = 1_000e18;
        queuedParams[0].withdrawer = address(boringVault);
        targetData[2] = abi.encodeWithSignature("queueWithdrawals((address[],uint256[],address)[])", queuedParams);

        // Set up decoder/sanitizer contracts for each operation
        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        // No ETH value is sent with these calls
        uint256[] memory values = new uint256[](3);

        // Execute the batch of operations with Merkle verification
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // ----- Part 2: Finalize withdrawal after required delay -----
        // Record the block number at which the withdrawal was requested
        uint32 withdrawRequestBlock = uint32(block.number);
        // Advance the blockchain by 50400 blocks to simulate the mandatory waiting period
        vm.roll(block.number + 50400);

        // ----- Part 3: Complete the queued withdrawal -----
        // Select the ManageLeaf corresponding to the withdrawal completion operation (leafs[3])
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

        // Generate the Merkle proof for the withdrawal completion operation
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Define the target contract for completing the withdrawal (delegationManager)
        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "delegationManager");

        // Prepare encoded call data to complete the queued withdrawal
        targetData = new bytes[](1);
        // Set up withdrawal parameters: staker is the BoringVault, no delegation, nonce is 0
        // Use mETHStrategy and specify the shares to withdraw
        DecoderCustomTypes.Withdrawal[] memory withdrawParams = new DecoderCustomTypes.Withdrawal[](1);
        withdrawParams[0].staker = address(boringVault);
        withdrawParams[0].delegatedTo = address(0);
        withdrawParams[0].withdrawer = address(boringVault);
        withdrawParams[0].nonce = 0;
        withdrawParams[0].startBlock = withdrawRequestBlock;
        withdrawParams[0].strategies = new address[](1);
        withdrawParams[0].strategies[0] = getAddress(sourceChain, "mETHStrategy");
        withdrawParams[0].shares = new uint256[](1);
        withdrawParams[0].shares[0] = 1_000e18;
        // Define the tokens involved in the withdrawal; in this case, the METH token
        address[][] memory tokens = new address[][](1);
        tokens[0] = new address[](1);
        tokens[0][0] = getAddress(sourceChain, "METH");
        // Setup middleware parameters (here, an index of 0)
        uint256[] memory middlewareTimesIndexes = new uint256[](1);
        middlewareTimesIndexes[0] = 0;
        // Indicate that the withdrawal should result in tokens being received
        bool[] memory receiveAsTokens = new bool[](1);
        receiveAsTokens[0] = true;
        // Encode the completeQueuedWithdrawals function call with all parameters
        targetData[0] = abi.encodeWithSignature(
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
            withdrawParams,
            tokens,
            middlewareTimesIndexes,
            receiveAsTokens
        );

        // Set up the decoder for the withdrawal completion operation
        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // No ETH value is attached to this call
        values = new uint256[](1);

        // Execute the complete withdrawal operation with Merkle verification
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // ----- Final Assertion: Confirm that the BoringVault received 1,000 METH tokens -----
        assertEq(
            getERC20(sourceChain, "METH").balanceOf(address(boringVault)),
            1_000e18,
            "BoringVault should have received 1,000 METH"
        );
    }

    function testEigenLayerLSTStakingReverts() external {
        deal(getAddress(sourceChain, "METH"), address(boringVault), 1_000e18);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "METH"),
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            address(0),
            getAddress(sourceChain, "eigenRewards"),
            address(0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "METH");
        targets[1] = getAddress(sourceChain, "strategyManager");
        targets[2] = getAddress(sourceChain, "delegationManager");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "strategyManager"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "depositIntoStrategy(address,address,uint256)",
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "METH"),
            1_000e18
        );
        DecoderCustomTypes.QueuedWithdrawalParams[] memory queuedParams =
            new DecoderCustomTypes.QueuedWithdrawalParams[](1);
        queuedParams[0].strategies = new address[](1);
        queuedParams[0].strategies[0] = getAddress(sourceChain, "mETHStrategy");
        queuedParams[0].shares = new uint256[](1);
        queuedParams[0].shares[0] = 1_000e18;
        queuedParams[0].withdrawer = address(boringVault);
        targetData[2] = abi.encodeWithSignature("queueWithdrawals((address[],uint256[],address)[])", queuedParams);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Finalize withdraw requests.
        // Must wait atleast delegationManager.minWithdrawalDelayBlocks() blocks which is 50400.
        uint32 withdrawRequestBlock = uint32(block.number);
        vm.roll(block.number + 50400);

        // Complete the withdrawal
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "delegationManager");

        targetData = new bytes[](1);
        DecoderCustomTypes.Withdrawal[] memory withdrawParams = new DecoderCustomTypes.Withdrawal[](1);
        withdrawParams[0].staker = address(boringVault);
        withdrawParams[0].delegatedTo = address(0);
        withdrawParams[0].withdrawer = address(boringVault);
        withdrawParams[0].nonce = 0;
        withdrawParams[0].startBlock = withdrawRequestBlock;
        withdrawParams[0].strategies = new address[](1);
        withdrawParams[0].strategies[0] = getAddress(sourceChain, "mETHStrategy");
        withdrawParams[0].shares = new uint256[](1);
        withdrawParams[0].shares[0] = 1_000e18;
        address[][] memory tokens = new address[][](1);
        tokens[0] = new address[](1);
        tokens[0][0] = getAddress(sourceChain, "METH");
        uint256[] memory middlewareTimesIndexes = new uint256[](1);
        middlewareTimesIndexes[0] = 0;
        bool[] memory receiveAsTokens = new bool[](1);
        receiveAsTokens[0] = false;
        targetData[0] = abi.encodeWithSignature(
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
            withdrawParams,
            tokens,
            middlewareTimesIndexes,
            receiveAsTokens
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    EigenLayerLSTStakingDecoderAndSanitizer
                        .EigenLayerLSTStakingDecoderAndSanitizer__CanOnlyReceiveAsTokens
                        .selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testDelegation() external {
        deal(getAddress(sourceChain, "METH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "METH"),
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "testOperator"),
            getAddress(sourceChain, "eigenRewards"),
            address(0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[4];
        manageLeafs[1] = leafs[5];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "delegationManager");
        targets[1] = getAddress(sourceChain, "delegationManager");

        bytes[] memory targetData = new bytes[](2);
        DecoderCustomTypes.SignatureWithExpiry memory signatureWithExpiry;
        targetData[0] = abi.encodeWithSignature(
            "delegateTo(address,(bytes,uint256),bytes32)",
            getAddress(sourceChain, "testOperator"),
            signatureWithExpiry,
            bytes32(0)
        );
        targetData[1] = abi.encodeWithSignature("undelegate(address)", boringVault);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
