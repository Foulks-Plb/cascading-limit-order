# Automated Cascading Limit Order System on Uniswap V3 🦄🦄🦄

## Overview

This project proposes an trading strategy for Uniswap V3, enabling users to place cascading limit orders that are executed by a third-party service (filler) when the specified price is reached. The system ensures atomic transactions, where the execution of an initial limit order triggers the creation of subsequent limit orders using the tokens received, following a predefined strategy. This process can repeat in both upward and downward price movements, creating an automated trading loop that maximizes trading opportunities and minimizes manual intervention.

## Introduction

Uniswap V3 has revolutionized decentralized finance (DeFi) by providing liquidity providers with the flexibility to concentrate their capital within specific price ranges. However, traditional limit orders are not natively supported. This project introduces a solution for creating cascading limit orders on Uniswap V3, enabling sophisticated trading strategies to be executed seamlessly.

## Problem Statement

Current DeFi platforms lack native support for automated limit order executions that can create subsequent limit orders based on the outcomes of the initial trades. Traders need a robust solution that allows for:

- Placing limit orders that execute automatically when target prices are reached.
- Creating new limit orders using the proceeds of the executed orders.
- Ensuring atomic transactions to prevent loss or partial execution.
- Repeating the process in both upward and downward market trends.

## Proposed Solution

### System Architecture

The proposed solution consists of three main components:

1. **Smart Contracts**:
   - Deployed on the Ethereum blockchain, these contracts handle the creation and execution of limit orders.

2. **Off-Chain Service**:
   - A third-party service monitors the market prices and triggers the execution of limit orders when conditions are met.

3. **User Interface**:
   - A front-end application for traders to set their strategies and manage their orders.

### Workflow

1. **Initial Limit Order Placement**:
   - The user specifies a token, the amount, and the target price for the initial limit order.
   - The user also specifies the second target price for the second limit order.
   - The smart contract locks the user’s token and registers the strategy details.

2. **Market Monitoring and Order Execution**:
   - The off-chain service continuously monitors market prices.
   - When the market price reaches the target, the service triggers the execution of the limit order through the smart contract.
   - The smart contract swaps the tokens at the specified price (initial limit order).
   - Atomically creates a new limit order using the received tokens. The second limit order is set with a higher (or lower) target price based on the predefined strategy.

3. **Repetition and Looping**:
   - The process repeats, with each executed limit order triggering a subsequent one.
   - The strategy can be customized to either continue indefinitely or stop after a certain number of iterations or target profit/loss thresholds are reached.

### Example

1. Initial Limit Order: Sell 10 USDC at 1.05 DAI/USDC
    - Execution: Receive 10.50 DAI
        - Create New Order: Buy USDC with 10.50 DAI at 0.95 DAI/USDC
            - Execution: Receive ~11.05 USDC
                - Create New Order: Sell 11.05 USDC at 1.05 DAI/USDC
                    - And so on...

## Atomic Transactions

Atomic transactions are achieved using Solidity smart contracts ensuring that the creation of the subsequent order only occurs if the initial order is executed successfully. This prevents any partial executions or loss of funds during the process.
