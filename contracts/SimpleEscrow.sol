// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimpleEscrow is ReentrancyGuard {


    // immutable config
    address public immutable factory;
    address public immutable depositor;
    address public immutable payee;
    uint256 public immutable deadline;
    uint256 public immutable feePercent;

    // mutable state
    bool public funded;
    bool public released;
    uint256 public depositedAmount;

    // events
    event Funded(uint amount);
    event Released(address indexed payee, uint256 amountAfterFee); // 'indexed' allows filtering logs by payee

    constructor(
        address _factory,
        address _depositor,  
        address _payee, 
        uint256 _deadline, 
        uint256  _feePercent
        ) {
            factory = _factory;
            depositor = _depositor;
            payee = _payee;
            deadline = _deadline;
            feePercent = _feePercent;
        }
}
