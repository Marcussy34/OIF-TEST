<p align="center">
    <a href="https://www.openintents.xyz/" target="_blank" title="Open Intents Framework home">
      <img src="https://www.bootnode.dev/external/github-headers/oif.png" alt="open intents framework banner">
    </a>
</p>

<div align="center"><strong>Intents For Everyone, With Everyone</strong></div>
<div align="center">A modular, open-source framework for permissionless, scalable intent execution.</div>
<br />

# Open Intents Framework

[![License: MIT][license-badge]][license]

[license]: https://www.apache.org/licenses/LICENSE-2.0
[license-badge]: https://img.shields.io/badge/License-Apache-blue.svg

## Description

The Open Intents Framework is an open-source framework that provides a full stack of smart contracts, solvers and UI with modular abstractions for settlement to build and deploy intent protocols across EVM chains.

With out-of-the-box ERC-7683 support, the Open Intents Framework standardizes cross-chain transactions and unlocks intents on day 1 for builders in the whole Ethereum ecosystem (and beyond).

## Features

- **ERC-7683 Reference Implementation:** Standardizes cross-chain intent execution, making transactions more interoperable and predictable across EVM chains.
- **Open-Source Reference Solver:** application that provides customizable protocol-independent features—such as indexing, transaction submission, and rebalancing.
- **Composable Smart Contracts:** composable framework where developers can mix and match smart contracts, solvers, and settlement layers to fit their use case
- **Ready-to-Use UI:** A pre-built, customizable UI template that makes intents accessible to end users.
- **Credibly Neutral:** works across different intent-based protocols and settlement mechanisms

## Directory Structure

- `solidity/` - Contains the smart contract code written in Solidity.
- `typescript/solvers/` - Houses the TypeScript implementations of the solvers that execute the intents.

## Getting Started

### Prerequisites

- Node.js
- yarn
- Git

### Installation

```bash
git clone https://github.com/BootNodeDev/intents-framework.git
cd intents-framework
yarn
```

### Running the Solver

Run the following commands from the root directory (you need `docker` installed)

```bash
docker build -t solver .
```

Once it finish building the image

```bash
docker run -it -e [PRIVATE_KEY=SOME_PK_YOU_OWN | MNEMONIC=SOME_MNEMONIC_YOU_OWN] solver
```

The solver is run using `pm2` inside the docker container so `pm2` commands can still be used inside a container with the docker exec command:

```bash
# Monitoring CPU/Usage of each process
docker exec -it <container-id> pm2 monit
# Listing managed processes
docker exec -it <container-id> pm2 list
# Get more information about a process
docker exec -it <container-id> pm2 show
# 0sec downtime reload all applications
docker exec -it <container-id> pm2 reload all
```

### Versioning

For the versions available, see the tags on this repository.

### Releasing packages to NPM

We use [changesets](https://github.com/changesets/changesets) to release to NPM. You can use the `release` script in `package.json` to publish.

Currently the only workspace being released as an NPM package is the one in `solidity`, which contains the contracts and typechain artifacts.

### License

This project is licensed under the Apache 2.0 License - see the LICENSE.md file for details.

# Intent Chamber

A gamified cross-chain token transfer interface built on the Open Intents Framework (OIF) that connects to real blockchain testnets.

## Overview

Intent Chamber is a Next.js application that allows users to:

- Connect to Base Sepolia and Optimism Sepolia testnets
- Create cross-chain token transfer intents
- Submit intents to blockchain solvers
- Track the execution of intents through an intuitive interface

The application uses real blockchain connections rather than mock components, leveraging the Open Intents Framework to handle the creation, signing, and execution of intents.

## Technical Stack

- **Frontend**: Next.js with JavaScript
- **Styling**: Tailwind CSS
- **Blockchain Integration**:
  - OIF (Open Intents Framework)
  - RainbowKit for wallet connections
  - Wagmi/Viem for blockchain interactions
  - Hyperlane for cross-chain messaging
- **Testnets**:
  - Base Sepolia
  - Optimism Sepolia

## Getting Started

### Prerequisites

- Node.js (v16+)
- npm or yarn
- MetaMask or another compatible wallet
- Testnet ETH on Base Sepolia and Optimism Sepolia

### Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/intent-chamber.git
cd intent-chamber
```

2. Install dependencies:

```bash
npm install
```

3. Create a `.env.local` file:

```
NEXT_PUBLIC_WALLET_CONNECT_ID=your_wallet_connect_project_id
```

4. Start the development server:

```bash
npm run dev
```

5. Open [http://localhost:3000](http://localhost:3000) in your browser

## Using the Application

1. Connect your wallet (ensure it's configured for Base Sepolia and Optimism Sepolia)
2. Select source and target tokens for your cross-chain transfer
3. Enter the amount and recipient address
4. Create your intent and wait for solvers to analyze it
5. Select a solver to execute your intent
6. Confirm and sign the transaction
7. Monitor the execution status in real-time

## Setting Up a Solver

For intents to be executed, you need a solver running that can process intents from the testnets:

1. Follow the solver setup instructions in the [GUIDE.md](./GUIDE.md) file
2. Configure the solver to connect to Base Sepolia and Optimism Sepolia
3. Ensure the solver has sufficient funds to execute transactions

## Getting Testnet Tokens

- **Base Sepolia**: [Base Sepolia Faucet](https://www.basescan.org/faucet)
- **Optimism Sepolia**: [Optimism Sepolia Faucet](https://www.optimism.io/faucet)

## Project Structure

```
intent-chamber/
├── components/
│   └── intent/
│       └── IntentChamber.js   # Main component for creating/executing intents
├── lib/
│   ├── wallet-config.js       # Wallet connection configuration
│   └── oif-components.js      # OIF component wrappers
├── pages/
│   ├── index.js               # Main page
│   └── _app.js                # App component with providers
├── public/
│   └── images/                # Solver and UI images
└── styles/
    └── globals.css            # Global styles
```

## Resources

- [Open Intents Framework Documentation](https://bootnodedev.github.io/intents-framework-core/)
- [Base Sepolia Explorer](https://sepolia.basescan.org/)
- [Optimism Sepolia Explorer](https://sepolia-optimism.etherscan.io/)
- [Detailed Implementation Guide](./GUIDE.md)

## License

MIT
