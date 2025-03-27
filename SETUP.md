# Open Intents Framework Setup Guide

This guide provides comprehensive instructions for setting up and running the Open Intents Framework, including the solver component for intent execution and the UI for user interaction.

## Overview

The Open Intents Framework is an open-source framework that provides a full stack of smart contracts, solvers, and UI components with modular abstractions for building and deploying intent protocols across EVM chains.

With ERC-7683 support, this framework standardizes cross-chain transactions and enables intents across the Ethereum ecosystem.

## System Requirements

- Node.js (v16+)
- Yarn
- Docker
- Git
- A private key with funds on test networks

## 1. Setting Up the Solver

The solver is the component that fulfills user intents by executing the most efficient path to achieve the desired outcome.

### 1.1 Building the Solver Docker Image

1. Clone the repository:

   ```bash
   git clone https://github.com/BootNodeDev/intents-framework.git
   cd intents-framework


   OPEN POWERSHELL
   npm install --global yarn
   yarn --version

   IF YARN IS NOT v4.0+
   open powershell
   corepack enable
   corepack prepare yarn@4.5.1 --activate
   yarn --version
   yarn install
   ```

2. Create a Dockerfile in the root directory with the following content:

   ```dockerfile
   FROM node:20-alpine

   WORKDIR /workspace
   COPY . ./
   RUN corepack enable
   RUN yarn install

   WORKDIR /workspace/typescript/solver

   # Install required packages
   RUN yarn add zod @hyperlane-xyz/registry @hyperlane-xyz/sdk

   # Install necessary tools
   RUN npm install -g tsx

   # Add debugging output
   RUN echo '#!/bin/sh\ncd /workspace/typescript/solver\necho "Starting solver..."\nenv | grep -i key\ntsx --no-warnings index.ts' > /start.sh
   RUN chmod +x /start.sh

   CMD ["/start.sh"]
   ```

3. Build the Docker image:
   ```bash
   docker build -t solver .
   ```

### 1.2 Running the Solver

1. Run the solver with your private key:

   ```bash
   docker run -it -e PRIVATE_KEY=your_private_key_here solver
   ```

   Replace `your_private_key_here` with your actual private key (without the "0x" prefix).

2. Verify the solver is running by checking Docker:
   ```bash
   docker ps
   ```

## 2. Setting Up the UI

The UI component allows users to create intents that the solver will fulfill.

### 2.1 WalletConnect Project ID

1. Create a WalletConnect Project ID:
   - Go to [WalletConnect Cloud](https://cloud.walletconnect.com)
   - Sign up or log in
   - Create a new project
   - Copy the Project ID

### 2.2 Environment Configuration

1. Create a `.env.local` file in the `typescript/ui` directory:

   ```bash
   cd typescript/ui
   ```

   Create a file named `.env.local` with the following content:

   ```
   NEXT_PUBLIC_WALLET_CONNECT_ID=your_wallet_connect_project_id
   ```

   Replace `your_wallet_connect_project_id` with the ID you obtained from WalletConnect.

### 2.3 Building and Running the UI

1. Install dependencies:

   ```bash
   cd typescript/ui
   yarn
   ```

2. Build the UI:

   ```bash
   yarn build
   ```

3. Start the development server:

   ```bash
   yarn dev
   ```

4. Access the UI in your browser at `http://localhost:3000`

## 3. Using the System

### 3.1 Creating an Intent

1. Open the UI in your browser
2. Connect your wallet
3. Select the source chain (e.g., Optimism Sepolia)
4. Select the destination chain (e.g., Base Sepolia)
5. Enter the amount and token to bridge
6. Click "Send to [Destination Chain]"
7. Approve the transaction in your wallet

### 3.2 How the System Works

When you create an intent:

1. The UI creates and signs an ERC-7683 compatible intent
2. This intent is broadcast to the network
3. The solver (running in your Docker container) detects the intent
4. The solver validates the intent against its rules
5. If the intent is valid and profitable, the solver executes it
6. The tokens are bridged from the source chain to the destination chain

The solver optimizes for:

- Gas costs
- Execution time
- Output amount

## 4. Troubleshooting

### 4.1 Solver Issues

If the solver container stops immediately:

- Ensure your private key is valid
- Check that you have funds on the relevant networks
- Verify network connectivity

View solver logs:

```bash
docker logs [container_name]
```

### 4.2 UI Issues

If the UI fails to start:

- Ensure you have the correct WalletConnect Project ID
- Check that all dependencies are installed
- Verify the terminal output for errors

### 4.3 Intent Execution Issues

If an intent is stuck "waiting for solver":

- Ensure the solver is running
- Check the solver logs for errors
- Verify that your solver has funds to execute transactions
- Confirm that the networks in the intent match the ones configured in the solver

## 5. Customization

### 5.1 Supporting Additional Chains

1. Edit `typescript/solver/config/chainMetadata.ts` to add custom chain configurations
2. Update the UI chain configurations in `typescript/ui/src/consts/chains.ts`

### 5.2 Modifying UI Appearance

1. Edit branding assets in `typescript/ui/src/images/logos/`
2. Modify color scheme in `typescript/ui/tailwind.config.js`
3. Update app name and description in `typescript/ui/src/consts/app.ts`

## 6. Advanced Configuration

### 6.1 Solver Configuration

The solver can be customized by editing:

- `typescript/solver/solvers.json` - Enable/disable specific solvers
- `typescript/solver/config/chainMetadata.ts` - Configure chain-specific settings
- Individual solver configurations in their respective directories

### 6.2 Production Deployment

For production deployment of the UI:

1. Build the UI: `yarn build`
2. Deploy to Vercel: `vercel` (after installing Vercel CLI)
3. Set environment variables in the Vercel dashboard

For production deployment of the solver:

1. Use a reliable host for your Docker container
2. Consider using a secret management solution for your private key
3. Set up monitoring and alerts for solver performance
