📘 SOLVER.md
A Comprehensive Guide to the Intent Solver Architecture

🧠 Overview
The Intent Solver is a modular, protocol-agnostic TypeScript application designed to process and execute cross-chain user intents. It listens to on-chain events across multiple blockchains, validates and interprets those events using customizable rules, and fulfills them by executing transactions via protocol-specific logic such as Hyperlane's cross-chain messaging protocol.

Its architecture is built for flexibility, composability, and extensibility, enabling support for multiple protocols simultaneously while avoiding redundant logic across implementations.

🏗️ Architecture Diagram
text
Copy
Edit
┌─────────────────┐
│  SolverManager  │
└────────┬────────┘
         │
┌────────▼────────┐
│ Initializes all │
│ protocol solvers│
└──────┬──────────┘
       │
 ┌─────▼────────────────────────────────────────────────────────┐
 │                      Protocol-Specific Solver                │
 │ ┌────────────────┐ ┌────────────────┐ ┌────────────────────┐ │
 │ │   Listener     │→│    Filler      │→│       Rules        │ │
 │ └────────────────┘ └────────────────┘ └────────────────────┘ │
 └──────────────────────────────────────────────────────────────┘
🚀 Execution Lifecycle
1. Startup and Initialization
The SolverManager is the main entry point and is responsible for:

Loading the configuration from solvers.json

Enabling or disabling protocol-specific solvers

Instantiating listeners and fillers for each protocol

Managing the lifecycle of active listeners

ts
Copy
Edit
await this.initializeSolver(solverName as SolverName);
Each protocol has its own listener.ts and filler.ts implementation.

2. Listening for Intents
Each solver uses a BaseListener subclass to:

Connect to specific smart contracts on each supported chain

Set up filters for protocol-specific events (e.g., IntentCreated)

Poll recent blocks for missed events

Parse events into standardized intent objects (ParsedArgs)

Pass valid intents to the Filler for processing

ts
Copy
Edit
await contract.queryFilter(filter, from, to)
Historical blocks are processed using a database-backed checkpointing system via SQLite (db.ts).

3. Intent Validation (Rules Engine)
Each Filler evaluates the intent using a series of Rules:

Rules are reusable, composable async functions

Example rules:

✅ Intent not already filled

✅ Tokens are allowed

✅ Sufficient balance or slippage margin

✅ Transaction is profitable

ts
Copy
Edit
for (const rule of this.rules) {
  result = await rule(parsedArgs, this);
}
Example rule files:

intentNotFilled.ts

filterByTokenAndAmount.ts

If any rule fails, the intent is rejected.

4. Intent Fulfillment
Once an intent passes all rules, the fill() function is called. This is where protocol-specific fulfillment happens.

For example, in Hyperlane7683Filler:

Prepares gas payments and token approvals

Constructs the transaction to call settleOrder() using Hyperlane messaging

Routes cross-chain data and funds securely via Hyperlane’s infrastructure

Returns success or failure with structured IntentData

ts
Copy
Edit
await settleOrder(fillInstructions, originChainId, orderId, this.multiProvider, "hyperlane7683");
Each Filler implementation can customize:

Settlement strategy

Token approval flow

Message routing logic

5. Tracking & Deduplication
The solver uses a SQLite database (libsql) to persist:

Last processed blocks per chain

List of processed orderIds to prevent duplicates

Tracked via:

indexedBlocks table in hyperlane7683/db.ts

getLastIndexedBlocks() to resume safely on restart

🔧 Configuration
Solvers are configured through:

json
Copy
Edit
// solvers.json
{
  "eco": {
    "enabled": true
  },
  "hyperlane7683": {
    "enabled": true
  }
}
Each protocol has:

Independent enable/disable flags

Rule-specific configs via metadata.ts

Allow/block lists for fine-grained control

🧩 Modularity
The entire solver stack is built for modularity:

Component	Description
SolverManager	Central controller that loads all solvers from config
BaseListener	Abstract listener class for event monitoring
BaseFiller	Abstract filler class for executing intents
Rules	Pluggable rule system for validating intents before execution
MultiProvider	Utility for managing multiple RPC endpoints
SQLite DB	Tracks processed blocks and filled intents to ensure idempotency
settleOrder	Utility for Hyperlane-based cross-chain messaging
Each protocol implementation (e.g., Hyperlane7683 or ECO) simply needs to provide:

A Listener subclass

A Filler subclass

Optional rules and types

🐳 Docker & Deployment
The project comes with a Dockerfile for containerized execution:

dockerfile
Copy
Edit
FROM node:20-alpine
...
CMD [ "node", "run.mjs" ]
Use pm2 to manage production deployment:

js
Copy
Edit
// ecosystem.config.js
module.exports = {
  apps : [{
    name: "solver",
    script: "./typescript/solver/dist/index.js"
  }]
}
🧪 Example Flow (Hyperlane7683)
User creates a cross-chain swap intent on the source chain

Hyperlane7683Listener detects the event

Parsed into standardized ParsedArgs

Passed to Hyperlane7683Filler

All rules evaluated

If valid, transaction executed via Hyperlane

Intent marked as filled in DB

➕ Adding a New Protocol
Use the built-in script:

bash
Copy
Edit
yarn solver:add <protocol-name>
This:

Creates the listener.ts, filler.ts, and types.ts boilerplate

Adds the protocol to solvers.json

Updates SolverManager for initialization

🛡 Security
✅ NonceKeeperWallet to avoid transaction collision

✅ Rule system to filter malicious or invalid intents

✅ Allow/block lists for filtering by user, chain, token

✅ Gas estimates and checks to prevent DoS via under-funded transactions

📈 Observability
Logging via Logger with multiple levels (info, debug, error)

Future support planned for:

Prometheus metrics

Slack/webhook alerts

Tracing intent lifecycle

🧩 Protocols Supported (as of now)
Protocol	Description
Hyperlane7683	ERC-7683 intents via Hyperlane messaging
ECO	Native ECO ecosystem intents (custom logic)
🧠 Final Notes
This solver system is designed to serve as a canonical, extensible reference for intent processing across Ethereum and beyond. By abstracting intent logic, messaging, execution, and validation into cleanly separated components, it ensures that adding new intent protocols or supporting new chains is straightforward, testable, and production-ready.

Build with confidence. Execute with precision. Extend without fear.