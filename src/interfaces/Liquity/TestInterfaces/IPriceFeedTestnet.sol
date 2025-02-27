// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "../IPriceFeed.sol";

interface IPriceFeedTestnet is IPriceFeed {
    function setPrice(uint256 _price) external returns (bool);
    function getPrice() external view returns (uint256);
}
