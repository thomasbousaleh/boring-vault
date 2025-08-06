// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {StHypeLoopBase} from "./StHYPELoopBase.s.sol";
import {StHypeLoopLeg1StakeScript} from "./StHYPELoopLeg1Stake.s.sol";
import {StHypeLoopLeg2DepositScript} from "./StHYPELoopLeg2Deposit.s.sol";
import {StHypeLoopLeg2BorrowScript} from "./StHYPELoopLeg2Borrow.s.sol";

import {IMorpho, Id, Position, Market, MarketParams} from "./interfaces/IMorpho.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract StHYPELoopStrategyScript is StHypeLoopBase {
    uint256 public constant BORROW_HEALTH_THRESHOLD_WAD = 860000000000000000;

    function run() external {
        console.log("Starting StHYPE Loop Strategy Script");

        initChainSetup();
        loadDeployedContracts();

        /*

        // ──────────────────────────────
        // STEP 1: Stake wHYPE to stHYPE
        // ──────────────────────────────
        StHypeLoopLeg1StakeScript stakeScript = new StHypeLoopLeg1StakeScript();
        stakeScript.run();

        // ────────────────────────────────────────────────
        // STEP 2: Deposit stHYPE to Felix (supplyCollateral)
        // ────────────────────────────────────────────────
        StHypeLoopLeg2DepositScript depositScript = new StHypeLoopLeg2DepositScript();
        depositScript.run();

        */

        // ──────────────────────────────────────────────────────────────
        // STEP 3: Check health factor, and borrow if under threshold
        // ──────────────────────────────────────────────────────────────
        MarketParams memory depositParams = MarketParams({
            loanToken:      0x5555555555555555555555555555555555555555,
            collateralToken:0x94e8396e0869c9F2200760aF0621aFd240E1CF38,
            oracle:         0xD767818Ef397e597810cF2Af6b440B1b66f0efD3,
            irm:            0xD4a426F010986dCad727e8dd6eed44cA4A9b7483,
            lltv:           860000000000000000
        });
        Id marketId = Id.wrap(0xe9a9bb9ed3cc53f4ee9da4eea0370c2c566873d5de807e16559a99907c9ae227);
        address vault = address(boringVault);

        Position memory pos = morpho.position(marketId, vault);
        uint128 borrowShares = pos.borrowShares;
        uint128 collateral = pos.collateral;

        Market memory m = morpho.market(marketId);
        uint128 totalBorrowAssets = m.totalBorrowAssets;
        uint128 totalBorrowShares = m.totalBorrowShares;

        // Calculate borrowed in asset terms
        uint256 borrowedAssets = borrowShares == 0 ? 0 :
            uint256(borrowShares) * totalBorrowAssets / totalBorrowShares;

        console.log("Loan Token:", depositParams.loanToken);
        console.log("Collateral Token:", depositParams.collateralToken);
        console.log("Oracle:", depositParams.oracle);
        console.log("IRM:", depositParams.irm);
        console.log("LLTV:", depositParams.lltv);

        console.log("Vault Position - Borrow Shares:", borrowShares);
        console.log("Vault Position - Collateral:", collateral);

        console.log("Market Stats - Total Borrow Assets:", totalBorrowAssets);
        console.log("Market Stats - Total Borrow Shares:", totalBorrowShares);

        console.log("Borrowed Assets:", borrowedAssets);

        // Calculate max borrow allowed
        // uint256 collateralValue = uint256(collateral) * oraclePrice / ORACLE_PRICE_SCALE;
        // uint256 maxBorrow = collateralValue * marketParams.lltv / WAD;

        // Calculate health factor
        // uint256 healthFactor = borrowedAssets * WAD / (maxBorrow == 0 ? 1 : maxBorrow);

        // console.log("Collateral:", collateral);
        // console.log("Oracle Price:", oraclePrice);
        // console.log("Max Borrow:", maxBorrow);
        // console.log("Borrowed Assets:", borrowedAssets);
        // console.log("Health Factor (WAD):", healthFactor);

        /* 
        if (healthFactor < BORROW_HEALTH_THRESHOLD_WAD) {
            console.log("Health good, borrowing more.");
            StHYPELoopLeg2BorrowScript borrowScript = new StHYPELoopLeg2BorrowScript();
            borrowScript.run();
        } else {
            console.log("Skipping borrow, health factor too high.");
        }
        */
    }
}