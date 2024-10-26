// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "lib/chainlink/contracts/src/v0.8/sharedinterfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract BorrowingMechanism {
    using PriceConverter for uint256;

    struct Loan {
        uint256 borrowedAmount;
        uint256 collateralAmount;
        uint256 timestamp;
    }

    mapping(address => Loan) public loans;

    AggregatorV3Interface public immutable ethUsdPriceFeed;

    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization ratio
    uint256 public constant INTEREST_RATE = 5; // 5% annual interest rate
    uint256 public constant SECONDS_PER_YEAR = 31536000; // 365 days

    event Borrow(address indexed borrower, uint256 borrowedAmount, uint256 collateralAmount);
    event Repay(address indexed borrower, uint256 repaidAmount, uint256 interest);

    function borrow(uint256 borrowAmount) external payable {
        require(borrowAmount > 0, "Borrow amount must be greater than 0");
        require(loans[msg.sender].borrowedAmount == 0, "Existing loan must be repaid first");

        uint256 requiredCollateral = calculateRequiredCollateral(borrowAmount);
        require(msg.value >= requiredCollateral, "Insufficient collateral");

        loans[msg.sender] = Loan({
            borrowedAmount: borrowAmount,
            collateralAmount: msg.value,
            timestamp: block.timestamp
        });

        // Transfer borrowed ETH to the borrower
        payable(msg.sender).transfer(borrowAmount);

        emit Borrow(msg.sender, borrowAmount, msg.value);
    }

    function repay() external payable {
        Loan storage loan = loans[msg.sender];
        require(loan.borrowedAmount > 0, "No existing loan");

        uint256 interest = calculateInterest(loan.borrowedAmount, loan.timestamp);
        uint256 totalRepayment = loan.borrowedAmount + interest;

        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        // Return collateral
        uint256 collateralToReturn = loan.collateralAmount;

        // Clear the loan before transfers to prevent reentrancy
        delete loans[msg.sender];

        // Return collateral
        payable(msg.sender).transfer(collateralToReturn);

        // Refund any excess payment
        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit Repay(msg.sender, loan.borrowedAmount, interest);
    }

    function calculateRequiredCollateral(uint256 borrowAmount) public view returns (uint256) {
        uint256 ethUsdPrice = uint256(ethUsdPriceFeed.latestAnswer());
        uint256 requiredCollateralUsd = (borrowAmount * COLLATERAL_RATIO) / 100;
        uint256 requiredCollateral = (requiredCollateralUsd * 1e18) / ethUsdPrice;
        return requiredCollateral;
    }

    function calculateInterest(uint256 amount, uint256 timestamp) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - timestamp;
        return (amount * INTEREST_RATE * timeElapsed) / (100 * SECONDS_PER_YEAR);
    }

    receive() external payable {}
}