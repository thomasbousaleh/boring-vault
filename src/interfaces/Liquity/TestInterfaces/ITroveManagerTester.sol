// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "../ITroveManager.sol";

interface ITroveManagerTester is ITroveManager {
    function liquidate(uint256 _troveId) external;

    function get_CCR() external view returns (uint256);
    function get_MCR() external view returns (uint256);
    function get_SCR() external view returns (uint256);
    function get_LIQUIDATION_PENALTY_SP() external view returns (uint256);
    function get_LIQUIDATION_PENALTY_REDISTRIBUTION() external view returns (uint256);

    function getBoldToken() external view returns (IBoldToken);
    function getBorrowerOperations() external view returns (IBorrowerOperations);

    function get_L_coll() external view returns (uint256);
    function get_L_boldDebt() external view returns (uint256);
    function getTotalStakes() external view returns (uint256);
    function getTotalStakesSnapshot() external view returns (uint256);
    function getTotalCollateralSnapshot() external view returns (uint256);
    function get_lastCollError_Redistribution() external view returns (uint256);
    function get_lastBoldDebtError_Redistribution() external view returns (uint256);
    function getTroveId(uint256 _index) external view returns (uint256);

    function getTCR(uint256 _price) external view returns (uint256);

    function checkBelowCriticalThreshold(uint256 _price) external view returns (bool);

    function computeICR(uint256 _coll, uint256 _debt, uint256 _price) external pure returns (uint256);
    function getCollGasCompensation(uint256 _coll) external pure returns (uint256);

    function getEffectiveRedemptionFeeInColl(uint256 _redeemAmount, uint256 _price) external view returns (uint256);

    function callInternalRemoveTroveId(uint256 _troveId) external;

    function ownerOf(uint256 _troveId) external view returns (address);
    function balanceOf(address _account) external view returns (uint256);

    // Trove and batch getters
    function checkTroveIsActive(uint256 _troveId) external view returns (bool);
    function checkTroveIsOpen(uint256 _troveId) external view returns (bool);
    function checkTroveIsZombie(uint256 _troveId) external view returns (bool);

    function hasRedistributionGains(uint256 _troveId) external view returns (bool);

    function getPendingCollReward(uint256 _troveId) external view returns (uint256);

    function getPendingBoldDebtReward(uint256 _troveId) external view returns (uint256);

    function getEntireDebtAndColl(uint256 _troveId)
        external
        view
        returns (
            uint256 entireDebt,
            uint256 entireColl,
            uint256 pendingBoldDebtReward,
            uint256 pendingCollReward,
            uint256 accruedTroveInterest
        );

    function getTroveEntireDebt(uint256 _troveId) external view returns (uint256);

    function getTroveEntireColl(uint256 _troveId) external view returns (uint256);

    //function getTroveStatus(uint256 _troveId) external view returns (Status);

    function getTroveStake(uint256 _troveId) external view returns (uint256);

    function getTroveDebt(uint256 _troveId) external view returns (uint256);

    function getTroveWeightedRecordedDebt(uint256 _troveId) external returns (uint256);

    function getTroveColl(uint256 _troveId) external view returns (uint256);

    function getTroveLastDebtUpdateTime(uint256 _troveId) external view returns (uint256);

    function troveIsStale(uint256 _troveId) external view returns (bool);

    function calcTroveAccruedInterest(uint256 _troveId) external view returns (uint256);
    function calcTroveAccruedBatchManagementFee(uint256 _troveId) external view returns (uint256);
    function calcBatchAccruedInterest(address _batchAddress) external view returns (uint256);
    function calcBatchAccruedManagementFee(address _batchAddress) external view returns (uint256);

    function getBatchAnnualInterestRate(address _batchAddress) external view returns (uint256);
    function getBatchLastDebtUpdateTime(address _batchAddress) external view returns (uint256);
    function getBatch(address _batchAddress)
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint64 arrayIndex,
            uint64 lastDebtUpdateTime,
            uint64 lastInterestRateAdjTime,
            uint256 annualInterestRate,
            uint256 annualManagementFee,
            uint256 totalDebtShares
        );

    // --- Functions for testing ---

    function getBorrowingRate() external pure returns (uint256);
    function getBorrowingRateWithDecay(uint256 _lastFeeOpTime) external pure returns (uint256);

    function getRedemptionFee(uint256 _price) external view returns (uint256);
    function getRedemptionPremium(uint256 _price) external view returns (uint256);
    function computeBetweenRedemptionAndLiquidations(uint256 _ETH, uint256 _BOLD) external view returns (uint256);
    function getFactor(uint256 _x1, uint256 _y1, uint256 _x2, uint256 _y2, uint256 _x) external pure returns (uint256);

    function getTroveFeeBips(uint256 _troveId) external view returns (uint256);
    function getTroveStatus(uint256 _troveId) external view returns (Status);
    function getTroveNFTOwner(uint256 _troveId) external view returns (address);
    function getTroveLogs(uint256 _troveId) external view returns (bytes32[] memory);
    function getZombieUnlockedColl(uint256 _troveId) external view returns (uint256);

    function getTotalInterests() external view returns (uint256);

    function getTroveOwnerId(address _borrower) external view returns (uint256);
    function getTroveFromNFTId(uint256 _nftId) external view returns (uint256);

    function getCurrentSharedPrice() external view returns (uint256);
    function getCurrentSharedPriceAll() external view returns (
        uint256 price,
        uint256 troveCount,
        uint256 pendingRedistributedDebt,
        uint256 pendingRedistributedColl,
        uint256 zombiesCount,
        uint256 lastZombieId
    );

    // Renamed to TrovesExtended to avoid conflict with ITroveManager.Troves
    function TrovesExtended(uint256 _troveId)
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            address nftOwner,
            uint256 status,
            uint256 arrayIndex,
            uint256 feeBips,
            address batchMananger,
            uint256 nextTroveId,
            uint256 previousTroveId,
            uint256 unlockTime,
            uint256 pendingBatchReward,
            uint256 stabilityFee,
            uint256 unlockedColl,
            uint256 interestRate,
            uint256 lastInterestRate,
            uint256 lastInterestTimeUpdated,
            uint256 lastFeeOperationTime
        );

    function addTroveOwnerToArray(address _borrower) external returns (uint256 index);

    function getRedemptionRate() external view returns (uint256);
    function getRedemptionRateWithDecay(uint256 _lastRedemptionTimestamp) external view returns (uint256);

    function lastZombie() external view returns (uint256);
    function getNominalICR(uint256 _troveId) external view returns (uint256);
    function getCurrentICR(uint256 _troveId, uint256 _price) external view returns (uint256);

    function getCandidate(uint256 _troveId) external view returns (uint256 next, uint256 prev);
    function shouldInterestBeUpdated(uint256 _troveId) external view returns (bool);
}
