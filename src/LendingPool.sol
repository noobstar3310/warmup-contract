// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract LendingPool {
    // Struct to store lender information
    struct Lender {
        uint256 depositAmount;
        uint256 depositTimestamp;
    }

    mapping(address => Lender) public lenders;
    

    address[] public lenderAddresses;

    uint256 public totalSupply;       
    uint256 public totalInterest;     

    event Deposit(address indexed lender, uint256 amount);
    event Withdraw(address indexed lender, uint256 amount, uint256 interest);

    function deposit() external payable {
        require(msg.value > 0, "Must deposit more than 0 ETH");

        if (lenders[msg.sender].depositAmount == 0) {
            lenderAddresses.push(msg.sender);
        }

        // Update lender information
        lenders[msg.sender].depositAmount += msg.value;
        lenders[msg.sender].depositTimestamp = block.timestamp;

        // Update total supply
        totalSupply += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        Lender storage lender = lenders[msg.sender];
        require(lender.depositAmount > 0, "No deposits found");

        // Calculate amounts
        uint256 supplyRatio = (lender.depositAmount * 1e18) / totalSupply;
        uint256 lenderInterest = (supplyRatio * totalInterest) / 1e18;
        uint256 totalWithdrawAmount = lender.depositAmount + lenderInterest;

        require(address(this).balance >= totalWithdrawAmount, "Insufficient contract balance");

        // Reset lender's deposit info before transfer
        uint256 amountToWithdraw = totalWithdrawAmount;
        totalSupply -= lender.depositAmount;
        delete lenders[msg.sender];

        // Remove lender from array
        removeLender(msg.sender);

        // Transfer funds
        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, lender.depositAmount, lenderInterest);
    }

    function addInterest() external payable {
        require(msg.value > 0, "Must add more than 0 interest");
        totalInterest += msg.value;
    }

    // New function to handle principal repayment
    function repayPrincipal() external payable {
        require(msg.value > 0, "Must repay more than 0");
        totalSupply += msg.value;
    }

    // Modified function to get total pool value
    function getTotalPoolValue() external view returns (uint256) {
        return totalSupply + totalInterest;
    }

    function getAllLenders() external view returns (address[] memory, uint256[] memory) {
        uint256[] memory deposits = new uint256[](lenderAddresses.length);
        
        for (uint i = 0; i < lenderAddresses.length; i++) {
            deposits[i] = lenders[lenderAddresses[i]].depositAmount;
        }
        
        return (lenderAddresses, deposits);
    }

    function getSupplyRatio(address lender) public view returns (uint256) {
        if (totalSupply == 0) return 0;
        return (lenders[lender].depositAmount * 1e18) / totalSupply;
    }

    function getLenderInterest(address lender) public view returns (uint256) {
        uint256 supplyRatio = getSupplyRatio(lender);
        return (supplyRatio * totalInterest) / 1e18;
    }

    function getWithdrawableAmount(address lender) external view returns (uint256) {
        return lenders[lender].depositAmount + getLenderInterest(lender);
    }

    function removeLender(address lenderAddress) internal {
        for (uint i = 0; i < lenderAddresses.length; i++) {
            if (lenderAddresses[i] == lenderAddress) {
                lenderAddresses[i] = lenderAddresses[lenderAddresses.length - 1];
                lenderAddresses.pop();
                break;
            }
        }
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}