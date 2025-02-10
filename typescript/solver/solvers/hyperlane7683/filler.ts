import type { BigNumber } from "@ethersproject/bignumber";
import { AddressZero, Zero } from "@ethersproject/constants";
import type { MultiProvider } from "@hyperlane-xyz/sdk";
import {
  addressToBytes32,
  bytes32ToAddress,
  type Result,
} from "@hyperlane-xyz/utils";

import { Erc20__factory } from "../../typechain/factories/contracts/Erc20__factory.js";
import { Hyperlane7683__factory } from "../../typechain/factories/hyperlane7683/contracts/Hyperlane7683__factory.js";
import type { IntentData, OpenEventArgs } from "./types.js";
import { log, settleOrder } from "./utils.js";

import { chainIdsToName } from "../../config/index.js";
import { BaseFiller } from "../BaseFiller.js";
import {
  retrieveOriginInfo,
  retrieveTargetInfo,
  retrieveTokenBalance,
} from "../utils.js";
import { allowBlockLists, metadata } from "./config/index.js";

export type Metadata = {
  protocolName: string;
};

export type Hyperlane7683Rule = Hyperlane7683Filler["rules"][number];

class Hyperlane7683Filler extends BaseFiller<
  Metadata,
  OpenEventArgs,
  IntentData
> {
  constructor(
    multiProvider: MultiProvider,
    rules?: BaseFiller<Metadata, OpenEventArgs, IntentData>["rules"],
  ) {
    const { protocolName } = metadata;
    const hyperlane7683FillerMetadata = { protocolName };

    super(
      multiProvider,
      allowBlockLists,
      hyperlane7683FillerMetadata,
      log,
      rules,
    );
  }

  protected async retrieveOriginInfo(parsedArgs: OpenEventArgs) {
    const originTokens = parsedArgs.resolvedOrder.minReceived.map(
      ({ amount, chainId, token }) => {
        const tokenAddress = bytes32ToAddress(token);
        const chainName = chainIdsToName[chainId.toString()];
        return { amount, chainName, tokenAddress };
      },
    );

    return retrieveOriginInfo({
      multiProvider: this.multiProvider,
      tokens: originTokens,
    });
  }

  protected async retrieveTargetInfo(parsedArgs: OpenEventArgs) {
    const targetTokens = parsedArgs.resolvedOrder.maxSpent.map(
      ({ amount, chainId, token }) => {
        const tokenAddress = bytes32ToAddress(token);
        const chainName = chainIdsToName[chainId.toString()];
        return { amount, chainName, tokenAddress };
      },
    );

    return retrieveTargetInfo({
      multiProvider: this.multiProvider,
      tokens: targetTokens,
    });
  }

  protected async prepareIntent(
    parsedArgs: OpenEventArgs,
  ): Promise<Result<IntentData>> {
    const { fillInstructions, maxSpent } = parsedArgs.resolvedOrder;

    try {
      await super.prepareIntent(parsedArgs);

      return { data: { fillInstructions, maxSpent }, success: true };
    } catch (error: any) {
      return {
        error: error.message ?? "Failed to prepare Hyperlane7683 Intent.",
        success: false,
      };
    }
  }

  protected async fill(parsedArgs: OpenEventArgs, data: IntentData) {
    this.log.info({
      msg: "Filling Intent",
      intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
    });

    await Promise.all(
      data.maxSpent.map(
        async ({ amount, chainId, recipient, token: tokenAddress }) => {
          tokenAddress = bytes32ToAddress(tokenAddress);
          recipient = bytes32ToAddress(recipient);
          const _chainId = chainId.toString();

          const filler = this.multiProvider.getSigner(_chainId);

          if (tokenAddress === AddressZero) {
            // native token
            return;
          }

          const tx = await Erc20__factory.connect(tokenAddress, filler).approve(
            recipient,
            amount,
          );

          const receipt = await tx.wait();
          const baseUrl =
            this.multiProvider.getChainMetadata(_chainId).blockExplorers?.[0]
              .url;

          if (baseUrl) {
            this.log.debug({
              msg: "Approval",
              protocolName: this.metadata.protocolName,
              tx: `${baseUrl}/tx/${receipt.transactionHash}`,
            });
          } else {
            this.log.debug({
              msg: "Approval",
              protocolName: this.metadata.protocolName,
              tx: `${receipt.transactionHash}`,
            });
          }

          this.log.debug({
            msg: "Approval",
            protocolName: this.metadata.protocolName,
            amount: amount.toString(),
            tokenAddress,
            recipient,
            chainId: _chainId,
          });
        },
      ),
    );

    await Promise.all(
      data.fillInstructions.map(
        async (
          { destinationChainId, destinationSettler, originData },
          index,
        ) => {
          destinationSettler = bytes32ToAddress(destinationSettler);
          const _chainId = destinationChainId.toString();

          const filler = this.multiProvider.getSigner(_chainId);
          const fillerAddress = await filler.getAddress();
          const destination = Hyperlane7683__factory.connect(
            destinationSettler,
            filler,
          );

          const value =
            bytes32ToAddress(data.maxSpent[index].token) === AddressZero
              ? data.maxSpent[index].amount
              : undefined;

          // Depending on the implementation we may call `destination.fill` directly or call some other
          // contract that will produce the funds needed to execute this leg and then in turn call
          // `destination.fill`
          const tx = await destination.fill(
            parsedArgs.orderId,
            originData,
            addressToBytes32(fillerAddress),
            { value },
          );

          const receipt = await tx.wait();
          const baseUrl =
            this.multiProvider.getChainMetadata(_chainId).blockExplorers?.[0]
              .url;

          const txInfo = baseUrl
            ? `${baseUrl}/tx/${receipt.transactionHash}`
            : receipt.transactionHash;

          log.info({
            msg: "Filled Intent",
            intent: `${this.metadata.protocolName}-${parsedArgs.orderId}`,
            txDetails: txInfo,
            txHash: receipt.transactionHash,
          });
        },
      ),
    );
  }

  settleOrder(parsedArgs: OpenEventArgs, data: IntentData) {
    return settleOrder(
      data.fillInstructions,
      parsedArgs.orderId,
      this.multiProvider,
      this.metadata.protocolName,
    );
  }
}

const enoughBalanceOnDestination: Hyperlane7683Rule = async (
  parsedArgs,
  context,
) => {
  const amountByTokenByChain = parsedArgs.resolvedOrder.maxSpent.reduce<{
    [chainId: number]: { [token: string]: BigNumber };
  }>((acc, { token, ...output }) => {
    token = bytes32ToAddress(token);
    const chainId = output.chainId.toNumber();

    acc[chainId] ||= { [token]: Zero };
    acc[chainId][token] ||= Zero;

    acc[chainId][token] = acc[chainId][token].add(output.amount);

    return acc;
  }, {});

  for (const chainId in amountByTokenByChain) {
    const chainTokens = amountByTokenByChain[chainId];
    const fillerAddress = await context.multiProvider.getSignerAddress(chainId);
    const provider = context.multiProvider.getProvider(chainId);

    for (const tokenAddress in chainTokens) {
      const amount = chainTokens[tokenAddress];
      const balance = await retrieveTokenBalance(
        tokenAddress,
        fillerAddress,
        provider,
      );

      if (balance.lt(amount)) {
        return {
          error: `Insufficient balance on destination chain ${chainId}, for ${tokenAddress}`,
          success: false,
        };
      }
    }
  }

  return { data: "Enough tokens to fulfill the intent", success: true };
};

  // - ETH: 1
  // - OP: 10
  // - ARB: 42161
  // - Base: 8453
  // - Gnosis: 100
  // - Bera: 80094
  // - Form: 478

const allowedTokens: Record<string, string> = {
  "1": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  "10": "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85",
  "42161": "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
  "8453": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  "100": "0x2a22f9c3b484c3629090feed35f17ff8f88f76f0",
  "80094": "0x549943e04f40284185054145c6E4e9568C1D3241", // TODO - check this one
  "478": "0xFBf489bb4783D4B1B2e7D07ba39873Fb8068507D",  // TODO - check this one
};

const MAX_AMOUNT_OUT = 100*10^6;

const filterByTokenAndAmount: Hyperlane7683Rule = async (
  parsedArgs
) => {
  const tokenIn = parsedArgs.resolvedOrder.minReceived[0].token;
  const amountIn = parsedArgs.resolvedOrder.minReceived[0].amount;
  const originChainId = parsedArgs.resolvedOrder.minReceived[0].chainId.toString();

  const tokenOut = parsedArgs.resolvedOrder.maxSpent[0].token;
  const amountOut = parsedArgs.resolvedOrder.maxSpent[0].amount;
  const destChainId = parsedArgs.resolvedOrder.maxSpent[0].chainId.toString();

  if (
    tokenIn !== allowedTokens[originChainId] ||
    tokenOut !== allowedTokens[destChainId] ||
    amountIn.lt(amountOut) ||
    amountOut.gt(MAX_AMOUNT_OUT)
  ) {
    return { error: "Amounts and tokens are not ok", success: false };
  }

  return { data: "Amounts and tokens are ok", success: true };
}

export const create = (
  multiProvider: MultiProvider,
  rules?: Hyperlane7683Filler["rules"],
  keepBaseRules = true,
) => {
  const customRules = rules ?? [];

  return new Hyperlane7683Filler(
    multiProvider,
    keepBaseRules ? [filterByTokenAndAmount, enoughBalanceOnDestination, ...customRules] : customRules,
  ).create();
};
