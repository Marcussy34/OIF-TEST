# Intent Chamber Implementation Guide

This guide provides step-by-step instructions for implementing the Intent Chamber with real blockchain functionality using the Open Intents Framework (OIF).

## Project Overview

The Intent Chamber is a Next.js application that allows users to:

- Connect their wallet to Base Sepolia and Optimism Sepolia testnets
- Create cross-chain token transfer intents
- Submit these intents to the blockchain where they can be discovered by solvers
- Monitor the execution of their intents

This implementation uses real blockchain connections instead of mocks, with local Docker-based solvers processing the intents.

## Architecture Overview

The Intent Chamber uses a hybrid architecture:

1. **On-chain**: Intents are signed by users and published to the blockchain
2. **Off-chain**: Solvers run locally in Docker containers, monitoring the blockchain for new intents
3. **On-chain**: When a solver processes an intent, it submits the fulfillment transaction back to the blockchain

This design offers the efficiency of off-chain computation with the security and transparency of on-chain verification.

## Project Structure

```
intent-chamber/
├── components/
│   ├── intent/
│   │   ├── IntentChamber.js
│   │   ├── SolverCard.js         # New component for solver selection
│   │   ├── IntentForm.js         # New component for intent creation
│   │   ├── IntentStatus.js       # New component for tracking execution
│   │   └── IntentReview.js       # New component for reviewing intent details
│   ├── ui/
│   │   ├── Button.js             # Reusable UI components
│   │   ├── Card.js
│   │   └── Loader.js
│   └── layout/
│       ├── Header.js             # Site header with wallet connection
│       └── Footer.js             # Site footer with links
├── lib/
│   ├── wallet-config.js
│   ├── oif-components.js
│   ├── intent-utils.js           # New utility functions for intent operations
│   ├── chain-config.js           # New testnet configuration details
│   └── solver-config.js          # New solver configuration
├── pages/
│   ├── index.js
│   ├── intents/[id].js           # New page for individual intent tracking
│   └── _app.js
├── public/
│   └── images/
│       └── ... (solver images)
├── styles/
│   └── globals.css
├── hooks/                       # New directory for custom React hooks
│   ├── useIntent.js             # Hook for intent state management
│   ├── useSolver.js             # Hook for solver interactions
│   └── useChainData.js          # Hook for blockchain data
└── ... (configuration files)
```

## Setup Instructions

### 1. Directory Setup

Create the necessary directories:

```bash
mkdir -p components/intent lib public/images
```

### 2. Dependencies Installation

Install the required packages:

```bash
npm install @bootnodedev/intents-framework-core @hyperlane-xyz/sdk @hyperlane-xyz/widgets @rainbow-me/rainbowkit viem wagmi @tanstack/react-query zod framer-motion react-toastify
```

### 3. Wallet Configuration

Create `lib/wallet-config.js` to configure the blockchain connections:

```javascript
import { createConfig, configureChains } from "wagmi";
import { publicProvider } from "wagmi/providers/public";
import { baseSepolia, optimismSepolia } from "wagmi/chains";
import { getDefaultWallets } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";

// Configure testnet chains
const { chains, publicClient } = configureChains(
  [baseSepolia, optimismSepolia],
  [publicProvider()]
);

// Real wallet connections
const { connectors } = getDefaultWallets({
  appName: "Intent Chamber",
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_ID,
  chains,
});

export const wagmiConfig = createConfig({
  autoConnect: true,
  connectors,
  publicClient,
});
```

### 4. OIF Components Setup

Create `lib/oif-components.js` to import and expose the OIF components:

```javascript
import dynamic from "next/dynamic";

// Import actual blockchain components, not mocks
export const TransferTokenForm = dynamic(
  () =>
    import("@bootnodedev/intents-framework-core/ui").then(
      (mod) => mod.TransferTokenForm
    ),
  { ssr: false }
);

export const WalletConnector = dynamic(
  () =>
    import("@bootnodedev/intents-framework-core/ui").then(
      (mod) => mod.ConnectWalletButton
    ),
  { ssr: false }
);

// Real intent creation functions
export const IntentBuilder = dynamic(
  () =>
    import("@bootnodedev/intents-framework-core").then(
      (mod) => mod.IntentBuilder
    ),
  { ssr: false }
);

export const SolverClient = dynamic(
  () =>
    import("@bootnodedev/intents-framework-core").then(
      (mod) => mod.SolverClient
    ),
  { ssr: false }
);
```

### 5. Intent Chamber Component

Create `components/intent/IntentChamber.js`:

```javascript
// components/intent/IntentChamber.js
import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { toast } from "react-toastify";
import { useAccount, useNetwork } from "wagmi";
import {
  TransferTokenForm,
  IntentBuilder,
  SolverClient,
} from "../../lib/oif-components";
import { SolverCard } from "./SolverCard";
import { IntentReview } from "./IntentReview";
import { IntentStatus } from "./IntentStatus";

// Solver visualization (for UX purposes)
const SOLVER_NPCS = [
  {
    id: "swift",
    name: "Swift Solver",
    description: "Fast but more expensive",
    speedMultiplier: 0.7,
    costMultiplier: 1.2,
    image: "/images/swift-solver.png",
  },
  {
    id: "balanced",
    name: "Balanced Solver",
    description: "Average speed and cost",
    speedMultiplier: 1,
    costMultiplier: 1,
    image: "/images/balanced-solver.png",
  },
  {
    id: "thrifty",
    name: "Thrifty Solver",
    description: "Slower but cheaper",
    speedMultiplier: 1.5,
    costMultiplier: 0.8,
    image: "/images/thrifty-solver.png",
  },
];

export function IntentChamber() {
  const [stage, setStage] = useState("selection");
  const [intent, setIntent] = useState(null);
  const [selectedSolver, setSelectedSolver] = useState(null);
  const [signedIntent, setSignedIntent] = useState(null);
  const [executionStatus, setExecutionStatus] = useState("pending");
  const { address, isConnected } = useAccount();
  const { chain } = useNetwork();

  // Create and build a real blockchain intent
  const handleIntentCreated = async (intentData) => {
    try {
      setIntent(intentData);
      setStage("chamber");

      // Use actual OIF IntentBuilder to create a real intent
      const intentBuilder = new IntentBuilder({
        sourceChain: intentData.sourceChain,
        targetChain: intentData.targetChain,
        tokenAddress: intentData.tokenAddress,
        amount: intentData.amount,
        recipient: address || intentData.recipient,
      });

      const builtIntent = await intentBuilder.build();
      setIntent({
        ...intentData,
        builtIntent,
      });

      toast.info("Solvers are analyzing your intent...");
    } catch (error) {
      toast.error(`Error creating intent: ${error.message}`);
      setStage("selection");
    }
  };

  // Select solver visualization (the OIF will actually pick the optimal solver)
  const handleSelectSolver = (solver) => {
    setSelectedSolver(solver);
    setStage("review");
  };

  // Submit the real intent to the blockchain
  const handleExecuteIntent = async () => {
    try {
      setStage("execution");

      if (!intent.builtIntent) {
        throw new Error("Intent not properly built");
      }

      // Sign with real wallet and get a blockchain-valid signature
      const signedIntent = await intent.builtIntent.sign(window.ethereum);
      setSignedIntent(signedIntent);

      // Create real solver client to interact with blockchain
      const solverClient = new SolverClient();

      // Submit the signed intent to the network
      await solverClient.submitIntent(signedIntent);

      toast.success("Intent submitted to the blockchain!");
    } catch (error) {
      toast.error(`Error executing intent: ${error.message}`);
      setStage("review");
    }
  };

  // Monitor intent status on the blockchain
  useEffect(() => {
    if (signedIntent && stage === "execution") {
      const interval = setInterval(async () => {
        try {
          const solverClient = new SolverClient();
          const status = await solverClient.getIntentStatus(signedIntent.id);

          setExecutionStatus(status);

          if (status === "fulfilled") {
            toast.success("Intent fulfilled successfully!");
            clearInterval(interval);
          } else if (status === "failed") {
            toast.error("Intent fulfillment failed.");
            clearInterval(interval);
          }
        } catch (error) {
          console.error("Error checking intent status:", error);
        }
      }, 5000);

      return () => clearInterval(interval);
    }
  }, [signedIntent, stage]);

  return (
    <div className="w-full max-w-4xl mx-auto">
      {stage === "selection" && (
        <div className="bg-slate-800 p-6 rounded-lg shadow-lg">
          <h2 className="text-2xl font-bold mb-4">Create Intent</h2>
          <p className="mb-6">Select tokens to bridge between testnets</p>
          <TransferTokenForm onIntentCreated={handleIntentCreated} />
        </div>
      )}

      {stage === "chamber" && (
        <div className="bg-slate-800 p-6 rounded-lg shadow-lg">
          <h2 className="text-2xl font-bold mb-4">Select Solver</h2>
          <p className="mb-6">Choose a solver to fulfill your intent</p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {SOLVER_NPCS.map((solver) => (
              <SolverCard
                key={solver.id}
                solver={solver}
                onClick={() => handleSelectSolver(solver)}
              />
            ))}
          </div>
        </div>
      )}

      {stage === "review" && intent && selectedSolver && (
        <IntentReview
          intent={intent}
          solver={selectedSolver}
          onExecute={handleExecuteIntent}
          isConnected={isConnected}
        />
      )}

      {stage === "execution" && (
        <IntentStatus
          intent={intent}
          solver={selectedSolver}
          status={executionStatus}
          signedIntent={signedIntent}
        />
      )}
    </div>
  );
}
```

### 5.1 SolverCard Component

Create `components/intent/SolverCard.js`:

```javascript
import React from "react";
import Image from "next/image";

export function SolverCard({ solver, onClick }) {
  return (
    <div
      className="bg-slate-700 p-4 rounded-lg shadow cursor-pointer hover:bg-slate-600 transition-colors"
      onClick={onClick}
    >
      <div className="flex justify-center mb-3">
        <div className="w-20 h-20 relative rounded-full overflow-hidden">
          <Image
            src={solver.image}
            alt={solver.name}
            fill
            className="object-cover"
          />
        </div>
      </div>

      <h3 className="text-xl font-semibold text-center mb-2">{solver.name}</h3>
      <p className="text-center text-gray-300 mb-3">{solver.description}</p>

      <div className="text-sm text-gray-400">
        <div className="flex justify-between mb-1">
          <span>Speed:</span>
          <span>
            {solver.speedMultiplier < 1
              ? "Fast"
              : solver.speedMultiplier > 1
                ? "Slow"
                : "Average"}
          </span>
        </div>
        <div className="flex justify-between">
          <span>Cost:</span>
          <span>
            {solver.costMultiplier > 1
              ? "High"
              : solver.costMultiplier < 1
                ? "Low"
                : "Average"}
          </span>
        </div>
      </div>
    </div>
  );
}
```

### 5.2 IntentReview Component

Create `components/intent/IntentReview.js`:

```javascript
import React from "react";

export function IntentReview({ intent, solver, onExecute, isConnected }) {
  // Format the amount for display
  const amount = parseFloat(intent.amount).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 6,
  });

  // Calculate estimated cost based on solver
  const estimatedCost = (solver.costMultiplier * 0.001).toFixed(6);

  // Calculate estimated time in minutes
  const estimatedTime = Math.ceil(solver.speedMultiplier * 2);

  return (
    <div className="bg-slate-800 p-6 rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-4">Review Intent</h2>

      <div className="mb-6">
        <div className="flex items-center mb-4">
          <div className="w-12 h-12 bg-slate-700 rounded-full flex items-center justify-center mr-3">
            <span className="text-xl">🔄</span>
          </div>
          <div>
            <h3 className="font-semibold">Selected Solver</h3>
            <p>{solver.name}</p>
          </div>
        </div>

        <div className="bg-slate-700 p-4 rounded-lg mb-4">
          <h3 className="font-semibold mb-2">Intent Details</h3>
          <div className="grid grid-cols-2 gap-2 text-sm">
            <div>Transfer Amount:</div>
            <div className="text-right">
              {amount} {intent.sourceToken}
            </div>

            <div>From Chain:</div>
            <div className="text-right">{intent.sourceChain}</div>

            <div>To Chain:</div>
            <div className="text-right">{intent.targetChain}</div>

            <div>Destination Token:</div>
            <div className="text-right">{intent.destToken}</div>

            <div>Estimated Time:</div>
            <div className="text-right">{estimatedTime} minutes</div>

            <div>Estimated Gas:</div>
            <div className="text-right">{estimatedCost} ETH</div>
          </div>
        </div>
      </div>

      <button
        onClick={onExecute}
        disabled={!isConnected}
        className={`w-full py-3 rounded-lg font-semibold ${
          isConnected
            ? "bg-blue-600 hover:bg-blue-700"
            : "bg-gray-600 cursor-not-allowed"
        }`}
      >
        {isConnected ? "Execute Intent" : "Connect Wallet to Execute"}
      </button>

      {!isConnected && (
        <p className="text-red-400 text-center mt-3 text-sm">
          Please connect your wallet to execute this intent
        </p>
      )}
    </div>
  );
}
```

### 5.3 IntentStatus Component

Create `components/intent/IntentStatus.js`:

```javascript
import React from "react";
import { motion } from "framer-motion";

export function IntentStatus({ intent, solver, status, signedIntent }) {
  // Status display configurations
  const statusConfigs = {
    pending: {
      title: "Intent Submitted",
      description: "Your intent is being processed by solvers...",
      icon: "⏳",
      color: "text-yellow-400",
    },
    processing: {
      title: "Intent Processing",
      description: `${solver.name} is fulfilling your intent...`,
      icon: "⚙️",
      color: "text-blue-400",
    },
    fulfilled: {
      title: "Intent Fulfilled",
      description: "Your cross-chain transfer was successful!",
      icon: "✅",
      color: "text-green-400",
    },
    failed: {
      title: "Intent Failed",
      description: "There was an error fulfilling your intent.",
      icon: "❌",
      color: "text-red-400",
    },
  };

  const currentConfig = statusConfigs[status] || statusConfigs.pending;

  return (
    <div className="bg-slate-800 p-6 rounded-lg shadow-lg text-center">
      <h2 className="text-2xl font-bold mb-2">{currentConfig.title}</h2>
      <p className={`${currentConfig.color} text-lg mb-6`}>{status}</p>

      <div className="flex justify-center mb-6">
        {status !== "fulfilled" && status !== "failed" ? (
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ repeat: Infinity, duration: 3, ease: "linear" }}
            className="w-20 h-20 bg-slate-700 rounded-full flex items-center justify-center text-3xl"
          >
            {currentConfig.icon}
          </motion.div>
        ) : (
          <div className="w-20 h-20 bg-slate-700 rounded-full flex items-center justify-center text-3xl">
            {currentConfig.icon}
          </div>
        )}
      </div>

      <p className="mb-6">{currentConfig.description}</p>

      {signedIntent && (
        <div className="bg-slate-700 p-4 rounded-lg mb-4 text-left">
          <h3 className="font-semibold mb-2">Intent Details</h3>
          <div className="grid grid-cols-1 gap-2 text-sm">
            <div className="flex justify-between">
              <span>Intent ID:</span>
              <span className="font-mono text-xs overflow-hidden overflow-ellipsis">
                {signedIntent.id.substring(0, 10)}...
              </span>
            </div>

            <div className="flex justify-between">
              <span>From Chain:</span>
              <span>{intent.sourceChain}</span>
            </div>

            <div className="flex justify-between">
              <span>To Chain:</span>
              <span>{intent.targetChain}</span>
            </div>

            {status === "fulfilled" && (
              <div className="mt-2 pt-2 border-t border-slate-600">
                <a
                  href={`https://sepolia.basescan.org/tx/${signedIntent.txHash}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-blue-400 hover:underline"
                >
                  View Transaction →
                </a>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
```

### 5.4 Chain Configuration Utility

Create `lib/chain-config.js`:

```javascript
// Chain configuration for testnet interactions
export const CHAIN_CONFIG = {
  // Base Sepolia testnet configuration
  "base-sepolia": {
    id: 84532,
    name: "Base Sepolia",
    rpcUrl: "https://sepolia.base.org",
    blockExplorer: "https://sepolia.basescan.org",
    currency: "ETH",
    // Test tokens available on Base Sepolia
    tokens: [
      {
        symbol: "USDC",
        name: "USD Coin",
        address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
        decimals: 6,
      },
      {
        symbol: "WETH",
        name: "Wrapped ETH",
        address: "0x4200000000000000000000000000000000000006",
        decimals: 18,
      },
    ],
  },

  // Optimism Sepolia testnet configuration
  "optimism-sepolia": {
    id: 11155420,
    name: "Optimism Sepolia",
    rpcUrl: "https://sepolia.optimism.io",
    blockExplorer: "https://sepolia-optimism.etherscan.io",
    currency: "ETH",
    // Test tokens available on Optimism Sepolia
    tokens: [
      {
        symbol: "USDC",
        name: "USD Coin",
        address: "0x5fd84259d66Cd46123540766Be93DFE6D43130D7",
        decimals: 6,
      },
      {
        symbol: "WETH",
        name: "Wrapped ETH",
        address: "0x4200000000000000000000000000000000000006",
        decimals: 18,
      },
    ],
  },
};

// Helper function to get chain details by ID or name
export function getChainDetails(chainIdOrName) {
  if (typeof chainIdOrName === "number") {
    return Object.values(CHAIN_CONFIG).find(
      (chain) => chain.id === chainIdOrName
    );
  }

  return CHAIN_CONFIG[chainIdOrName];
}

// Get token details for a specific chain
export function getTokensForChain(chainIdOrName) {
  const chain = getChainDetails(chainIdOrName);
  return chain ? chain.tokens : [];
}
```

### 5.5 Custom Hook for Intent Management

Create `hooks/useIntent.js`:

```javascript
import { useState, useCallback } from "react";
import { IntentBuilder, SolverClient } from "../lib/oif-components";
import { getChainDetails } from "../lib/chain-config";

export function useIntent() {
  const [intent, setIntent] = useState(null);
  const [status, setStatus] = useState("idle");
  const [error, setError] = useState(null);

  // Create a new intent
  const createIntent = useCallback(async (intentData, walletProvider) => {
    try {
      setStatus("creating");
      setError(null);

      // Get chain details for validation
      const sourceChain = getChainDetails(intentData.sourceChain);
      const targetChain = getChainDetails(intentData.targetChain);

      if (!sourceChain || !targetChain) {
        throw new Error("Invalid chains specified");
      }

      // Build the intent using the OIF
      const intentBuilder = new IntentBuilder({
        sourceChain: intentData.sourceChain,
        targetChain: intentData.targetChain,
        tokenAddress: intentData.tokenAddress,
        amount: intentData.amount,
        recipient: intentData.recipient,
      });

      const builtIntent = await intentBuilder.build();

      // Sign the intent with the user's wallet
      const signedIntent = await builtIntent.sign(walletProvider);

      setIntent({
        ...intentData,
        builtIntent,
        signedIntent,
        id: signedIntent.id,
        createdAt: new Date().toISOString(),
      });

      setStatus("created");
      return signedIntent;
    } catch (err) {
      setStatus("error");
      setError(err.message);
      throw err;
    }
  }, []);

  // Submit the intent to the blockchain
  const submitIntent = useCallback(async (signedIntent) => {
    try {
      setStatus("submitting");

      const solverClient = new SolverClient();
      await solverClient.submitIntent(signedIntent);

      setStatus("submitted");
      return true;
    } catch (err) {
      setStatus("error");
      setError(err.message);
      throw err;
    }
  }, []);

  // Check intent status
  const checkStatus = useCallback(async (intentId) => {
    try {
      const solverClient = new SolverClient();
      const currentStatus = await solverClient.getIntentStatus(intentId);

      setStatus(currentStatus);
      return currentStatus;
    } catch (err) {
      setError(err.message);
      return "error";
    }
  }, []);

  return {
    intent,
    status,
    error,
    createIntent,
    submitIntent,
    checkStatus,
  };
}
```

### 10. Styles Configuration

Create or update `styles/globals.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --primary-color: #3b82f6;
  --background-color: #1e293b;
  --card-background: #334155;
  --text-color: #f8fafc;
}

body {
  background-color: var(--background-color);
  color: var(--text-color);
}

/* Custom animation for solving intents */
@keyframes pulse {
  0% {
    opacity: 0.6;
    transform: scale(0.98);
  }
  50% {
    opacity: 1;
    transform: scale(1.01);
  }
  100% {
    opacity: 0.6;
    transform: scale(0.98);
  }
}

.animate-pulse-slow {
  animation: pulse 2s infinite;
}
```

### 11. Configuring the Solver

When setting up your local solver in Docker, you will need to create a configuration file. Here's an example `solver-config.json`:

```json
{
  "rpcProviders": {
    "base-sepolia": "https://sepolia.base.org",
    "optimism-sepolia": "https://sepolia.optimism.io"
  },
  "walletPrivateKey": "YOUR_PRIVATE_KEY_HERE",
  "intentRoutes": [
    {
      "sourceChain": "base-sepolia",
      "targetChain": "optimism-sepolia",
      "supportedTokens": ["0x036CbD53842c5426634e7929541eC2318f3dCF7e"]
    },
    {
      "sourceChain": "optimism-sepolia",
      "targetChain": "base-sepolia",
      "supportedTokens": ["0x5fd84259d66Cd46123540766Be93DFE6D43130D7"]
    }
  ],
  "gasLimitMultiplier": 1.2,
  "maxGasPrice": "100000000000", // 100 Gwei
  "intentListeningInterval": 10000, // Poll for new intents every 10 seconds
  "logLevel": "info"
}
```

**IMPORTANT: Never commit files with real private keys to your repository. Use environment variables or secure key management.**

## Testing Your Implementation

1. Obtain testnet ETH from Base Sepolia and Optimism Sepolia faucets
2. Start your application: `npm run dev`
3. Connect your wallet to the application
4. Create an intent to transfer tokens between chains
5. Select a solver and submit your intent
6. Monitor the status of your intent through the UI

## Troubleshooting

### Common Issues

1. **Wallet Connection Errors**

   - Ensure you've set the correct WalletConnect Project ID
   - Verify that your RPC endpoints for the testnets are working

2. **Intent Creation Failures**

   - Check that you have sufficient testnet ETH for gas fees
   - Verify token contract addresses are correct for the testnets

3. **Solver Communication Issues**
   - Ensure your Docker container with the solver is running properly
   - Check that your solver has sufficient testnet ETH to submit fulfillment transactions
   - Verify network connectivity between your solver container and the blockchain RPC endpoints

### Getting Testnet Tokens

- Base Sepolia: Use the [Base Sepolia Faucet](https://www.basescan.org/faucet)
- Optimism Sepolia: Use the [Optimism Sepolia Faucet](https://www.optimism.io/faucet)

## Additional Resources

- [OIF Documentation](https://bootnodedev.github.io/intents-framework-core/)
- [Base Sepolia Explorer](https://sepolia.basescan.org/)
- [Optimism Sepolia Explorer](https://sepolia-optimism.etherscan.io/)
- [Etherscan](https://etherscan.io) for tracking transactions
