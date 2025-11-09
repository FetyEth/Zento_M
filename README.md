# Zento Markets - Permissionless Launchpad

A permissionless prediction market launchpad built on Binance Smart Chain (BSC). Zento Markets enables users to create and trade on binary outcome markets (YES/NO) with automated market-making using a **Constant Product Market Maker (CPMM)**, native governance token staking, and transparent settlement.


## Overview

Zento Markets allows users to:
- Create markets on any future event with binary outcomes (YES/NO)
- Buy and sell positions (shares) on YES or NO outcomes
- Provide liquidity to individual markets or the global liquidity pool
- Stake ZENT tokens to earn rewards and unlock platform benefits
- Participate in dispute resolution for market outcomes
- Track comprehensive market analytics and history
- Claim winnings after market resolution

The platform uses a **Constant Product Market Maker (CPMM)** with the formula `x * y = k` for automated market making, ensuring continuous liquidity and price discovery.

## Features

### 🎯 Market Creation
- Create custom prediction markets with titles, descriptions, and resolution criteria
- Set market end times and designate oracles
- Require initial liquidity provision
- Two-tier system: **Standard** and **Optima** markets
- Market creation fee discounts for ZENT stakers

### 💱 Trading
- Buy YES or NO positions using BSC USDT 
- Sell positions before market resolution
- Dynamic pricing based on CPMM algorithm
- Slippage protection with maximum price limits
- Real-time price updates
- Trading fee discounts for ZENT stakers (up to 50%)

### 💧 Liquidity Provision
- **Market-Specific Liquidity**: Add liquidity to individual markets to earn trading fees
- **Global Liquidity Pool**: Deposit into a platform-wide pool for automatic allocation to high-performing Optima markets
- LP boost multipliers for ZENT stakers (up to 2.5x)
- Remove liquidity before market resolution
- Claim principal after market resolution

### 🪙 ZENT Token & Staking
- Native governance and utility token (ERC-20)
- Stake ZENT tokens for 30 days to 4 years
- Four staking tiers: Bronze, Silver, Gold, Platinum
- Earn staking rewards with tier-based multipliers (1x to 2x)
- Compound rewards automatically
- Benefits include:
  - Trading fee discounts (10% - 50%)
  - Market creation fee discounts (15% - 70%)
  - LP boost multipliers (1.2x - 2.5x)
  - Enhanced staking APY

### 📊 Advanced Analytics
- Comprehensive trade history tracking
- Volume metrics (total, daily, hourly)
- Unique trader statistics
- Market-specific analytics
- Platform-wide statistics

### ✅ Resolution & Disputes
- Oracle-based market resolution
- Community dispute mechanism with ZENT token staking
- 1-hour dispute window after resolution
- Dispute rewards for successful challenges
- Token slashing for frivolous disputes
- Automated payout distribution


## Architecture

### Data Structures

#### `Market`
Core market structure containing:
- Market metadata (title, description, resolution criteria)
- Trading pools (YES/NO reserves with global allocation tracking)
- Position tracking
- Analytics data
- Resolution status and disputes
- Market tier (Standard/Optima)

#### `Position`
User position in a market:
- User address
- Outcome (YES=1, NO=2)
- Number of shares
- Average purchase price
- Timestamp

#### `MarketPool`
Market-specific liquidity pool:
- YES and NO reserves
- Total LP tokens
- Virtual reserves for price stability
- Global liquidity allocations

#### `MarketAnalytics`
Comprehensive market metrics:
- Volume statistics
- Trade counts
- Unique traders
- Fee totals

#### `GlobalLiquidityPool`
Platform-wide liquidity management:
- Total deposits and allocations
- LP token supply
- Pending fees distribution

#### `StakeInfo` (ZENT Token)
User staking information:
- Staked amount
- Lock end time
- Staking tier
- Reward tracking

#### `Dispute`
Market dispute details:
- Disputer address
- Proposed outcome
- Stake amount
- Status and timeline

### AMM Pricing (CPMM)

The contract uses a **Constant Product Market Maker (CPMM)** for pricing, based on the formula:

```
x * y = k
```

Where:
- `x` = YES reserve (including global allocation)
- `y` = NO reserve (including global allocation)
- `k` = constant product

The price for an outcome is calculated as:

```
Price(outcome) = outcome_reserve / (yes_reserve + no_reserve) * PRICE_PRECISION
```

Price bounds: 0.5% to 99.5% (50 to 9950 in PRICE_PRECISION units)

This ensures:
- ✅ Continuous liquidity
- ✅ Prices sum to ~100%
- ✅ Smooth price discovery
- ✅ Stable market maker behavior

## Core Concepts

### Market Tiers

1. **Standard Markets**: Basic markets with initial liquidity < 1,000 USDT
2. **Optima Markets**: High-liquidity markets (≥ 1,000 USDT) eligible for global liquidity allocation

### Market States

1. **Active**: Market is open for trading (before end time)
2. **Ended**: Past end time, awaiting resolution
3. **Resolved**: Oracle has determined outcome
4. **Disputed**: Under community dispute review

### Outcomes

- **YES (1)**: Event will occur
- **NO (2)**: Event will not occur

### Staking Tiers (ZENT Token)

| Tier | Minimum Stake | Trading Fee Discount | Creation Fee Discount | LP Boost | Reward Multiplier |
|------|---------------|---------------------|----------------------|----------|-------------------|
| Bronze | 1,000 ZENT | 10% | 15% | 1.2x | 1.0x |
| Silver | 10,000 ZENT | 20% | 30% | 1.5x | 1.25x |
| Gold | 50,000 ZENT | 30% | 50% | 2.0x | 1.5x |
| Platinum | 250,000 ZENT | 50% | 70% | 2.5x | 2.0x |

## Usage

### USDT Approval (Required First)

Users must approve USDT spending before interacting with the platform:

```javascript
// Check and approve USDT allowance
await zentoMarkets.checkAndApproveUSDT();

// Or approve specific amount for market creation
await zentoMarkets.approveForMarketCreation(
  ethers.utils.parseEther("100")
);

// Check current allowance
const allowance = await zentoMarkets.getUSDTCurrentAllowance(userAddress);
```

### Creating a Market

```javascript
await zentoMarkets.createMarket(
  "Will Bitcoin reach $100K by EOY 2025?",
  "Market resolves YES if BTC reaches $100,000 on any major exchange",
  "Resolution based on CoinGecko data",
  1735689600, // Unix timestamp for end time
  "0xOracleAddress",
  ethers.utils.parseEther("100") // Initial liquidity in USDT
);
```

### Buying a Position

```javascript
await zentoMarkets.buyPosition(
  1, // Market ID
  1, // Outcome (1=YES, 2=NO)
  ethers.utils.parseEther("10"), // Amount in USDT
  9500 // Max price (95% in PRICE_PRECISION)
);
```

### Adding Liquidity

```javascript
// Add to specific market
await zentoMarkets.addLiquidity(
  1, // Market ID
  ethers.utils.parseEther("50") // Amount in USDT
);

// Add to global pool
await zentoMarkets.depositGlobalLiquidity(
  ethers.utils.parseEther("1000")
);
```

### Staking ZENT Tokens

```javascript
await zentoToken.stake(
  ethers.utils.parseEther("10000"), // Amount
  90 * 24 * 60 * 60 // Lock duration (90 days)
);

// Claim rewards
await zentoToken.claimRewards();

// Compound rewards
await zentoToken.compoundRewards();

// Unstake (after lock period)
await zentoToken.unstake(ethers.utils.parseEther("10000"));
```

### Resolving a Market

```javascript
// Admin, oracle, or creator can resolve
await zentoMarkets.resolveMarket(
  1, // Market ID
  1  // Outcome (1=YES, 2=NO)
);
```

### Initiating a Dispute

```javascript
await zentoMarkets.initiateDispute(
  1, // Market ID
  2, // Proposed outcome
  ethers.utils.parseEther("1000") // ZENT stake
);
```

### Claiming Winnings

```javascript
await zentoMarkets.claimWinnings(
  1, // Market ID
  1  // Position ID
);

// Claim LP principal after resolution
await zentoMarkets.claimLpPrincipal(1);
```

## Contract Functions

### Entry Functions (State-Changing)

| Function | Description | Parameters |
|----------|-------------|------------|
| `createMarket` | Create a new market | `title, description, criteria, endTime, oracle, initialLiquidity` |
| `buyPosition` | Buy YES/NO shares | `marketId, outcome, amount, maxPrice` |
| `addLiquidity` | Add liquidity to market | `marketId, amount` |
| `depositGlobalLiquidity` | Deposit to global pool | `amount` |
| `withdrawGlobalLiquidity` | Withdraw from global pool | `lpTokens` |
| `resolveMarket` | Resolve market outcome | `marketId, outcome` |
| `claimWinnings` | Claim winning position | `marketId, positionId` |
| `claimLpPrincipal` | Claim LP principal | `marketId` |
| `initiateDispute` | Challenge market outcome | `marketId, proposedOutcome, stakeAmount` |
| `finalizeDispute` | Admin resolves dispute | `marketId, uphold` |
| `checkAndApproveUSDT` | Approve USDT spending | None |
| `setPaused` | Pause/unpause platform | `paused` |
| `updateFees` | Update fee parameters | `platformFeeRate, marketCreationFee, tradeFeeRate, globalLpFeeRate` |

### View Functions (Read-Only)

| Function | Description | Returns |
|----------|-------------|---------|
| `getMarketDetails` | Get full market info | Market metadata and stats |
| `getMarketPoolInfo` | Get pool reserves and LP data | Reserves, LP tokens, shares |
| `getUserPositions` | Get user's position IDs | Array of position IDs |
| `getPosition` | Get position details | User, outcome, shares, price |
| `getMarketAnalytics` | Get market analytics | Volume, trades, fees |
| `calculateOutcomePrice` | Get current price | Price in PRICE_PRECISION |
| `getGlobalPoolStats` | Get global pool info | Deposits, allocations, LP tokens |
| `getUserGlobalLpBalance` | Get user's global LP tokens | LP token balance |
| `getMarketLpBalance` | Get user's market LP tokens | LP token balance |
| `getAllMarketIds` | Get all market IDs | Array of market IDs |
| `marketExists` | Check if market exists | Boolean |

### ZENT Token Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `stake` | Stake ZENT tokens | `amount, lockDuration` |
| `unstake` | Unstake tokens (after lock) | `amount` |
| `claimRewards` | Claim staking rewards | None |
| `compoundRewards` | Reinvest rewards | None |
| `calculatePendingRewards` | View pending rewards | `account` |
| `getStakingInfo` | Get complete staking info | `account` |
| `buyTokensInSale` | Buy ZENT in public sale | `baseTokenAmount` |
| `getTradingFeeDiscount` | Get user's fee discount | `account` |
| `getMarketCreationDiscount` | Get creation discount | `account` |
| `getLPBoost` | Get LP boost multiplier | `account` |

## ZENT Token & Staking

### Token Economics

- **Total Supply**: Configurable (e.g., 1,000,000,000 ZENT)
- **Public Sale Allocation**: Configurable percentage
- **Staking Rewards**: Funded by platform treasury
- **Utility**: Governance, staking, fee discounts, dispute resolution

### Staking Mechanism

1. **Lock Period**: Minimum 30 days, maximum 4 years
2. **Tier Progression**: Automatic based on staked amount
3. **Rewards**: Calculated per second with tier multipliers
4. **Compounding**: Reinvest rewards to increase stake
5. **Dispute Locking**: Tokens locked during active disputes

### Reward Distribution

- Rewards calculated using `accRewardPerShare` with high precision (1e36)
- Tier multipliers applied to base rewards
- APY varies by tier and total staked amount
- Rewards claimed separately or compounded into stake

## Fee Structure

### Trading Fees
- **Standard Markets**: 1% (100 basis points)
- **Optima Markets with Global Liquidity**: 0.8% (80 basis points)
- **ZENT Staker Discounts**: Up to 50% reduction
- Applied on buy transactions
- Distributed to platform and creators

### Platform Fees
- **Platform Fee**: 0.5% (50 basis points)
- Collected on market resolution
- Sent to platform admin

### Creator Fees
- **Creator Fee**: 20% of total trading fees collected
- Rewarded to market creator
- Incentivizes quality market creation

### Market Creation
- **Base Creation Fee**: 1 USDT
- **ZENT Staker Discounts**: Up to 70% reduction
- **Minimum Initial Liquidity**: 10 USDT (Standard), 1,000 USDT (Optima)
- **Minimum Market Duration**: 1 hour (3,600 seconds)

### Global Liquidity Pool Fees
- **Global LP Fee Rate**: 0.8% (80 basis points) on Optima trades
- **Global LP Share**: 50% of fees go to global LP providers
- Distributed proportionally to LP token holders

### Dispute Fees
- **Minimum Dispute Stake**: 1,000 ZENT
- **Dispute Reward**: 100 ZENT for successful challenges
- **Slashing**: 100% of stake for failed disputes


### Audit Recommendations

- Complete security audit before mainnet deployment
- Thorough testing of all edge cases
- Fuzz testing for AMM calculations
- Gas optimization review
- Frontend integration testing with BSC USDT

## Example Use Cases

### Sports Betting
```
"Will Team A win the championship?"
- Users bet YES or NO
- Oracle resolves after game
- Winners claim proportional payouts
- Community can dispute incorrect resolutions
```

### Price Predictions
```
"Will BTC reach $100K by Dec 2025?"
- Prices adjust based on market sentiment
- Real-time trading until deadline
- ZENT stakers get fee discounts
- Transparent settlement
```

### Event Outcomes
```
"Will the product launch happen on time?"
- Company creates market
- Employees/public trade
- Aggregates collective wisdom
- Dispute mechanism ensures fairness
```

### Governance Decisions
```
"Will the proposal pass?"
- Community stakes ZENT to participate
- Market prices reflect sentiment
- Resolution after vote completes
```

## Roadmap

- [x] Core prediction market functionality
- [x] CPMM automated market maker
- [x] ZENT token with staking and rewards
- [x] Global liquidity pool with auto-allocation
- [x] Dispute resolution mechanism
- [x] Comprehensive analytics
- [ ] Multi-outcome markets (>2 options)
- [ ] Chainlink/Band Protocol oracle integration
- [ ] Advanced order types (limit orders, stop-loss)

## Support & Community

- **Website**: https://zento.markets
- **Documentation**: https://docs.zento.markets
- **Twitter**: @ZentoMarkets
- **Telegram**: t.me/ZentoMarkets
- **GitHub**: github.com/zento-markets

---

**Built with ❤️ by the Zento Markets Team**