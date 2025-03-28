# Testnet Intent Chamber Integration Guide

## Overview

This guide walks you through setting up a custom Next.js (JavaScript) UI that integrates with the Open Intents Framework to create a testnet-only Intent Chamber. This implementation will focus on Base Sepolia and OP Sepolia testnets for token bridging.

## Project Setup

### 1. Create a New Next.js Project

```bash
# Create a new Next.js project with JavaScript
npx create-next-app@latest intent-chamber --javascript --eslint
cd intent-chamber
```

### 2. Install Dependencies

```bash
npm install @bootnodedev/intents-framework-core @rainbow-me/rainbowkit viem wagmi@2.x @tanstack/react-query framer-motion react-toastify tailwindcss
```

### 3. Configure Tailwind CSS

```bash
npx tailwindcss init -p
```

Update `tailwind.config.js`:

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,jsx}",
    "./components/**/*.{js,jsx}",
    "./app/**/*.{js,jsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
```

## Project Structure

Create the following folder structure:

```
intent-chamber/
├── components/
│   ├── intent/
│   │   ├── IntentChamber.js       # Main component for intent flow
│   │   ├── SolverCard.js          # Component for solver selection
│   │   ├── IntentReview.js        # Component for reviewing intent details
│   │   └── IntentStatus.js        # Component for tracking execution
│   └── layout/
│       └── Header.js              # Site header with wallet connection
├── lib/
│   ├── wallet-config.js           # Wallet and chain configuration
│   ├── oif-components.js          # OIF component imports
│   ├── chain-config.js            # Testnet configuration
│   └── solver-client.js           # Interface for solver interactions
├── hooks/
│   └── useIntent.js               # Custom hook for intent management
├── pages/
│   ├── _app.js                    # App component with providers
│   └── index.js                   # Main page
├── public/
│   └── images/                    # Solver images
└── styles/
    └── globals.css                # Global styles
```

## Implementation Steps

### 1. Configure Wallet and Chain Integration

Create `lib/wallet-config.js`:

```javascript
import { createConfig } from "wagmi";
import { baseSepolia, optimismSepolia } from "viem/chains";
import { getDefaultWallets } from "@rainbow-me/rainbowkit";
import { http } from "viem";
import "@rainbow-me/rainbowkit/styles.css";

// Configure testnet chains
const chains = [baseSepolia, optimismSepolia];

// Real wallet connections
const { connectors } = getDefaultWallets({
  appName: "Intent Chamber",
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_ID,
  chains,
});

export const wagmiConfig = createConfig({
  chains,
  transports: {
    [baseSepolia.id]: http(),
    [optimismSepolia.id]: http(),
  },
  connectors,
});

export { chains };
```

### 2. Set Up OIF Components

Create `lib/oif-components.js`:

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

### 3. Configure Testnet Chains and Tokens

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

### 4. Create Intent Management Hook

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

  // Get the status of an intent
  const getIntentStatus = useCallback(async (intentId) => {
    try {
      const solverClient = new SolverClient();
      const status = await solverClient.getIntentStatus(intentId);
      setStatus(status);
      return status;
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  return {
    intent,
    status,
    error,
    createIntent,
    submitIntent,
    getIntentStatus,
  };
}
```

### 5. Create UI Components

#### 5.1. Create the Main IntentChamber Component

Create `components/intent/IntentChamber.js`:

```javascript
import React, { useState, useEffect } from "react";
import { toast, ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { useAccount } from "wagmi";
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
      <ToastContainer position="top-right" autoClose={5000} />

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

#### 5.2. SolverCard Component

Create `components/intent/SolverCard.js`:

```javascript
import React from "react";
import Image from "next/image";

export function SolverCard({ solver, onClick }) {
  return (
    <div
      className="bg-slate-700 p-4 rounded-lg cursor-pointer transition-all hover:bg-slate-600 hover:-translate-y-1"
      onClick={onClick}
    >
      <div className="flex flex-col items-center">
        <div className="w-20 h-20 rounded-full overflow-hidden bg-slate-500 mb-3">
          {solver.image && (
            <Image
              src={solver.image}
              alt={solver.name}
              width={80}
              height={80}
              className="object-cover"
            />
          )}
        </div>
        <h3 className="text-xl font-semibold">{solver.name}</h3>
        <p className="text-slate-300 text-sm mt-1">{solver.description}</p>
        <div className="mt-3 grid grid-cols-2 gap-2 w-full">
          <div className="bg-slate-800 p-2 rounded text-center">
            <p className="text-xs text-slate-400">Speed</p>
            <p className="text-sm">
              {solver.speedMultiplier < 1
                ? "Fast"
                : solver.speedMultiplier === 1
                  ? "Medium"
                  : "Slow"}
            </p>
          </div>
          <div className="bg-slate-800 p-2 rounded text-center">
            <p className="text-xs text-slate-400">Cost</p>
            <p className="text-sm">
              {solver.costMultiplier > 1
                ? "High"
                : solver.costMultiplier === 1
                  ? "Medium"
                  : "Low"}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
```

#### 5.3. IntentReview Component

Create `components/intent/IntentReview.js`:

```javascript
import React from "react";

export function IntentReview({ intent, solver, onExecute, isConnected }) {
  // Format token amount for display
  const formatAmount = (amount, decimals = 18) => {
    if (!amount) return "0";
    return (Number(amount) / 10 ** decimals).toFixed(6);
  };

  // Calculate estimated fee based on solver's cost multiplier
  const estimatedFee = (0.001 * solver.costMultiplier).toFixed(6);

  // Calculate estimated time based on solver's speed multiplier (in minutes)
  const estimatedTime = Math.round(5 * solver.speedMultiplier);

  return (
    <div className="bg-slate-800 p-6 rounded-lg shadow-lg">
      <h2 className="text-2xl font-bold mb-4">Review Intent</h2>
      <p className="mb-6">Review your intent details before execution</p>

      <div className="bg-slate-700 p-4 rounded-lg mb-6">
        <div className="flex items-center justify-between mb-4">
          <span className="text-slate-300">Solver:</span>
          <span className="font-medium">{solver.name}</span>
        </div>
        <div className="flex items-center justify-between mb-4">
          <span className="text-slate-300">From Chain:</span>
          <span className="font-medium">{intent.sourceChain}</span>
        </div>
        <div className="flex items-center justify-between mb-4">
          <span className="text-slate-300">To Chain:</span>
          <span className="font-medium">{intent.targetChain}</span>
        </div>
        <div className="flex items-center justify-between mb-4">
          <span className="text-slate-300">Token:</span>
          <span className="font-medium">{intent.tokenSymbol}</span>
        </div>
        <div className="flex items-center justify-between mb-4">
          <span className="text-slate-300">Amount:</span>
          <span className="font-medium">
            {formatAmount(intent.amount, intent.tokenDecimals)}
          </span>
        </div>
        <div className="flex items-center justify-between mb-4">
          <span className="text-slate-300">Estimated Fee:</span>
          <span className="font-medium">{estimatedFee} ETH</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-slate-300">Estimated Time:</span>
          <span className="font-medium">{estimatedTime} minutes</span>
        </div>
      </div>

      <button
        className={`w-full py-3 px-6 rounded-lg text-white font-medium transition-colors ${
          isConnected
            ? "bg-blue-600 hover:bg-blue-700"
            : "bg-gray-500 cursor-not-allowed"
        }`}
        onClick={onExecute}
        disabled={!isConnected}
      >
        Execute Intent
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

#### 5.4. IntentStatus Component

Create `components/intent/IntentStatus.js`:

```javascript
import React from "react";

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

      <div className="text-5xl mb-6">{currentConfig.icon}</div>

      <p className="mb-6">{currentConfig.description}</p>

      <div className="bg-slate-700 p-4 rounded-lg mb-6">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <p className="text-slate-400 text-sm">From Chain</p>
            <p>{intent.sourceChain}</p>
          </div>
          <div>
            <p className="text-slate-400 text-sm">To Chain</p>
            <p>{intent.targetChain}</p>
          </div>
          <div>
            <p className="text-slate-400 text-sm">Amount</p>
            <p>
              {intent.tokenSymbol}{" "}
              {Number(intent.amount) / 10 ** intent.tokenDecimals}
            </p>
          </div>
          <div>
            <p className="text-slate-400 text-sm">Solver</p>
            <p>{solver.name}</p>
          </div>
        </div>
      </div>

      {signedIntent && (
        <div className="bg-slate-900 p-3 rounded text-left overflow-hidden">
          <p className="text-slate-400 text-sm mb-1">Intent ID:</p>
          <p className="text-xs text-slate-300 truncate">{signedIntent.id}</p>
        </div>
      )}
    </div>
  );
}
```

### 6. Create App Component with Providers

Update `pages/_app.js`:

```javascript
import "../styles/globals.css";
import { RainbowKitProvider } from "@rainbow-me/rainbowkit";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { wagmiConfig, chains } from "../lib/wallet-config";

// Create React Query client
const queryClient = new QueryClient();

function MyApp({ Component, pageProps }) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider chains={chains}>
          <Component {...pageProps} />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default MyApp;
```

### 7. Create Main Page

Update `pages/index.js`:

```javascript
import Head from "next/head";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { IntentChamber } from "../components/intent/IntentChamber";

export default function Home() {
  return (
    <div className="min-h-screen bg-slate-900 text-white">
      <Head>
        <title>Testnet Intent Chamber</title>
        <meta
          name="description"
          content="A testnet-only intent chamber for token bridging"
        />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <header className="py-4 px-6 border-b border-slate-700">
        <div className="container mx-auto flex justify-between items-center">
          <h1 className="text-xl font-bold">Testnet Intent Chamber</h1>
          <ConnectButton />
        </div>
      </header>

      <main className="container mx-auto py-8 px-4">
        <IntentChamber />
      </main>

      <footer className="py-6 border-t border-slate-700 text-center text-slate-400">
        <p>Powered by Open Intents Framework</p>
      </footer>
    </div>
  );
}
```

### 8. Create Environment Variables

Create `.env.local` in your project root:

```
NEXT_PUBLIC_WALLET_CONNECT_ID=your_wallet_connect_project_id
```

## Testing Your Implementation

1. Get testnet tokens for Base Sepolia and Optimism Sepolia:

   - [Base Sepolia Faucet](https://www.basescan.org/faucet)
   - [Optimism Sepolia Faucet](https://www.optimism.io/faucet)

2. Start your Next.js application:

   ```bash
   npm run dev
   ```

3. Connect your wallet and ensure it's configured for the testnet networks.

4. Create an intent to bridge tokens between the two testnets.

5. Follow the flow to select a solver, review the intent, and execute it.

## Troubleshooting

- **Wallet Connection Issues**: Ensure you have the proper `NEXT_PUBLIC_WALLET_CONNECT_ID` in your `.env.local` file.
- **Missing Testnet Tokens**: Use the provided faucet links to get testnet tokens.
- **RPC Errors**: If you encounter RPC connection issues, consider using alternative RPC providers for the testnets.

- **Intent Execution Failures**: Check that your solver is properly configured and running.

## Next Steps

- Customize the UI to match your branding
- Add more testnet networks
- Implement more complex intent types
- Add an intent history feature
- Enhance error handling and user feedback

By following this guide, you should have a functional testnet Intent Chamber that demonstrates the core capabilities of the Open Intents Framework.
