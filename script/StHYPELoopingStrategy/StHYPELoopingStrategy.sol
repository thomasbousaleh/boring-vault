// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function wrap(uint256 amount) external returns (uint256);
}

interface IStHYPE {
    function stake(uint256 amount) external returns (uint256);
}

interface IFelixMarket {
    function supplyCollateral(address token, uint256 amount) external;
    function borrow(address token, uint256 amount) external;
}

interface IBoringVault {
    function withdraw(address token, address from, address to, uint256 amount) external;
    function deposit(address token, address from, address to, uint256 amount, uint256 share) external;
}

contract StHypeLoopingStrategy {
    IBoringVault public immutable vault;
    IERC20 public immutable hype;
    IWETH public immutable wHype;
    IStHYPE public immutable stHype;
    IFelixMarket public immutable felix;

    address public manager;

    event LoopExecuted(uint256 loops, uint256 finalWethAmount);
    event ManagerChanged(address oldManager, address newManager);

    constructor(
        IBoringVault _vault,
        IERC20 _hype,
        IWETH _wHype,
        IStHYPE _stHype,
        IFelixMarket _felix,
        address _manager
    ) {
        vault = _vault;
        hype = _hype;
        wHype = _wHype;
        stHype = _stHype;
        felix = _felix;
        manager = _manager;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Not manager");
        _;
    }

    function loop(uint256 iterations, uint256 amount) external onlyManager {
        // Withdraw initial wHYPE from vault
        vault.withdraw(address(wHype), address(this), address(this), amount);

        for (uint256 i = 0; i < iterations; i++) {
            amount = _stakeWrapSupplyBorrow(amount);
        }

        // Optionally re-deposit looped wHYPE to vault
        wHype.approve(address(vault), amount);
        vault.deposit(address(wHype), address(this), address(this), amount, 0);

        emit LoopExecuted(iterations, amount);
    }

    function _stakeWrapSupplyBorrow(uint256 wHypeIn) internal returns (uint256 wHypeOut) {
        // Stake wHYPE → stHYPE
        wHype.approve(address(stHype), wHypeIn);
        uint256 stHypeAmount = stHype.stake(wHypeIn);

        // Supply stHYPE as collateral
        IERC20(address(stHype)).approve(address(felix), stHypeAmount);
        felix.supplyCollateral(address(stHype), stHypeAmount);

        // Borrow HYPE (example: 50% LTV)
        uint256 borrowAmount = stHypeAmount / 2;
        felix.borrow(address(hype), borrowAmount);

        // Wrap to wHYPE
        hype.approve(address(wHype), borrowAmount);
        wHypeOut = wHype.wrap(borrowAmount);
    }

    function setManager(address newManager) external onlyManager {
        emit ManagerChanged(manager, newManager);
        manager = newManager;
    }
}