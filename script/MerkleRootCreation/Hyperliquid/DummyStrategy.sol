// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DummyStrategy {
    address public immutable vault;

    constructor(address _vault) {
        vault = _vault;
    }

    function onDeposit(address /* token */, uint256 /* amount */) external view {
        require(msg.sender == vault, "Not vault");
    }

    function onWithdraw(address token, uint256 amount, address to) external {
        require(msg.sender == vault, "Not vault");
        IERC20(token).transfer(to, amount);
    }
}