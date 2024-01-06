# ZapWarrant Protocol Overview

## Introduction
ZapWarrant is an innovative decentralized protocol designed for peer-to-peer option trading on the Ethereum blockchain, focusing on ERC20 tokens. It introduces a flexible, user-driven approach to options trading, expanding the scope of financial derivatives in the crypto space.

## Core Components
- **WarrantFactory.sol:** Automates the creation of new option contracts. It's the starting point for users to generate unique option instances based on their specifications.
- **WarrantPair.sol:** Manages option pairings, allowing traders to combine different option types and underlying assets. This contract is crucial for creating diverse trading possibilities and strategies.
- **Settlement.sol:** Handles the settlement of options at maturity. It is designed to offer both cash and asset-based settlements, depending on the terms of the option and the preference of the parties involved.
- **MockChainlinkAggregator.sol:** A test contract that simulates price feeds, critical for validating the protocol's responsiveness to market conditions.
- **Interfaces (IWarrant.sol & IWarrantPair.sol):** These define the essential functions for Warrants and Warrant Pairs, ensuring standardization across the protocol.

## Functionality
- **Customizable Options:** Users can list options with any ERC20 token, choose their strike prices, and set maturity dates.
- **European-style Options:** The protocol supports European-style options, offering a specific exercise style at maturity.
- **Diverse Settlement Options:** Traders can opt for different settlement methods, providing flexibility in how options are executed.

## Impact
ZapWarrant democratizes options trading by removing traditional barriers such as fixed maturities and strikes, thereby making a wider range of underlying assets accessible. It stands out for its emphasis on flexibility and user empowerment in the crypto derivatives market.
