// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract InterestDistribution {
    uint256 public totalInterestAccrued;
    uint256 public totalSupplied;
    mapping(address => uint256) public lenderDeposits;

    event InterestAdded(uint256 amount);
    event LenderDeposited(address indexed lender, uint256 amount);
    event LenderWithdrew(address indexed lender, uint256 amount);

    // Function to add interest to the pool when a loan is repaid
    function addInterest(uint256 interestAmount) external {
        totalInterestAccrued += interestAmount;
        emit InterestAdded(interestAmount);
    }

    // Function for lenders to withdraw their deposit
    function withdraw(uint256 amount) external {
        require(lenderDeposits[msg.sender] >= amount, "Insufficient balance");
        lenderDeposits[msg.sender] -= amount;
        totalSupplied -= amount;
        payable(msg.sender).transfer(amount);
        emit LenderWithdrew(msg.sender, amount);
    }

    // Function to get the total interest in the pool
    function getTotalInterest() external view returns (uint256) {
        return totalInterestAccrued;
    }

    // Function to calculate the lender's supply ratio
    function getLenderSupplyRatio(address lender) public view returns (uint256) {
        if (totalSupplied == 0) return 0;
        return (lenderDeposits[lender] * 1e18) / totalSupplied;
    }

    // Function to calculate the accumulated interest for a lender
    function getLenderAccumulatedInterest(address lender) external view returns (uint256) {
        uint256 supplyRatio = getLenderSupplyRatio(lender);
        return (supplyRatio * totalInterestAccrued) / 1e18;
    }
}