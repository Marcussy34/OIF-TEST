FROM node:20-alpine

# Bundle APP files
WORKDIR /workspace
COPY .  ./
RUN corepack enable
# Correct yarn install command for monorepo
RUN yarn install

# Move to the solver workspace
WORKDIR /workspace/typescript/solver

# Create a sample entry point script that uses the node loader with debugging
RUN echo '#!/usr/bin/env node\n\nconsole.log("Starting solver script...");\n\ntry {\n  import * as url from "url";\n  const __dirname = url.fileURLToPath(new URL(".", import.meta.url));\n  console.log("Current directory:", __dirname);\n\n  import { createRequire } from "module";\n  const require = createRequire(import.meta.url);\n\n  console.log("Running node with tsx loader...");\n  const { spawnSync } = require("child_process");\n\n  const result = spawnSync("node", ["--no-warnings", "--loader", "tsx", "index.ts"], {\n    stdio: "inherit",\n    env: process.env,\n    cwd: __dirname,\n  });\n\n  console.log("Process exited with code:", result.status);\n  if (result.error) {\n    console.error("Error:", result.error);\n  }\n\n  process.exit(result.status ?? 0);\n} catch (error) {\n  console.error("Error in run.mjs:", error);\n  process.exit(1);\n}' > run.mjs
RUN chmod +x run.mjs

# Install ts-node and tsx globally for direct TS execution
RUN npm install -g ts-node tsx

# Install pm2 for process management
RUN npm install pm2 -g

# Show current folder structure in logs
RUN ls -al -R
RUN ls -la /workspace/

# Run the entry point script
CMD [ "node", "run.mjs" ]
