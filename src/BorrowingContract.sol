// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./LendingPool.sol";

contract BorrowingContract {
    LendingPool public lendingPool;

    struct Borrower {
        uint256 collateralAmount;
        uint256 activeLoanAmount;
        uint256 paybackAmount;
        uint256 borrowTimestamp;
    }

    // Constants
    uint256 public constant COLLATERAL_RATIO = 150; // 1.5 * 100
    uint256 public constant INTEREST_RATE = 105; // 1.05 * 100

    // Mappings and arrays to track borrowers
    mapping(address => Borrower) public borrowers;
    address[] public borrowerAddresses;

    // Events
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event LoanTaken(address indexed borrower, uint256 amount, uint256 paybackAmount);
    event LoanRepaid(address indexed borrower, uint256 amount);

    constructor(address _lendingPool) {
        lendingPool = LendingPool(_lendingPool);
    }

    // Modifier to check if borrower is eligible for the requested loan amount
    modifier isEligibleToBorrow(uint256 borrowAmount) {
        uint256 eligibleAmount = getEligibleLoanAmount(msg.sender);
        require(borrowAmount <= eligibleAmount, "Exceeds eligible borrow amount");
        _;
    }

    // Function to deposit collateral
    function depositCollateral() external payable {
        require(msg.value > 0, "Must deposit collateral");

        if (borrowers[msg.sender].collateralAmount == 0) {
            borrowerAddresses.push(msg.sender);
        }

        borrowers[msg.sender].collateralAmount += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    // Function to calculate eligible loan amount
    function getEligibleLoanAmount(address borrower) public view returns (uint256) {
        Borrower memory borrowerInfo = borrowers[borrower];
        uint256 maxLoanAmount = (borrowerInfo.collateralAmount * 100) / COLLATERAL_RATIO;
        
        if (borrowerInfo.activeLoanAmount >= maxLoanAmount) {
            return 0;
        }
        
        return maxLoanAmount - borrowerInfo.activeLoanAmount;
    }

    // Function to borrow ETH
    function borrow(uint256 borrowAmount) external isEligibleToBorrow(borrowAmount) {
        require(borrowAmount > 0, "Borrow amount must be greater than 0");
        require(address(lendingPool).balance >= borrowAmount, "Insufficient funds in lending pool");

        // Calculate payback amount (borrowed amount + 5% interest)
        uint256 paybackAmount = (borrowAmount * INTEREST_RATE) / 100;

        // Update borrower information. 
        Borrower storage borrower = borrowers[msg.sender];
        borrower.activeLoanAmount += borrowAmount;
        borrower.paybackAmount += paybackAmount;
        borrower.borrowTimestamp = block.timestamp;

        // Transfer borrowed amount to borrower
        (bool success, ) = payable(msg.sender).call{value: borrowAmount}("");
        require(success, "Transfer failed");

        emit LoanTaken(msg.sender, borrowAmount, paybackAmount);
    }

    // Function to repay loan
    function repayLoan() external payable {
        Borrower storage borrower = borrowers[msg.sender];
        require(borrower.activeLoanAmount > 0, "No active loan");
        require(msg.value >= borrower.paybackAmount, "Insufficient repayment amount");

        // Calculate interest portion
        uint256 interestAmount = borrower.paybackAmount - borrower.activeLoanAmount;

        // Send interest to lending pool
        (bool success, ) = address(lendingPool).call{value: interestAmount}("");
        require(success, "Interest transfer failed");

        // Clear borrower's loan information
        borrower.activeLoanAmount = 0;
        borrower.paybackAmount = 0;

        // Return excess payment if any
        if (msg.value > borrower.paybackAmount) {
            payable(msg.sender).transfer(msg.value - borrower.paybackAmount);
        }

        emit LoanRepaid(msg.sender, msg.value);
    }

    // Function to get all borrowers and their info
    function getAllBorrowers() external view returns (
        address[] memory,
        uint256[] memory, // collateral amounts
        uint256[] memory, // active loan amounts
        uint256[] memory  // payback amounts
    ) {
        uint256 length = borrowerAddresses.length;
        uint256[] memory collaterals = new uint256[](length);
        uint256[] memory loans = new uint256[](length);
        uint256[] memory paybacks = new uint256[](length);

        for (uint i = 0; i < length; i++) {
            address borrower = borrowerAddresses[i];
            collaterals[i] = borrowers[borrower].collateralAmount;
            loans[i] = borrowers[borrower].activeLoanAmount;
            paybacks[i] = borrowers[borrower].paybackAmount;
        }

        return (borrowerAddresses, collaterals, loans, paybacks);
    }

    // Function to get borrower's loan details
    function getBorrowerInfo(address borrower) external view returns (
        uint256 collateralAmount,
        uint256 activeLoanAmount,
        uint256 paybackAmount,
        uint256 borrowTimestamp
    ) {
        Borrower memory borrowerInfo = borrowers[borrower];
        return (
            borrowerInfo.collateralAmount,
            borrowerInfo.activeLoanAmount,
            borrowerInfo.paybackAmount,
            borrowerInfo.borrowTimestamp
        );
    }

    function updateLoanAfterRepayment(
        address borrower,
        uint256 principalPaid,
        uint256 interestPaid,
        bool fullyRepaid
    ) external {
        require(msg.sender == address(repaymentContract), "Only repayment contract");
        
        Borrower storage borrowerInfo = borrowers[borrower];
        
        if (fullyRepaid) {
            // Remove borrower if loan is fully repaid
            delete borrowers[borrower];
            removeBorrower(borrower);
        } else {
            // Update loan amounts
            borrowerInfo.activeLoanAmount -= principalPaid;
            borrowerInfo.paybackAmount -= (principalPaid + interestPaid);
        }
    }

    // Helper function to remove borrower from array
    function removeBorrower(address borrower) internal {
        for (uint i = 0; i < borrowerAddresses.length; i++) {
            if (borrowerAddresses[i] == borrower) {
                borrowerAddresses[i] = borrowerAddresses[borrowerAddresses.length - 1];
                borrowerAddresses.pop();
                break;
            }
        }
    }

    receive() external payable {}
}