// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol

contract SimpleEscrow is ReentrancyGuard {

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
    uint256 public depositAmount;

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
        
        bytes32 ethSignedHash = hashRelease(amount).toEthSignedMessageHash();
        
        require(sig.length == 65, "Invalid signature length");

    }
}