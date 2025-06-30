// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../StHYPELoopingStrategy/StHYPELoopingStrategy.sol";

contract MockERC20 is IERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract MockVault is IBoringVault {
    function withdraw(address asset, address, address to, uint256 amount) external override {
        // mint the asset token to the recipient
        MockERC20(asset).mint(to, amount);
    }

    function deposit(address asset, address, address to, uint256 amount, uint256) external override {
        // mint the asset token to the recipient
        MockERC20(asset).mint(to, amount);
    }
}

contract MockStHYPE is IStHYPE, IERC20 {
    mapping(address => uint256) public balanceOf;
    string public name = "stHYPE";
    string public symbol = "stHYPE";
    uint8 public decimals = 18;

    function stake(uint256 amount) external override returns (uint256) {
        balanceOf[msg.sender] += amount;
        return amount;
    }

    function approve(address, uint256) public pure override returns (bool) {
        return true;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }

    function totalSupply() external pure override returns (uint256) {
        return 0;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }
}

contract MockFelix is IFelixMarket {
    function supplyCollateral(address, uint256) external override {}
    function borrow(address, uint256) external override {}
}

contract MockWETH is MockERC20, IWETH {
    function wrap(uint256 amount) external override returns (uint256) {
        mint(msg.sender, amount);
        return amount;
    }
}

contract StHypeLoopingStrategyTest is Test {
    StHypeLoopingStrategy public strategy;
    MockVault public vault;
    MockERC20 public hype;
    MockWETH public wHype;
    MockStHYPE public stHype;
    MockFelix public felix;

    address public manager = address(this);

    function setUp() public {
        vault = new MockVault();
        hype = new MockERC20();
        wHype = new MockWETH();
        stHype = new MockStHYPE();
        felix = new MockFelix();

        strategy = new StHypeLoopingStrategy(
            vault,
            hype,
            wHype,
            stHype,
            felix,
            manager
        );

        wHype.mint(address(strategy), 1000 ether);
    }

    function testLoopExecutesSuccessfully() public {
        strategy.loop(3, 100 ether);
    }

    function testOnlyManagerCanLoop() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("Not manager");
        strategy.loop(1, 10 ether);
    }

    function testManagerCanUpdate() public {
        strategy.setManager(address(0xABCD));
        assertEq(strategy.manager(), address(0xABCD));
    }
}