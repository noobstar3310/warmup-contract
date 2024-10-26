// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {InterestDistribution} from "./InterestDistribution.sol";

contract LendingPool{
    using PriceConverter for uint256;

    mapping(address => uint256) public userDeposits;
    uint256 public totalDeposits;
    AggregatorV3Interface private priceFeed;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // Function to deposit ETH into the lending pool
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        userDeposits[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    // Function to withdraw ETH from the lending pool
    function withdraw(uint256 amount) external{
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(userDeposits[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient liquidity in the pool");

        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function getLatestEthUsdPrice() public view returns (uint256) {
        return PriceConverter.getPrice(priceFeed);
    }

    function getTotalDepositsInUsd() public view returns (uint256) {
        return totalDeposits.getConversionRate(priceFeed);
    }

    // Function to check the user's deposited balance
    function getBalance() external view returns (uint256) {
        return userDeposits[msg.sender];
    }

    // Function to check the total deposits in the pool
    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

    // Function to check the contract's ETH balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
