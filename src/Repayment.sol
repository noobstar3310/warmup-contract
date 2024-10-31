// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./LendingPool.sol";
import "./BorrowingContract.sol";

contract Repayment {
    LendingPool public lendingPool;
    BorrowingContract public borrowingContract;

    event LoanRepaid(
        address indexed borrower, 
        uint256 principalPaid, 
        uint256 interestPaid, 
        bool fullyRepaid
    );

    constructor(address _lendingPool, address _borrowingContract) {
        lendingPool = LendingPool(_lendingPool);
        borrowingContract = BorrowingContract(_borrowingContract);
    }

    // Modifier to check if repayment amount is valid
    modifier validRepaymentAmount(uint256 repaymentAmount) {
        (,uint256 activeLoanAmount, uint256 paybackAmount,) = borrowingContract.getBorrowerInfo(msg.sender);
        require(activeLoanAmount > 0, "No active loan");
        require(repaymentAmount <= paybackAmount, "Amount exceeds payback amount");
        _;
    }

    // Function to repay loan
    function repayLoan() external payable validRepaymentAmount(msg.value) {
        (,uint256 activeLoanAmount, uint256 paybackAmount,) = borrowingContract.getBorrowerInfo(msg.sender);
        
        // Calculate interest portion
        uint256 interestAmount = paybackAmount - activeLoanAmount;
        
        // Handle interest first
        uint256 interestPaid;
        uint256 principalPaid;
        
        if (msg.value >= interestAmount) {
            // Pay full interest
            interestPaid = interestAmount;
            principalPaid = msg.value - interestAmount;
            
            // Update lending pool with interest
            lendingPool.addInterest{value: interestPaid}();
            
            // Update lending pool with principal
            if (principalPaid > 0) {
                lendingPool.repayPrincipal{value: principalPaid}();
            }
        } else {
            // Partial interest payment
            interestPaid = msg.value;
            principalPaid = 0;
            lendingPool.addInterest{value: interestPaid}();
        }

        // Check if loan is fully repaid
        bool isFullyRepaid = (msg.value == paybackAmount);
        
        // Update borrower information in borrowing contract
        borrowingContract.updateLoanAfterRepayment(
            msg.sender, 
            principalPaid, 
            interestPaid, 
            isFullyRepaid
        );

        emit LoanRepaid(msg.sender, principalPaid, interestPaid, isFullyRepaid);
    }

    // Function to get remaining repayment amount
    function getRemainingRepayment(address borrower) external view returns (
        uint256 remainingPrincipal,
        uint256 remainingInterest
    ) {
        (,uint256 activeLoanAmount, uint256 paybackAmount,) = borrowingContract.getBorrowerInfo(borrower);
        uint256 totalInterest = paybackAmount - activeLoanAmount;
        return (activeLoanAmount, totalInterest);
    }

    receive() external payable {}
}