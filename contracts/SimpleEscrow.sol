// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SimpleEscrow is ReentrancyGuard {

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // immutable config
    address public immutable factory;
    address public immutable depositor;
    address public immutable payee;
    uint256 public immutable deadline;
    uint256 public immutable feePercent;

    // mutable state
    bool public funded;
    bool public released;
    bool public reclaimed;
    uint256 public depositAmount;

    // events
    event Funded(uint amount);
    event Released(address indexed payee, uint256 amountAfterFee); // 'indexed' allows filtering logs by payee
    event Reclaimed(address indexed depositor, uint256 amount);

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

    function fund() external payable {
        require(msg.sender == depositor, "Only Depositor!");
        require(!funded, "Already funded");
        require(msg.value > 0, "Contribution amount invalid");

        funded = true;
        depositAmount = msg.value;

        emit Funded(msg.value);
    }

    function hashRelease(uint256 amount) private view returns (bytes32) {

        return keccak256(abi.encodePacked("RELEASE", address(this), amount));
    }

    function verify(uint256 amount, bytes memory sig) internal view returns (address) {
        
        bytes32 messageHash = hashRelease(amount);
        
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        
        require(sig.length == 65, "Invalid signature length");

        address signer = ethSignedHash.recover(sig);

        return signer; 
    }

    function release(uint256 amount, bytes memory sig) external nonReentrant {

        require(funded, "Escrow not funded");
        require(!released, "Already released");
        require(verify(amount, sig) == depositor, "Invalid signature");
        require(amount == depositAmount, "Invalid amount");
        uint256 fee = amount * feePercent / 100;
        uint256 amountAfterFee = amount - fee;

        released = true;

        (bool successPayee, ) = payable(payee).call{value: amountAfterFee}("");
        require(successPayee, "Transfer failed");

        (bool successFee, ) = payable(factory).call{value: fee}("");
        require(successFee, "Transfer failed");

        emit Released(payee, amountAfterFee);
    }

    function reclaim() external nonReentrant {

        require(block.timestamp > deadline, "Deadline not reached");
        require(!released, "Already released");
        require(!reclaimed, "Already reclaimed");
        require(funded, "Not funded"); 

        reclaimed = true;

        uint256 balance = address(this).balance;

        (bool successReclaim, ) = payable(depositor).call{value: balance}("");
        require (successReclaim, "Refund failed");

        emit Reclaimed(depositor, balance);
    }
}