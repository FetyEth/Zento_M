import { createThirdwebClient, getContract, readContract } from "thirdweb";
import { bscTestnet } from "thirdweb/chains";
import type { Abi } from "viem";

// === AUTO-FALLBACK RPCs ===
const bscTestnetWithFallback = {
  ...bscTestnet,
  rpc: "https://bsc-testnet-rpc.publicnode.com",
};

export interface Position {
  id: number;
  user: string;
  outcome: number;
  shares: number;
  avgPrice: number;
  timestamp: number;
}

export interface MarketDetails {
  id: string;
  title: string;
  description: string;
  resolutionCriteria: string;
  resolved: boolean;
  endTime: bigint;
  outcome: number | null;
  tier: string;
  tvl: string;
  creator: string;
  oracle: string;
  yesPrice: string;
  noPrice: string;
  totalLiquidity: string;
  participantCount: string;
  yesReserve: string;
  noReserve: string;
  totalLpTokens: string;
  totalYesShares: string;
  totalNoShares: string;
  globalYesAllocation: string;
  globalNoAllocation: string;
  totalVolume: string;
  totalTrades: string;
  totalFees: string;
  last24hVolume: string;
  liquidityVolume: string;
}

// === CLIENT ===
export const client = createThirdwebClient({
  clientId: process.env.NEXT_PUBLIC_THIRDWEB_CLIENT_ID || "",
});

// === CONTRACT ADDRESS ===
const MARKET_CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_MARKET_CONTRACT_ADDRESS!;

// === FULL ABI ===
const MARKET_ABI = [
  {
    "inputs": [{ "internalType": "uint64", "name": "marketId", "type": "uint64" }],
    "name": "getMarketDetails",
    "outputs": [
      { "internalType": "uint64", "name": "id", "type": "uint64" },
      { "internalType": "string", "name": "title", "type": "string" },
      { "internalType": "string", "name": "description", "type": "string" },
      { "internalType": "uint64", "name": "endTime", "type": "uint64" },
      { "internalType": "bool", "name": "resolved", "type": "bool" },
      { "internalType": "uint8", "name": "outcome", "type": "uint8" },
      { "internalType": "uint8", "name": "tier", "type": "uint8" },
      { "internalType": "uint256", "name": "tvl", "type": "uint256" },
      { "internalType": "address", "name": "creator", "type": "address" },
      { "internalType": "address", "name": "oracle", "type": "address" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint64", "name": "marketId", "type": "uint64" },
      { "internalType": "uint8", "name": "outcome", "type": "uint8" }
    ],
    "name": "calculateOutcomePrice",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getAllMarketIds",
    "outputs": [{ "internalType": "uint64[]", "name": "", "type": "uint64[]" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "user", "type": "address" },
      { "internalType": "uint64", "name": "marketId", "type": "uint64" }
    ],
    "name": "getUserPosition",
    "outputs": [
      { "internalType": "uint64", "name": "", "type": "uint64" },
      { "internalType": "uint8", "name": "", "type": "uint8" },
      { "internalType": "uint256", "name": "", "type": "uint256" },
      { "internalType": "uint256", "name": "", "type": "uint256" },
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint64", "name": "marketId", "type": "uint64" },
      { "internalType": "uint256", "name": "limit", "type": "uint256" }
    ],
    "name": "getLatestTrades",
    "outputs": [
      {
        "components": [
          { "internalType": "address", "name": "trader", "type": "address" },
          { "internalType": "uint8", "name": "outcome", "type": "uint8" },
          { "internalType": "uint256", "name": "shares", "type": "uint256" },
          { "internalType": "uint256", "name": "price", "type": "uint256" },
          { "internalType": "uint256", "name": "timestamp", "type": "uint256" },
          { "internalType": "bytes32", "name": "txHash", "type": "bytes32" }
        ],
        "internalType": "struct IMarket.Trade[]",
        "name": "",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint64", "name": "marketId", "type": "uint64" }],
    "name": "getMarketAnalytics",
    "outputs": [
      { "internalType": "uint256", "name": "totalVolume", "type": "uint256" },
      { "internalType": "uint256", "name": "totalTrades", "type": "uint256" },
      { "internalType": "uint256", "name": "totalFees", "type": "uint256" },
      { "internalType": "uint256", "name": "last24hVolume", "type": "uint256" },
      { "internalType": "uint256", "name": "uniqueTraderCount", "type": "uint256" },
      { "internalType": "uint256", "name": "liquidityVolume", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "marketCreationFee",
    "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "internalType": "uint64", "name": "marketId", "type": "uint64" }],
    "name": "getMarketPoolInfo",
    "outputs": [
      { "internalType": "uint256", "name": "yesReserve", "type": "uint256" },
      { "internalType": "uint256", "name": "noReserve", "type": "uint256" },
      { "internalType": "uint256", "name": "totalLpTokens", "type": "uint256" },
      { "internalType": "uint256", "name": "totalYesShares", "type": "uint256" },
      { "internalType": "uint256", "name": "totalNoShares", "type": "uint256" },
      { "internalType": "uint256", "name": "globalYesAllocation", "type": "uint256" },
      { "internalType": "uint256", "name": "globalNoAllocation", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
] as const satisfies Abi;

// === TYPED CONTRACT ===
export const marketContract = getContract({
  client,
  chain: bscTestnetWithFallback,
  address: MARKET_CONTRACT_ADDRESS,
  abi: MARKET_ABI,
});

// === EXPORTED FUNCTIONS ===
export const getAllMarketIds = async (): Promise<string[]> => {
  try {
    const ids = await readContract({
      contract: marketContract,
      method: "getAllMarketIds", 
      params: [],
    });
    return ids.map(String);
  } catch (error) {
    console.error("getAllMarketIds error:", error);
    return [];
  }
};

export const getMarketDetails = async (marketId: number) => {
  try {
    // Get basic market details
    const [data, yesPrice, noPrice, poolInfo, analytics] = await Promise.all([
      readContract({
        contract: marketContract,
        method: "getMarketDetails",
        params: [BigInt(marketId)],
      }),
      readContract({
        contract: marketContract,
        method: "calculateOutcomePrice",
        params: [BigInt(marketId), 1],
      }),
      readContract({
        contract: marketContract,
        method: "calculateOutcomePrice",
        params: [BigInt(marketId), 2],
      }),
      getMarketPoolInfo(marketId),
      getMarketAnalytics(marketId), 
    ]);

    const [id, title, description, endTime, resolved, outcome, tier, tvl, creator, oracle] = data;

    return {
      id: id.toString(),
      title,
      description,
      resolutionCriteria: description, 
      resolved,
      endTime,
      outcome: outcome === 0 ? null : Number(outcome),
      tier: tier === 0 ? "STANDARD" : "OPTIMA",
      tvl: tvl.toString(),
      creator,
      oracle,
      yesPrice: yesPrice.toString(),
      noPrice: noPrice.toString(),
      totalLiquidity: tvl.toString(),
      participantCount: analytics ? analytics.uniqueTraderCount : "0",
      ...(poolInfo ? {
        yesReserve: poolInfo.yesReserve,
        noReserve: poolInfo.noReserve,
        totalLpTokens: poolInfo.totalLpTokens,
        totalYesShares: poolInfo.totalYesShares,
        totalNoShares: poolInfo.totalNoShares,
        globalYesAllocation: poolInfo.globalYesAllocation,
        globalNoAllocation: poolInfo.globalNoAllocation,
      } : {
        yesReserve: "0",
        noReserve: "0", 
        totalLpTokens: "0",
        totalYesShares: "0",
        totalNoShares: "0",
        globalYesAllocation: "0",
        globalNoAllocation: "0",
      }),
      ...(analytics ? {
        totalVolume: analytics.totalVolume,
        totalTrades: analytics.totalTrades,
        totalFees: analytics.totalFees,
        last24hVolume: analytics.last24hVolume,
        liquidityVolume: analytics.liquidityVolume,
      } : {
        totalVolume: "0",
        totalTrades: "0",
        totalFees: "0",
        last24hVolume: "0",
        liquidityVolume: "0",
      })
    };
  } catch (error) {
    console.error("getMarketDetails error:", error);
    return null;
  }
};

export const getMarketPoolInfo = async (marketId: number) => {
  try {
    const poolInfo = await readContract({
      contract: marketContract,
      method: "getMarketPoolInfo",
      params: [BigInt(marketId)],
    });

    const [yesReserve, noReserve, totalLpTokens, totalYesShares, totalNoShares, globalYesAllocation, globalNoAllocation] = poolInfo;

    return {
      yesReserve: yesReserve.toString(),
      noReserve: noReserve.toString(),
      totalLpTokens: totalLpTokens.toString(),
      totalYesShares: totalYesShares.toString(),
      totalNoShares: totalNoShares.toString(),
      globalYesAllocation: globalYesAllocation.toString(),
      globalNoAllocation: globalNoAllocation.toString(),
    };
  } catch (error) {
    console.error("getMarketPoolInfo error:", error);
    return null;
  }
};

export const getUserPositionDetails = async (user: string, marketId: number) => {
  try {
    const result = await readContract({
      contract: marketContract,
      method: "getUserPosition",
      params: [user, BigInt(marketId)],
    });

    const [id, outcome, shares, avgPrice, timestamp] = result;

    return {
      id: Number(id),
      user,
      outcome: Number(outcome),
      shares: Number(shares),
      avgPrice: Number(avgPrice),
      timestamp: Number(timestamp),
    };
  } catch {
    return null;
  }
};

export const getLatestTrades = async (marketId: number, limit = 10) => {
  try {
    const trades = await readContract({
      contract: marketContract,
      method: "getLatestTrades",
      params: [BigInt(marketId), BigInt(limit)],
    });

    return trades.map((t: any) => ({
      trader: t.trader,
      outcome: Number(t.outcome),
      shares: t.shares,
      price: t.price,
      timestamp: t.timestamp,
      txHash: t.txHash,
    }));
  } catch (error) {
    console.error("getLatestTrades error:", error);
    return [];
  }
};

export const getMarketAnalytics = async (marketId: number) => {
  try {
    const analytics = await readContract({
      contract: marketContract,
      method: "getMarketAnalytics",
      params: [BigInt(marketId)],
    });

    const [totalVolume, totalTrades, totalFees, last24hVolume, uniqueTraderCount, liquidityVolume] = analytics;

    return {
      totalVolume: totalVolume.toString(),
      totalTrades: totalTrades.toString(),
      totalFees: totalFees.toString(),
      last24hVolume: last24hVolume.toString(),
      uniqueTraderCount: uniqueTraderCount.toString(),
      liquidityVolume: liquidityVolume.toString(),
    };
  } catch (error) {
    console.error("getMarketAnalytics error:", error);
    return null;
  }
};

// === SAME AS BEFORE ===
export const getAllMarketSummaries = async () => {
  const ids = await getAllMarketIds();
  const summaries = await Promise.all(ids.map(id => getMarketSummary(Number(id))));
  return summaries.filter(Boolean);
};

export const getMarketSummary = async (marketId: number) => {
  const details = await getMarketDetails(marketId);
  if (!details) return null;

  const currentTime = Math.floor(Date.now() / 1000);
  const endTime = Number(details.endTime);
  const timeLeft = details.resolved || currentTime >= endTime ? 0 : endTime - currentTime;

  return {
    id: details.id,
    title: details.title,
    description: details.description,
    endTime: details.endTime,
    resolved: details.resolved,
    yesPrice: details.yesPrice,
    noPrice: details.noPrice,
    totalValueLocked: details.tvl,
    participantCount: "1",
    totalVolume: details.tvl,
    timeLeft: formatTimeLeft(timeLeft),
    category: "General",
    status: details.resolved ? "Resolved" : currentTime < endTime ? "Active" : "Ended",
  };
};

export const getPlatformStats = async () => {
  const ids = await getAllMarketIds();
  const details = await Promise.all(ids.map(id => getMarketDetails(Number(id))));

  let totalTvl = 0;
  let activeMarkets = 0;

  details.forEach(d => {
    if (d) {
      totalTvl += Number(d.tvl);
      if (!d.resolved) activeMarkets++;
    }
  });

  return {
    totalMarkets: ids.length,
    totalTvl,
    activeMarkets,
  };
};

export const getUserTradeHistory = async (user: string, marketId?: number, limit = 50): Promise<any[]> => {
  try {
    if (marketId) {
      const trades = await getLatestTrades(marketId, limit);
      return trades.filter((trade: any) => 
        trade.trader.toLowerCase() === user.toLowerCase()
      );
    } else {
      const marketIds = await getAllMarketIds();
      const allTrades = await Promise.all(
        marketIds.map(id => getLatestTrades(Number(id), limit))
      );
      
      return allTrades.flat().filter((trade: any) => 
        trade.trader.toLowerCase() === user.toLowerCase()
      ).sort((a: any, b: any) => Number(b.timestamp) - Number(a.timestamp));
    }
  } catch (error) {
    console.error("getUserTradeHistory error:", error);
    return [];
  }
};

// === HELPERS ===
export const formatPrice = (price: string) => (Number(price) / 100).toFixed(2) + "%";
export const formatUSDT = (amount: string) => "$" + (Number(amount) / 1e18).toFixed(2);
export const formatTimeLeft = (seconds: number): string => {
  if (seconds <= 0) return "Ended";
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (days > 0) return `${days}d`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
};