// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "../IPriceFeed.sol";

interface IPriceFeedMock is IPriceFeed {
    function setPrice(uint256 _price) external;
}
