// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./governance/ZentoTokenSeedify.sol";

/**
 * @title ZentoMarkets
 * @notice Main contract for Zento prediction markets
 * @dev Compatible with BSC USDT (BEP40) - uses compatibility layer
 */

// BEP40 Interface (compatible with Solidity 0.5.16 token)
interface IBEP40 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint256);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ZentoMarkets is Ownable, ReentrancyGuard {
    ZentoTokenSeedify public zentoToken;
    IBEP40 public baseToken; // BSC USDT (BEP40)
    bool public initialized;
    bool public paused;
    uint64 public nextId;
    uint64 public nextDisputeId;
    address public admin;
    uint256 public constant DISPUTE_WINDOW = 1 hours;
    uint256 public constant DISPUTE_COOLDOWN = 1 hours;
    uint256 public constant MAX_DISPUTES_PER_USER = 5;
    uint8 public constant DECIMALS = 18;
    uint256 constant PRICE_PRECISION = 10000;
    uint256 constant MIN_LIQUIDITY = 10 * 10 ** 18;
    uint256 public platformFeeRate = 50;
    uint256 public marketCreationFee = 1 * 10 ** 18;
    uint256 public minInitialLiquidity = 10 * 10 ** 18;
    uint256 public minMarketDuration = 3600;
    uint256 public tradeFeeRate = 100;
    uint256 public creatorFeeRate = 2000;
    uint256 public globalLpFeeRate = 80;
    uint256 public minOptimaLiquidity = 1000 * 10 ** 18;
    uint256 public globalLpShareRate = 5000;
    uint256 public minDisputeStake = 1000 * 10 ** 18;
    uint256 public disputeReward = 100 * 10 ** 18;
    uint256 public rewardPoolBalance;

    constructor(address _baseToken) Ownable(msg.sender) {
        require(_baseToken != address(0), "Invalid base token");
        admin = msg.sender;
        baseToken = IBEP40(_baseToken);
        
        // Deploy Zento token
        zentoToken = new ZentoTokenSeedify();
        zentoToken.setPlatformContract(address(this));
        
        initialized = true;
        nextId = 1; // Start from 1
        nextDisputeId = 1;
        
        emit SystemInitialized(msg.sender);
    }

    enum MarketTier { STANDARD, OPTIMA }
    enum DisputeStatus { NONE, ACTIVE, RESOLVED_UPHELD, RESOLVED_OVERTURNED }

    struct Position {
        address user;
        uint8 outcome;
        uint256 shares;
        uint256 avgPrice;
        uint256 timestamp;
    }

    struct MarketPool {
        uint256 yesReserve;
        uint256 noReserve;
        uint256 totalLpTokens;
        uint256 virtualYes;
        uint256 virtualNo;
        uint256 globalYesAllocation;
        uint256 globalNoAllocation;
    }

    struct MarketAnalytics {
        uint256 totalVolume;
        uint256 totalTrades;
        uint256 totalFees;
        uint256 last24hVolume;
        uint256 last24hTimestamp;
        uint256 uniqueTraderCount;
        uint256 liquidityVolume;
    }

    struct Dispute {
        uint64 disputeId;
        address disputer;
        uint8 proposedOutcome;
        uint256 stakeAmount;
        uint256 disputeEndTime;
        DisputeStatus status;
    }

    struct Market {
        uint64 id;
        string title;
        string description;
        string resolutionCriteria;
        uint64 endTime;
        address oracle;
        address creator;
        bool resolved;
        uint8 outcome;
        uint256 totalYesShares;
        uint256 totalNoShares;
        uint256 participantCount;
        uint256 creationTime;
        uint256 nextPositionId;
        uint256 lpClaimBalance;
        uint256 resolutionTime;
        MarketTier tier;
        bool hasActiveDispute;
        MarketPool ammPool;
        MarketAnalytics analytics;
        Dispute dispute;
    }

    struct GlobalLiquidityPool {
        uint256 totalDeposits;
        uint256 totalAllocated;
        uint256 totalLpTokens;
        uint256 pendingFees;
    }

    // Main storage
    mapping(uint64 => Market) private markets;
    GlobalLiquidityPool private globalPool;
    
    // Separate mappings for nested data
    mapping(uint64 => mapping(address => uint256)) private marketLpProviders;
    mapping(uint64 => mapping(address => uint64[])) private userMarketPositions;
    mapping(uint64 => mapping(uint64 => Position)) private marketPositions;
    mapping(uint64 => mapping(address => bool)) private marketUniqueTraders;
    mapping(uint64 => uint256) private globalPoolMarketAllocations;
    mapping(address => uint256) private globalPoolLpProviders;
    
    // Public mappings
    mapping(address => uint256[]) public userDisputes;
    mapping(address => uint256) public lastDisputeTime;
    mapping(uint64 => bool) public activeMarkets;

    // ============ EVENTS ============
    event SystemInitialized(address indexed admin);
    event MarketCreated(uint64 indexed id, address indexed creator, MarketTier tier, uint256 initialLiquidity);
    event PositionBought(uint64 indexed marketId, address indexed user, uint8 outcome, uint256 shares, uint256 amount);
    event MarketResolved(uint64 indexed marketId, uint8 outcome, address indexed resolver);
    event DisputeInitiated(uint64 indexed marketId, uint64 indexed disputeId, address indexed disputer);
    event DisputeResolved(uint64 indexed marketId, uint64 indexed disputeId, DisputeStatus outcome);
    event DisputeCancelled(uint64 indexed marketId, uint64 indexed disputeId, DisputeStatus status);
    event GlobalLiquidityDeposited(address indexed provider, uint256 amount);
    event GlobalLiquidityWithdrawn(address indexed provider, uint256 amount);
    event GlobalLiquidityAllocated(uint64 indexed marketId, uint256 amount);
    event GlobalLiquidityReclaimed(uint64 indexed marketId, uint256 amount);
    event WinningsClaimed(uint64 indexed marketId, address indexed user, uint64 positionId, uint256 amount);
    event LpPrincipalClaimed(uint64 indexed marketId, address indexed provider, uint256 amount);
    event Paused(address indexed admin);
    event Unpaused(address indexed admin);
    event FeesUpdated(uint256 platformFeeRate, uint256 marketCreationFee, uint256 tradeFeeRate, uint256 globalLpFeeRate);
    event DisputeRewardUpdated(uint256 newReward);
    event RewardPoolFunded(uint256 amount);
    event LiquidityAdded(uint64 indexed marketId, address indexed provider, uint256 amount, uint256 lpTokens);
    event USDTApprovedInfinite(address indexed user);
    event USDTCreationApproved(address indexed user, uint256 amount);

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Not initialized");
        _;
    }

    // ============ ADMIN FUNCTIONS ============
    function mintZentTokens(uint256 ts, uint256 ps, address dw, string memory uri) external onlyOwner {
        zentoToken.mintInitialSupply(ts, ps, dw, uri);
    }

    function updateZentMetadata(string memory uri, string memory w, string memory t, string memory tw) external onlyOwner {
        zentoToken.updateMetadata(uri, w, t, tw);
    }

    function markSeedifyLaunched() external onlyOwner {
        zentoToken.markSeedifyLaunched();
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) emit Paused(msg.sender);
        else emit Unpaused(msg.sender);
    }

    function updateFees(uint256 pf, uint256 mcf, uint256 tf, uint256 glf) external onlyOwner whenNotPaused {
        require(pf <= 1000 && tf <= 1000 && glf <= 1000, "Fee rate too high");
        require(mcf > 0, "Invalid creation fee");
        platformFeeRate = pf;
        marketCreationFee = mcf;
        tradeFeeRate = tf;
        globalLpFeeRate = glf;
        emit FeesUpdated(pf, mcf, tf, glf);
    }

    function setDisputeReward(uint256 _disputeReward) external onlyOwner whenNotPaused {
        require(_disputeReward > 0, "Invalid reward");
        disputeReward = _disputeReward;
        emit DisputeRewardUpdated(_disputeReward);
    }

    function fundRewardPool(uint256 amount) external onlyOwner whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(zentoToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        zentoToken.transferFrom(msg.sender, address(this), amount);
        rewardPoolBalance += amount;
        emit RewardPoolFunded(amount);
    }

    // ============ BEP40 COMPATIBLE FUNCTIONS ============
    function _safeBEP40TransferFrom(address from, address to, uint256 amount) internal {
        require(amount > 0, "Zero amount");
        uint256 balanceBefore = baseToken.balanceOf(to);
        
        // BEP40 returns boolean, so we need to handle it properly
        bool success = baseToken.transferFrom(from, to, amount);
        require(success, "BEP40 transferFrom failed");
        
        // Verify balance change as additional safety check
        uint256 balanceAfter = baseToken.balanceOf(to);
        require(balanceAfter >= balanceBefore + amount, "Balance check failed");
    }

    function _safeBEP40Transfer(address to, uint256 amount) internal {
        require(amount > 0, "Zero amount");
        uint256 balanceBefore = baseToken.balanceOf(to);
        
        // BEP40 returns boolean
        bool success = baseToken.transfer(to, amount);
        require(success, "BEP40 transfer failed");
        
        // Verify balance change as additional safety check
        uint256 balanceAfter = baseToken.balanceOf(to);
        require(balanceAfter >= balanceBefore + amount, "Balance check failed");
    }

    function _safeBEP40Approve(address spender, uint256 amount) internal {
        // BEP40 returns boolean
        bool success = baseToken.approve(spender, amount);
        require(success, "BEP40 approve failed");
    }

    // ============ APPROVAL HELPERS ============
    function checkAndApproveUSDT() external whenNotPaused {
        uint256 currentAllowance = baseToken.allowance(msg.sender, address(this));
        
        // Only approve if current allowance is less than max
        if (currentAllowance < type(uint256).max) {
            _safeBEP40Approve(address(this), type(uint256).max);
        }
        
        emit USDTApprovedInfinite(msg.sender);
    }

    function approveForMarketCreation(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount zero");
        _safeBEP40Approve(address(this), amount);
        emit USDTCreationApproved(msg.sender, amount);
    }

    // Helper function to check allowance
    function getUSDTCurrentAllowance(address user) external view returns (uint256) {
        return baseToken.allowance(user, address(this));
    }

    // ============ MARKET CREATION ============
    function createMarket(
        string memory title,
        string memory description,
        string memory resolutionCriteria,
        uint64 endTime,
        address oracle,
        uint256 initialLiquidity
    ) external nonReentrant whenNotPaused returns (uint64) {
        require(initialized, "Contract not initialized");
        require(endTime > block.timestamp + minMarketDuration, "Invalid end time");
        require(initialLiquidity >= minInitialLiquidity, "Insufficient liquidity");
        require(oracle != address(0), "Invalid oracle");
        require(bytes(title).length > 0, "Invalid title");

        address creator = msg.sender;
        uint256 creationFee = marketCreationFee;
        uint256 discount = zentoToken.getMarketCreationDiscount(creator);
        if (discount > 0) {
            creationFee = (creationFee * (10000 - discount)) / 10000;
        }

        uint256 totalRequired = creationFee + initialLiquidity;
        
        // Check user's USDT balance and allowance first
        require(baseToken.balanceOf(creator) >= totalRequired, "Insufficient USDT balance");
        uint256 currentAllowance = baseToken.allowance(creator, address(this));
        require(currentAllowance >= totalRequired, "Insufficient USDT allowance");
        
        // Transfer tokens first
        _safeBEP40TransferFrom(creator, address(this), totalRequired);

        // Pay creation fee to admin
        if (creationFee > 0) {
            _safeBEP40Transfer(admin, creationFee);
        }

        uint64 id = nextId++;
        
        // Create market struct
        Market memory newMarket = Market({
            id: id,
            title: title,
            description: description,
            resolutionCriteria: resolutionCriteria,
            endTime: endTime,
            oracle: oracle,
            creator: creator,
            resolved: false,
            outcome: 0,
            totalYesShares: 0,
            totalNoShares: 0,
            participantCount: 0,
            creationTime: block.timestamp,
            nextPositionId: 1,
            lpClaimBalance: 0,
            resolutionTime: 0,
            tier: initialLiquidity >= minOptimaLiquidity ? MarketTier.OPTIMA : MarketTier.STANDARD,
            hasActiveDispute: false,
            ammPool: MarketPool({
                yesReserve: initialLiquidity / 2,
                noReserve: initialLiquidity / 2,
                totalLpTokens: initialLiquidity,
                virtualYes: initialLiquidity / 2,
                virtualNo: initialLiquidity / 2,
                globalYesAllocation: 0,
                globalNoAllocation: 0
            }),
            analytics: MarketAnalytics({
                totalVolume: initialLiquidity,
                totalTrades: 1,
                totalFees: 0,
                last24hVolume: initialLiquidity,
                last24hTimestamp: block.timestamp,
                uniqueTraderCount: 1,
                liquidityVolume: initialLiquidity
            }),
            dispute: Dispute({
                disputeId: 0,
                disputer: address(0),
                proposedOutcome: 0,
                stakeAmount: 0,
                disputeEndTime: 0,
                status: DisputeStatus.NONE
            })
        });

        markets[id] = newMarket;
        marketLpProviders[id][creator] = initialLiquidity;
        marketUniqueTraders[id][creator] = true;

        if (newMarket.tier == MarketTier.OPTIMA) {
            activeMarkets[id] = true;
        }

        emit MarketCreated(id, creator, newMarket.tier, initialLiquidity);
        return id;
    }

    // ============ TRADING ============
    function buyPosition(
        uint64 marketId,
        uint8 outcome,
        uint256 amount,
        uint256 maxPrice
    ) external nonReentrant whenNotPaused returns (uint64) {
        require(amount > 0, "Invalid amount");
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        require(!m.resolved, "Market resolved");
        require(block.timestamp < m.endTime, "Market ended");
        require(outcome == 1 || outcome == 2, "Invalid outcome");
        require(!m.hasActiveDispute, "Active dispute");

        uint256 currentPrice = calculateOutcomePrice(marketId, outcome);
        require(currentPrice <= maxPrice, "Price too high");

        // Check user's USDT balance and allowance first
        require(baseToken.balanceOf(msg.sender) >= amount, "Insufficient USDT balance");
        uint256 currentAllowance = baseToken.allowance(msg.sender, address(this));
        require(currentAllowance >= amount, "Insufficient USDT allowance");

        _safeBEP40TransferFrom(msg.sender, address(this), amount);

        uint256 feeRate = m.tier == MarketTier.OPTIMA && globalPoolMarketAllocations[marketId] > 0
            ? globalLpFeeRate : tradeFeeRate;

        uint256 discount = zentoToken.getTradingFeeDiscount(msg.sender);
        if (discount > 0) {
            feeRate = (feeRate * (10000 - discount)) / 10000;
        }

        uint256 fee = (amount * feeRate) / PRICE_PRECISION;
        uint256 afterFee = amount - fee;

        uint256 reserve = outcome == 1
            ? m.ammPool.yesReserve + m.ammPool.globalYesAllocation
            : m.ammPool.noReserve + m.ammPool.globalNoAllocation;

        uint256 vReserve = outcome == 1 ? m.ammPool.virtualYes : m.ammPool.virtualNo;
        uint256 tShares = outcome == 1 ? m.totalYesShares : m.totalNoShares;

        uint256 shares = reserve == 0
            ? afterFee
            : (afterFee * (tShares + vReserve)) / reserve;

        require(shares > 0, "Zero shares");

        if (outcome == 1) {
            uint256 totalYes = m.ammPool.yesReserve + m.ammPool.globalYesAllocation;
            if (m.ammPool.globalYesAllocation > 0 && totalYes > 0) {
                uint256 gs = (amount * m.ammPool.globalYesAllocation) / totalYes;
                m.ammPool.yesReserve += (amount - gs);
                m.ammPool.globalYesAllocation += gs;
                globalPool.pendingFees += (fee * globalLpShareRate) / PRICE_PRECISION;
            } else {
                m.ammPool.yesReserve += amount;
            }
            m.totalYesShares += shares;
        } else {
            uint256 totalNo = m.ammPool.noReserve + m.ammPool.globalNoAllocation;
            if (m.ammPool.globalNoAllocation > 0 && totalNo > 0) {
                uint256 gs = (amount * m.ammPool.globalNoAllocation) / totalNo;
                m.ammPool.noReserve += (amount - gs);
                m.ammPool.globalNoAllocation += gs;
                globalPool.pendingFees += (fee * globalLpShareRate) / PRICE_PRECISION;
            } else {
                m.ammPool.noReserve += amount;
            }
            m.totalNoShares += shares;
        }

        uint64 posId = uint64(m.nextPositionId++);
        
        // Create position
        marketPositions[marketId][posId] = Position({
            user: msg.sender,
            outcome: outcome,
            shares: shares,
            avgPrice: currentPrice,
            timestamp: block.timestamp
        });
        
        // Add to user positions
        userMarketPositions[marketId][msg.sender].push(posId);

        if (!marketUniqueTraders[marketId][msg.sender]) {
            marketUniqueTraders[marketId][msg.sender] = true;
            m.analytics.uniqueTraderCount++;
            m.participantCount++;
        }

        // Update analytics
        if (block.timestamp - m.analytics.last24hTimestamp > 86400) {
            m.analytics.last24hVolume = amount;
            m.analytics.last24hTimestamp = block.timestamp;
        } else {
            m.analytics.last24hVolume += amount;
        }

        m.analytics.totalVolume += amount;
        m.analytics.totalTrades++;
        m.analytics.totalFees += fee;

        emit PositionBought(marketId, msg.sender, outcome, shares, amount);
        return posId;
    }

    // ============ LIQUIDITY ============
    function addLiquidity(uint64 marketId, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        require(!m.resolved, "Market resolved");
        require(!m.hasActiveDispute, "Active dispute");

        // Check user's USDT balance and allowance first
        require(baseToken.balanceOf(msg.sender) >= amount, "Insufficient USDT balance");
        uint256 currentAllowance = baseToken.allowance(msg.sender, address(this));
        require(currentAllowance >= amount, "Insufficient USDT allowance");

        _safeBEP40TransferFrom(msg.sender, address(this), amount);

        uint256 totalRes = m.ammPool.yesReserve + m.ammPool.noReserve;
        require(totalRes > 0, "No initial liquidity");

        uint256 yesAdd = (amount * m.ammPool.yesReserve) / totalRes;
        uint256 noAdd = amount - yesAdd;
        require(yesAdd > 0 && noAdd > 0, "Invalid split");

        m.ammPool.yesReserve += yesAdd;
        m.ammPool.noReserve += noAdd;
        m.ammPool.virtualYes += yesAdd;
        m.ammPool.virtualNo += noAdd;

        uint256 lp = (amount * m.ammPool.totalLpTokens) / totalRes;
        uint256 boost = zentoToken.getLPBoost(msg.sender);
        lp = (lp * boost) / 10000;
        require(lp > 0, "Zero LP tokens");

        marketLpProviders[marketId][msg.sender] += lp;
        m.ammPool.totalLpTokens += lp;
        m.analytics.liquidityVolume += amount;

        if (m.tier == MarketTier.STANDARD && (totalRes + amount) >= minOptimaLiquidity) {
            m.tier = MarketTier.OPTIMA;
            activeMarkets[marketId] = true;
        }

        emit LiquidityAdded(marketId, msg.sender, amount, lp);
    }

    // ============ GLOBAL LP ============
    function depositGlobalLiquidity(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        
        // Check user's USDT balance and allowance first
        require(baseToken.balanceOf(msg.sender) >= amount, "Insufficient USDT balance");
        uint256 currentAllowance = baseToken.allowance(msg.sender, address(this));
        require(currentAllowance >= amount, "Insufficient USDT allowance");

        _safeBEP40TransferFrom(msg.sender, address(this), amount);

        uint256 avail = globalPool.totalDeposits - globalPool.totalAllocated + globalPool.pendingFees;
        uint256 lp = globalPool.totalLpTokens == 0
            ? amount
            : (amount * globalPool.totalLpTokens) / avail;

        uint256 boost = zentoToken.getLPBoost(msg.sender);
        lp = (lp * boost) / 10000;
        require(lp > 0, "Zero LP tokens");

        globalPoolLpProviders[msg.sender] += lp;
        globalPool.totalLpTokens += lp;
        globalPool.totalDeposits += amount;

        emit GlobalLiquidityDeposited(msg.sender, amount);
    }

    function withdrawGlobalLiquidity(uint256 lp) external nonReentrant whenNotPaused {
        require(globalPoolLpProviders[msg.sender] >= lp, "Insufficient balance");
        require(lp > 0, "Invalid amount");

        uint256 avail = globalPool.totalDeposits - globalPool.totalAllocated + globalPool.pendingFees;
        require(avail > 0, "No available liquidity");

        uint256 amt = (lp * avail) / globalPool.totalLpTokens;
        require(amt > 0, "Zero withdraw amount");

        globalPoolLpProviders[msg.sender] -= lp;
        globalPool.totalLpTokens -= lp;

        if (amt <= globalPool.totalDeposits - globalPool.totalAllocated) {
            globalPool.totalDeposits -= amt;
        } else {
            uint256 fd = globalPool.totalDeposits - globalPool.totalAllocated;
            globalPool.totalDeposits -= fd;
            globalPool.pendingFees -= (amt - fd);
        }

        _safeBEP40Transfer(msg.sender, amt);
        emit GlobalLiquidityWithdrawn(msg.sender, amt);
    }

    // ============ ADMIN RE-ALLOCATION ============
    function reallocateGlobalLiquidity() external nonReentrant whenNotPaused {
        require(msg.sender == admin, "Only admin");
        uint256 availableLiquidity = globalPool.totalDeposits - globalPool.totalAllocated;
        if (availableLiquidity < MIN_LIQUIDITY) return;

        uint64[] memory sortedMarkets = getOptimaMarkets();
        if (sortedMarkets.length == 0) return;

        uint256 minAllocation = MIN_LIQUIDITY / 10;
        uint256 liquidityPerMarket = availableLiquidity / sortedMarkets.length;
        if (liquidityPerMarket < minAllocation) return;

        for (uint256 i = 0; i < sortedMarkets.length && i < 10; i++) {
            uint64 marketId = sortedMarkets[i];
            Market storage market = markets[marketId];
            if (
                market.resolved || block.timestamp >= market.endTime ||
                market.hasActiveDispute || block.timestamp <= market.resolutionTime + DISPUTE_WINDOW
            ) continue;

            uint256 currentAllocation = globalPoolMarketAllocations[marketId];
            uint256 targetAllocation = liquidityPerMarket;

            if (targetAllocation > currentAllocation) {
                uint256 additionalAllocation = min(targetAllocation - currentAllocation, availableLiquidity);
                uint256 totalReserve = market.ammPool.yesReserve + market.ammPool.noReserve;
                uint256 yesAlloc = totalReserve > 0
                    ? (additionalAllocation * market.ammPool.yesReserve) / totalReserve
                    : additionalAllocation / 2;
                uint256 noAlloc = additionalAllocation - yesAlloc;

                market.ammPool.globalYesAllocation += yesAlloc;
                market.ammPool.globalNoAllocation += noAlloc;
                globalPoolMarketAllocations[marketId] += additionalAllocation;
                globalPool.totalAllocated += additionalAllocation;
                availableLiquidity -= additionalAllocation;

                emit GlobalLiquidityAllocated(marketId, additionalAllocation);
            }
        }
    }

    // ============ RESOLUTION & CLAIMS ============
    function resolveMarket(uint64 marketId, uint8 outcome) external nonReentrant whenNotPaused {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        require(!m.resolved, "Already resolved");
        require(!m.hasActiveDispute, "Active dispute");
        require(outcome == 1 || outcome == 2, "Invalid outcome");
        require(msg.sender == admin || msg.sender == m.oracle || msg.sender == m.creator, "Not authorized");
        require(block.timestamp >= m.endTime, "Market not ended");

        // Handle global liquidity reclamation
        uint256 allocation = globalPoolMarketAllocations[marketId];
        if (allocation > 0) {
            uint256 returned = m.ammPool.globalYesAllocation + m.ammPool.globalNoAllocation;
            globalPool.totalAllocated -= allocation;
            globalPoolMarketAllocations[marketId] = 0;
            m.ammPool.globalYesAllocation = 0;
            m.ammPool.globalNoAllocation = 0;
            if (returned > allocation) {
                globalPool.pendingFees += (returned - allocation);
            }
            emit GlobalLiquidityReclaimed(marketId, returned);
        }

        // Calculate fees and payouts
        uint256 wr = outcome == 1 ? m.ammPool.yesReserve : m.ammPool.noReserve;
        uint256 lr = outcome == 1 ? m.ammPool.noReserve : m.ammPool.yesReserve;
        uint256 total = wr + lr;
        uint256 pf = (total * platformFeeRate) / 10000;
        uint256 cf = (m.analytics.totalFees * creatorFeeRate) / PRICE_PRECISION;
        uint256 tf = pf + cf;
        uint256 fl = min(lr, tf);
        uint256 fw = tf - fl;
        uint256 lpRet = m.ammPool.totalLpTokens;
        uint256 maxLp = (lr - fl) + (wr - fw);
        lpRet = min(lpRet, maxLp);

        // Update reserves
        if (outcome == 1) {
            m.ammPool.yesReserve -= fw;
            m.ammPool.noReserve -= fl;
        } else {
            m.ammPool.noReserve -= fw;
            m.ammPool.yesReserve -= fl;
        }

        // Pay fees
        if (pf > 0) _safeBEP40Transfer(admin, pf);
        if (cf > 0) _safeBEP40Transfer(m.creator, cf);

        m.lpClaimBalance = lpRet;
        m.resolved = true;
        m.outcome = outcome;
        m.resolutionTime = block.timestamp;

        emit MarketResolved(marketId, outcome, msg.sender);
    }

    function claimWinnings(uint64 marketId, uint64 posId) external nonReentrant whenNotPaused {
        Market storage m = markets[marketId];
        require(m.resolved, "Market not resolved");
        require(!m.hasActiveDispute, "Active dispute");
        require(block.timestamp > m.resolutionTime + DISPUTE_WINDOW, "Dispute window active");
        
        Position storage p = marketPositions[marketId][posId];
        require(p.user == msg.sender, "Not owner");
        require(p.shares > 0, "Already claimed");

        uint256 payout = 0;
        if (p.outcome == m.outcome) {
            uint256 ts = m.outcome == 1 ? m.totalYesShares : m.totalNoShares;
            if (ts > 0) {
                payout = (p.shares * (m.ammPool.yesReserve + m.ammPool.noReserve)) / ts;
                if (payout > 0) {
                    _safeBEP40Transfer(msg.sender, payout);
                }
            }
        }

        p.shares = 0; // Mark as claimed
        emit WinningsClaimed(marketId, msg.sender, posId, payout);
    }

    function claimLpPrincipal(uint64 marketId) external nonReentrant whenNotPaused {
        Market storage m = markets[marketId];
        require(m.resolved, "Market not resolved");
        require(!m.hasActiveDispute, "Active dispute");
        require(block.timestamp > m.resolutionTime + DISPUTE_WINDOW, "Dispute window active");
        
        uint256 lp = marketLpProviders[marketId][msg.sender];
        require(lp > 0, "No LP tokens");

        uint256 amt = (lp * m.lpClaimBalance) / m.ammPool.totalLpTokens;
        require(amt > 0, "Nothing to claim");

        marketLpProviders[marketId][msg.sender] = 0;
        m.lpClaimBalance -= amt;
        _safeBEP40Transfer(msg.sender, amt);

        emit LpPrincipalClaimed(marketId, msg.sender, amt);
    }

    // ============ DISPUTES ============
    function initiateDispute(uint64 marketId, uint8 proposedOutcome, uint256 stakeAmount) external nonReentrant whenNotPaused {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        require(m.resolved, "Market not resolved");
        require(!m.hasActiveDispute, "Active dispute");
        require(proposedOutcome == 1 || proposedOutcome == 2, "Invalid outcome");
        require(proposedOutcome != m.outcome, "Same as current outcome");
        require(stakeAmount >= minDisputeStake, "Insufficient stake");
        require(block.timestamp <= m.resolutionTime + DISPUTE_WINDOW, "Dispute window expired");

        address disputer = msg.sender;
        require(userDisputes[disputer].length < MAX_DISPUTES_PER_USER, "Too many disputes");
        require(block.timestamp >= lastDisputeTime[disputer] + DISPUTE_COOLDOWN, "Dispute cooldown active");
        require(zentoToken.lockForDispute(disputer, stakeAmount), "Lock failed");

        uint64 disputeId = nextDisputeId++;
        m.dispute = Dispute(disputeId, disputer, proposedOutcome, stakeAmount, block.timestamp + DISPUTE_WINDOW, DisputeStatus.ACTIVE);
        m.hasActiveDispute = true;
        userDisputes[disputer].push(disputeId);
        lastDisputeTime[disputer] = block.timestamp;

        emit DisputeInitiated(marketId, disputeId, disputer);
    }

    function finalizeDispute(uint64 marketId, bool uphold) external onlyOwner nonReentrant whenNotPaused {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        require(m.hasActiveDispute, "No active dispute");
        Dispute storage dispute = m.dispute;
        require(dispute.status == DisputeStatus.ACTIVE, "Dispute not active");

        dispute.status = uphold ? DisputeStatus.RESOLVED_UPHELD : DisputeStatus.RESOLVED_OVERTURNED;

        if (uphold) {
            m.outcome = dispute.proposedOutcome;
            zentoToken.unlockFromDispute(dispute.disputer, dispute.stakeAmount);
            if (rewardPoolBalance >= disputeReward) {
                rewardPoolBalance -= disputeReward;
                zentoToken.transfer(dispute.disputer, disputeReward);
            }
        } else {
            zentoToken.slashTokens(dispute.disputer, dispute.stakeAmount);
        }

        m.hasActiveDispute = false;
        emit DisputeResolved(marketId, dispute.disputeId, dispute.status);
    }

    function cancelDispute(uint64 marketId) external onlyOwner nonReentrant whenNotPaused {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        require(m.hasActiveDispute, "No active dispute");
        Dispute storage dispute = m.dispute;
        dispute.status = DisputeStatus.NONE;
        zentoToken.unlockFromDispute(dispute.disputer, dispute.stakeAmount);
        m.hasActiveDispute = false;
        emit DisputeCancelled(marketId, dispute.disputeId, DisputeStatus.NONE);
    }

    // ============ VIEW FUNCTIONS ============
    function calculateOutcomePrice(uint64 marketId, uint8 outcome) public view returns (uint256) {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");

        uint256 yr = m.ammPool.yesReserve + m.ammPool.globalYesAllocation;
        uint256 nr = m.ammPool.noReserve + m.ammPool.globalNoAllocation;
        uint256 total = yr + nr;
        if (total == 0) return PRICE_PRECISION / 2;

        uint256 or = outcome == 1 ? yr : nr;
        uint256 price = (or * PRICE_PRECISION) / total;

        if (price < 50) return 50;
        if (price > 9950) return 9950;
        return price;
    }

    function getMarketDetails(uint64 marketId) external view returns (
        uint64 id,
        string memory title,
        string memory description,
        uint64 endTime,
        bool resolved,
        uint8 outcome,
        MarketTier tier,
        uint256 tvl,
        address creator,
        address oracle
    ) {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        tvl = m.ammPool.yesReserve + m.ammPool.noReserve + m.ammPool.globalYesAllocation + m.ammPool.globalNoAllocation;
        return (m.id, m.title, m.description, m.endTime, m.resolved, m.outcome, m.tier, tvl, m.creator, m.oracle);
    }

    function getMarketPoolInfo(uint64 marketId) external view returns (
        uint256 yesReserve,
        uint256 noReserve,
        uint256 totalLpTokens,
        uint256 totalYesShares,
        uint256 totalNoShares,
        uint256 globalYesAllocation,
        uint256 globalNoAllocation
    ) {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        return (
            m.ammPool.yesReserve,
            m.ammPool.noReserve,
            m.ammPool.totalLpTokens,
            m.totalYesShares,
            m.totalNoShares,
            m.ammPool.globalYesAllocation,
            m.ammPool.globalNoAllocation
        );
    }

    function getMarketAnalytics(uint64 marketId) external view returns (
        uint256 totalVolume,
        uint256 totalTrades,
        uint256 totalFees,
        uint256 last24hVolume,
        uint256 uniqueTraderCount,
        uint256 liquidityVolume
    ) {
        Market storage m = markets[marketId];
        require(m.id != 0, "Market not found");
        return (
            m.analytics.totalVolume,
            m.analytics.totalTrades,
            m.analytics.totalFees,
            m.analytics.last24hVolume,
            m.analytics.uniqueTraderCount,
            m.analytics.liquidityVolume
        );
    }

    function getAllMarketIds() external view returns (uint64[] memory) {
        uint64[] memory result = new uint64[](nextId - 1);
        for (uint64 i = 1; i < nextId; i++) {
            if (markets[i].id != 0) {
                result[i-1] = i;
            }
        }
        return result;
    }

    function getUserPositions(uint64 marketId, address user) external view returns (uint64[] memory) {
        return userMarketPositions[marketId][user];
    }

    function getPosition(uint64 marketId, uint64 posId) external view returns (
        address user,
        uint8 outcome,
        uint256 shares,
        uint256 avgPrice,
        uint256 timestamp
    ) {
        Position storage p = marketPositions[marketId][posId];
        require(p.user != address(0), "Position not found");
        return (p.user, p.outcome, p.shares, p.avgPrice, p.timestamp);
    }

    function getGlobalPoolStats() external view returns (
        uint256 totalDeposits,
        uint256 totalAllocated,
        uint256 availableLiquidity,
        uint256 totalLpTokens,
        uint256 pendingFees
    ) {
        availableLiquidity = globalPool.totalDeposits - globalPool.totalAllocated;
        return (globalPool.totalDeposits, globalPool.totalAllocated, availableLiquidity, globalPool.totalLpTokens, globalPool.pendingFees);
    }

    function getUserGlobalLpBalance(address user) external view returns (uint256) {
        return globalPoolLpProviders[user];
    }

    function getMarketLpBalance(uint64 marketId, address provider) external view returns (uint256) {
        return marketLpProviders[marketId][provider];
    }

    function marketExists(uint64 marketId) public view returns (bool) {
        return markets[marketId].id != 0;
    }

    function getOptimaMarkets() public view returns (uint64[] memory) {
        uint256 count = 0;
        for (uint64 i = 1; i < nextId; i++) {
            Market storage m = markets[i];
            if (m.tier == MarketTier.OPTIMA && !m.resolved && block.timestamp > m.resolutionTime + DISPUTE_WINDOW) {
                count++;
            }
        }
        
        uint64[] memory optimaMarkets = new uint64[](count);
        uint256 idx = 0;
        for (uint64 i = 1; i < nextId; i++) {
            Market storage m = markets[i];
            if (m.tier == MarketTier.OPTIMA && !m.resolved && block.timestamp > m.resolutionTime + DISPUTE_WINDOW) {
                optimaMarkets[idx++] = i;
            }
        }
        
        // Sort by volume (simplified)
        for (uint256 i = 1; i < optimaMarkets.length; i++) {
            uint64 key = optimaMarkets[i];
            uint256 keyVolume = markets[key].analytics.last24hVolume;
            uint256 j = i;
            while (j > 0 && markets[optimaMarkets[j - 1]].analytics.last24hVolume < keyVolume) {
                optimaMarkets[j] = optimaMarkets[j - 1];
                j--;
            }
            optimaMarkets[j] = key;
        }
        return optimaMarkets;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}