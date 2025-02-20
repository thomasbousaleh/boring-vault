// pragma solidity 0.8.21;
// // SPDX-License-Identifier: UNLICENSED

// import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol"; 
// import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
// import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
// import {ERC20} from "@solmate/tokens/ERC20.sol";
// import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
// import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
// import {BoringVault} from "src/base/BoringVault.sol";
// import {FelixDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FelixDecoderAndSanitizer.sol";
// import {HyperliquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HyperliquidDecoderAndSanitizer.sol";
// import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
// import {IBorrowerOperations} from "src/interfaces/Liquity/IBorrowerOperations.sol";
// import {IL1Write} from "src/interfaces/Hyperliquid/IL1Write.sol";

// contract FelixMock {
//     uint256 public borrowedFeUSD;
//     function createTroveAndBorrow(address, uint256 collateralAmount) external {
//         borrowedFeUSD = collateralAmount * 2;
//     }
// }

// contract SwapMock {
//     function swapFeUSDToUSDC(uint256 feUSDAmount) external pure returns (uint256) {
//         return feUSDAmount;
//     }
// }

// contract HyperliquidMock {
//     uint256 public depositedUSDC;
//     function depositUSDC(uint256 amount) external {
//         depositedUSDC += amount;
//     }
// }

// // --- Test Contract ---

// contract BtcCarryIntegrationTest is Test, MerkleTreeHelper {
//     using SafeTransferLib for ERC20;
//     using FixedPointMathLib for uint256;
//     using stdStorage for StdStorage;

//     ManagerWithMerkleVerification public manager;
//     address public btcCarryUser;
//     BoringVault public boringVault;
//     address public rawDataDecoderAndSanitizer;
//     RolesAuthority public rolesAuthority;

//     uint8 public constant MANAGER_ROLE = 1;
//     uint8 public constant STRATEGIST_ROLE = 2;
//     uint8 public constant MANGER_INTERNAL_ROLE = 3;
//     uint8 public constant ADMIN_ROLE = 4;
//     uint8 public constant BORING_VAULT_ROLE = 5;
//     uint8 public constant BALANCER_VAULT_ROLE = 6;

//     address public wBTCOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
//     address public feUSDOracle = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    
//     ERC20 public wBTC;
//     ERC20 public feUSD;

//     IBorrowerOperations public felix;
//     SwapMock public swap;
//     IL1Write public hyperliquid;
    
//     // Fork variables
//     uint256 public forkId;

//     function setUp() external {
//         // Set source chain name to "hyperliquid" explicitly.
//         setSourceChainName("hyperliquid");

//         // Start a fork using the hyperliquid RPC URL and a specified block.
//         string memory rpcKey = "HYPERLIQUID_RPC_URL";
//         uint256 forkBlockNumber = 73609; // Using valid block number 73609 on hyperliquid.
//         forkId = vm.createFork(vm.envString(rpcKey), forkBlockNumber);
//         vm.selectFork(forkId);

//         // Retrieve deployed protocol addresses on hyperliquid.
//         felix = IBorrowerOperations(getAddress("hyperliquid", "felix"));
//         swap = SwapMock(getAddress("hyperliquid", "swap"));
//         hyperliquid = IL1Write(getAddress("hyperliquid", "hyperliquid"));
//         wBTC = ERC20(getAddress("hyperliquid", "wBTC"));
//         feUSD = ERC20(getAddress("hyperliquid", "feUSD"));

//         boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

//         // Deploy the manager contract.
//         manager = new ManagerWithMerkleVerification(address(this), address(this), getAddress(sourceChain, "vault"));

//         rawDataDecoderAndSanitizer = address(new StakingDecoderAndSanitizer());

//         setAddress(false, sourceChain, "boringVault", address(boringVault));
//         setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
//         setAddress(false, sourceChain, "manager", address(manager));
//         setAddress(false, sourceChain, "managerAddress", address(manager));
//         setAddress(false, sourceChain, "accountantAddress", address(1));

//         rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
//         boringVault.setAuthority(rolesAuthority);
//         manager.setAuthority(rolesAuthority);

//         // Setup roles authority.
//         rolesAuthority.setRoleCapability(
//             MANAGER_ROLE,
//             address(boringVault),
//             bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
//             true
//         );
//         rolesAuthority.setRoleCapability(
//             MANAGER_ROLE,
//             address(boringVault),
//             bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
//             true
//         );

//         rolesAuthority.setRoleCapability(
//             STRATEGIST_ROLE,
//             address(manager),
//             ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
//             true
//         );
//         rolesAuthority.setRoleCapability(
//             MANGER_INTERNAL_ROLE,
//             address(manager),
//             ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
//             true
//         );
//         rolesAuthority.setRoleCapability(
//             ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
//         );
//         rolesAuthority.setRoleCapability(
//             BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
//         );
//         rolesAuthority.setRoleCapability(
//             BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
//         );

//         // Grant roles
//         rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
//         rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
//         rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
//         rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
//         rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
//         rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

//         btcCarryUser = address(0xABCD);

//         // Set addresses in our MerkleTreeHelper.
//         setAddress(true, "hyperliquid", "felix", address(felix));
//         setAddress(true, "hyperliquid", "swap", address(swap));
//         setAddress(true, "hyperliquid", "hyperliquid", address(hyperliquid));
//         setAddress(true, "hyperliquid", "wBTC", address(wBTC));
//         setAddress(true, "hyperliquid", "feUSD", address(feUSD));
//         setAddress(true, "hyperliquid", "vault", address(manager));
//         setAddress(false, "hyperliquid", "rawDataDecoderAndSanitizer", address(this));

//         // Fund btcCarryUser.
//         deal(address(wBTC), btcCarryUser, 10 * 10 ** 8);
//     }
    
//     // Dummy function for the dummy leaf.
//     function dummy() external {}

//     function testBtcCarryStrategyExecution() external {
//         deal(getAddress(sourceChain, "WBTC"), address(boringVault), 1_000e18);

//         // ----- Setup: Prepare ManageLeafs for operations -----
//         // Create an array of 8 ManageLeaf structs for various operations (approve, deposit, withdrawal queue, etc.).
//         ManageLeaf[] memory leafs = new ManageLeaf[](8);

//         _addFelixLeafs(
            
//         )
//     }

//     // function testBtcCarryStrategyExecution() external {
//     //     // Step 1: User deposits 1 wBTC.
//     //     uint256 depositAmount = 1 * 10 ** 8;
//     //     vm.prank(btcCarryUser);
//     //     wBTC.transfer(address(manager), depositAmount);

//     //     // Reset leafIndex.
//     //     leafIndex = type(uint256).max;

//     //     // Step 2: Build Merkle leaves for 4 leaves: Felix, Swap, Hyperliquid, Dummy.
//     //     MerkleTreeHelper.ManageLeaf[] memory leafs = new MerkleTreeHelper.ManageLeaf[](4);

//     //     _addFelixLeafs(
//     //         leafs,
//     //         FelixOperation.CreateTrove,
//     //         address(felix),
//     //         address(felix),
//     //         address(felix),
//     //         address(felix),
//     //         address(felix),
//     //         address(felix)
//     //     );
//     //     unchecked { leafIndex++; }
//     //     leafs[leafIndex] = MerkleTreeHelper.ManageLeaf(
//     //         address(swap),
//     //         false,
//     //         "swapFeUSDToUSDC(uint256)",
//     //         new address[](0),
//     //         "Swap feUSD to USDC",
//     //         address(0)
//     //     );
//     //     _addHyperliquidLeafs(
//     //         leafs,
//     //         HyperliquidOperation.DepositUSDC,
//     //         address(hyperliquid),
//     //         address(hyperliquid),
//     //         address(hyperliquid)
//     //     );
//     //     unchecked { leafIndex++; }
//     //     leafs[leafIndex] = MerkleTreeHelper.ManageLeaf(
//     //         address(this),
//     //         false,
//     //         "dummy()",
//     //         new address[](0),
//     //         "Dummy: no-op",
//     //         address(0)
//     //     );

//     //     uint256 numLeaves = leafIndex + 1; // Should be 4.
//     //     bytes32[][] memory manageTree = _generateMerkleTree(leafs);
//     //     manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
//     //     bytes32[][] memory proofs = _getProofsUsingTree(leafs, manageTree);

//     //     // Step 3: Prepare execution arrays.
//     //     address[] memory targets = new address[](numLeaves);
//     //     targets[0] = address(felix);
//     //     targets[1] = address(swap);
//     //     targets[2] = address(hyperliquid);
//     //     targets[3] = address(this);

//     //     bytes[] memory targetData = new bytes[](numLeaves);
//     //     targetData[0] = abi.encodeWithSignature("createTroveAndBorrow(address,uint256)", address(wBTC), depositAmount);
//     //     uint256 borrowedFeUSD = depositAmount * 2;
//     //     targetData[1] = abi.encodeWithSignature("swapFeUSDToUSDC(uint256)", borrowedFeUSD);
//     //     uint256 usdcAmount = borrowedFeUSD;
//     //     targetData[2] = abi.encodeWithSignature("sendVaultTransfer(address,bool,uint64)", address(0), true, uint64(usdcAmount));
//     //     targetData[3] = abi.encodeWithSignature("dummy()");

//     //     uint256[] memory values = new uint256[](numLeaves);
//     //     address[] memory decodersAndSanitizers = new address[](numLeaves);

//     //     // Step 4: Execute strategy calls.
//     //     manager.manageVaultWithMerkleVerification(proofs, decodersAndSanitizers, targets, targetData, values);

//     //     // Step 5: Assert outcomes.
//     //     // Skipping assertion on felix.borrowedFeUSD() as it's not exposed via IBorrowerOperations.
//     // }
// } 