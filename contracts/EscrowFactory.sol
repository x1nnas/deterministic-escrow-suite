// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SimpleEscrow.sol";

contract EscrowFactory is Ownable, Pausable, ReentrancyGuard {
    event EscrowCreated(address indexed depositor, address escrow);

    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
        feePercent = 1;
    }

    mapping(address => address[]) public escrows;

    address public feeRecipient;
    uint256 public immutable feePercent;

    function createEscrow(
        address depositor,
        address payee,
        uint256 deadline,
        bytes32 salt
    ) external whenNotPaused returns (address) {
        require(depositor != address(0), "Invalid depositor");
        require(payee != address(0), "Invalid payee");
        require(deadline > block.timestamp, "Invalid deadline");

        require(msg.sender == depositor, "Only depositor can create escrow");
        bytes memory bytecode = abi.encodePacked(
            type(SimpleEscrow).creationCode,
            abi.encode(address(this), depositor, payee, deadline, feePercent)
        );
        address escrow;
        assembly {
            escrow := create2(
                0,
                add(bytecode, 32), // where bytecode is in memory
                mload(bytecode), // length of bytecode
                salt
            )
        }
        require(escrow != address(0), "Deployment failed");

        escrows[depositor].push(escrow);
        emit EscrowCreated(depositor, escrow);
        return escrow;
    }

    function predictAddress(
        address depositor,
        address payee,
        uint256 deadline,
        bytes32 salt
    ) external view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(SimpleEscrow).creationCode,
            abi.encode(address(this), depositor, payee, deadline, feePercent)
        );

        bytes32 bytecodeHash = keccak256(bytecode);

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)
        );
        return (address(uint160(uint256(hash))));
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        (bool successFee, ) = payable(feeRecipient).call{
            value: balance
        }("");
        require(successFee, "Transfer failed");
    }

    function getEscrows(address depositor) external view returns (address[] memory) {
        return escrows[depositor];
    }

    receive() external payable {}
}
