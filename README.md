# Deterministic Escrow Suite

A Solidity-based escrow system built with deterministic contract deployment (`CREATE2`), signature-based release authorization, and deadline-based refund safety.

This repository showcases a complete smart contract workflow: contract architecture, security-focused escrow logic, and automated testing with Hardhat.

## Project Overview

`Deterministic Escrow Suite` allows users to create escrow contracts at predictable addresses through a factory contract.  
Each escrow instance is configured for a specific depositor, payee, and deadline, then handles funding, conditional release, and reclaim flows.

## Architecture

The suite is composed of two core contracts:

- `EscrowFactory`
  - Deploys `SimpleEscrow` contracts using `CREATE2`
  - Predicts escrow addresses before deployment
  - Receives protocol fee on successful release

- `SimpleEscrow`
  - Stores immutable escrow participants and terms
  - Accepts funding only from the configured depositor
  - Releases funds only when a valid depositor signature is provided
  - Supports reclaim after deadline if escrow is not released

## Escrow Flow (Step-by-Step)

1. **Create Escrow**  
   Depositor creates an escrow through `EscrowFactory` with `depositor`, `payee`, `deadline`, and `salt`.

2. **Fund Escrow**  
   Only the designated depositor can fund the escrow.

3. **Release Path**  
   Depositor signs a release message off-chain.  
   `release()` verifies the signature on-chain, pays the payee, and sends the fee to the factory.

4. **Reclaim Path**  
   If the deadline passes without release, `reclaim()` returns funds to the depositor.

## Tech Stack

- Solidity `^0.8.20`
- Hardhat
- Ethers.js (v6)
- Chai + Mocha
- OpenZeppelin (`ECDSA`, `MessageHashUtils`, `ReentrancyGuard`)

## Run Locally

```bash
git clone https://github.com/x1nnas/deterministic-escrow-suite.git
cd deterministic-escrow-suite
npm install
```

Compile contracts:

```bash
npx hardhat compile
```

## Run Tests

Run full test suite:

```bash
npx hardhat test
```

Run escrow factory tests only:

```bash
npx hardhat test test/EscrowFactory.test.js
```
