// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBoringVault {
    function setStrategy(address token, address strategy) external;
}