// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IZentoToken.sol";

contract ZentoTokenSeedify is ERC20, Ownable, ReentrancyGuard, IZentoToken {
    uint256 public totalSupplyCap;
    uint256 public publicSaleAllocation;

    uint8 public constant TIER_NONE = 0;
    uint8 public constant TIER_BRONZE = 1;
    uint8 public constant TIER_SILVER = 2;
    uint8 public constant TIER_GOLD = 3;
    uint8 public constant TIER_PLATINUM = 4;

    uint256 public BRONZE_THRESHOLD = 1_000 * 10 ** 18;
    uint256 public SILVER_THRESHOLD = 10_000 * 10 ** 18;
    uint256 public GOLD_THRESHOLD = 50_000 * 10 ** 18;
    uint256 public PLATINUM_THRESHOLD = 250_000 * 10 ** 18;

    struct StakeInfo {
        uint256 amount;
        uint256 lockEndTime;
        uint8 tier;
        uint256 rewardDebt;
        uint256 lastRewardClaim;
    }

    struct PublicSale {
        bool active;
        uint256 tokensAvailable;
        uint256 priceInBaseToken;
        uint256 tokensSold;
        uint256 raised;
    }

    struct RewardConfig {
        uint256 rewardsPerSecond;
        uint256 totalStaked;
        uint256 accRewardPerShare;
        uint256 lastRewardUpdate;
        uint256 rewardPoolBalance;
        bool rewardsActive;
    }

    mapping(uint8 => uint256) public tierMultipliers;
    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public lockedForDispute;
    mapping(address => uint256) public pendingRewards;

    PublicSale public publicSale;
    RewardConfig public rewardConfig;
    IERC20 public baseToken;
    address public platformContract;
    address public rewardPoolAddress;

    bool public minted;
    bool public seedifyLaunched;
    bool public paused;
    string public logoURI;
    string public website;
    string public telegram;
    string public twitter;

    // New events for configuration changes
    event StakingThresholdsUpdated(
        uint256 bronze,
        uint256 silver,
        uint256 gold,
        uint256 platinum
    );
    event BaseTokenUpdated(address baseToken);
    event PlatformContractUpdated(address platformContract);
    event Paused(address admin);
    event Unpaused(address admin);

    modifier onlyPlatform() {
        require(msg.sender == platformContract, "Only platform");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor() ERC20("Zento Token", "ZENT") Ownable(msg.sender) {
        minted = false;
        seedifyLaunched = false;
        paused = false;

        tierMultipliers[TIER_BRONZE] = 10000;
        tierMultipliers[TIER_SILVER] = 12500;
        tierMultipliers[TIER_GOLD] = 15000;
        tierMultipliers[TIER_PLATINUM] = 20000;

        rewardConfig.lastRewardUpdate = block.timestamp;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

    function mintInitialSupply(
        uint256 _totalSupply,
        uint256 _publicSalePercent,
        address deployerWallet,
        string memory _logoURI
    ) external onlyOwner whenNotPaused {
        require(!minted, "Already minted");
        require(_totalSupply > 0, "Invalid supply");
        require(_publicSalePercent <= 100, "Invalid percentage");
        require(deployerWallet != address(0), "Invalid wallet");

        totalSupplyCap = _totalSupply;
        publicSaleAllocation = (_totalSupply * _publicSalePercent) / 100;
        logoURI = _logoURI;

        _mint(deployerWallet, _totalSupply);

        minted = true;
    }

    function updateMetadata(
        string memory _logoURI,
        string memory _website,
        string memory _telegram,
        string memory _twitter
    ) external onlyOwner whenNotPaused {
        logoURI = _logoURI;
        website = _website;
        telegram = _telegram;
        twitter = _twitter;
    }

    function setPlatformContract(
        address _platform
    ) external onlyOwner whenNotPaused {
        require(_platform != address(0), "Invalid platform");
        platformContract = _platform;
        emit PlatformContractUpdated(_platform);
    }

    function setBaseToken(address _baseToken) external onlyOwner whenNotPaused {
        require(_baseToken != address(0), "Invalid token");
        baseToken = IERC20(_baseToken);
        emit BaseTokenUpdated(_baseToken);
    }

    function markSeedifyLaunched() external onlyOwner whenNotPaused {
        seedifyLaunched = true;
    }

    function updateStakingThresholds(
        uint256 _bronze,
        uint256 _silver,
        uint256 _gold,
        uint256 _platinum
    ) external onlyOwner whenNotPaused {
        require(
            _bronze < _silver && _silver < _gold && _gold < _platinum,
            "Invalid thresholds"
        );
        BRONZE_THRESHOLD = _bronze;
        SILVER_THRESHOLD = _silver;
        GOLD_THRESHOLD = _gold;
        PLATINUM_THRESHOLD = _platinum;
        emit StakingThresholdsUpdated(_bronze, _silver, _gold, _platinum);
    }

    function fundRewardPool(uint256 amount) external onlyOwner whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, address(this), amount);
        rewardConfig.rewardPoolBalance += amount;

        emit RewardPoolFunded(amount);
    }

    function configureRewards(
        uint256 _rewardsPerSecond
    ) external onlyOwner whenNotPaused {
        require(_rewardsPerSecond > 0, "Invalid rate");
        require(
            rewardConfig.rewardPoolBalance >= _rewardsPerSecond * 30 days,
            "Insufficient pool for 30 days"
        );

        _updateRewards();

        rewardConfig.rewardsPerSecond = _rewardsPerSecond;

        emit RewardsConfigured(
            _rewardsPerSecond,
            rewardConfig.rewardPoolBalance
        );
    }

    function setRewardsActive(bool active) external onlyOwner whenNotPaused {
        if (active) {
            require(rewardConfig.rewardPoolBalance > 0, "No rewards in pool");
            require(rewardConfig.rewardsPerSecond > 0, "Rewards rate not set");
        }

        _updateRewards();
        rewardConfig.rewardsActive = active;

        emit RewardsActivated(active);
    }

    function updateTierMultiplier(
        uint8 tier,
        uint256 multiplier
    ) external onlyOwner whenNotPaused {
        require(tier >= TIER_BRONZE && tier <= TIER_PLATINUM, "Invalid tier");
        require(
            multiplier >= 10000 && multiplier <= 50000,
            "Invalid multiplier"
        );

        tierMultipliers[tier] = multiplier;

        emit TierMultiplierUpdated(tier, multiplier);
    }

    function _updateRewards() internal {
        if (!rewardConfig.rewardsActive || rewardConfig.totalStaked == 0) {
            rewardConfig.lastRewardUpdate = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - rewardConfig.lastRewardUpdate;
        if (timeElapsed == 0) return;

        uint256 rewards = timeElapsed * rewardConfig.rewardsPerSecond;

        if (rewards > rewardConfig.rewardPoolBalance) {
            rewards = rewardConfig.rewardPoolBalance;
            rewardConfig.rewardsActive = false;
        }

        // Use higher precision to reduce truncation errors
        rewardConfig.accRewardPerShare +=
            (rewards * 1e36) / rewardConfig.totalStaked;
        rewardConfig.rewardPoolBalance -= rewards;
        rewardConfig.lastRewardUpdate = block.timestamp;
    }

    function calculatePendingRewards(
        address account
    ) public view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[account];
        if (stakeInfo.amount == 0) return pendingRewards[account];

        uint256 accRewardPerShare = rewardConfig.accRewardPerShare;

        if (rewardConfig.rewardsActive && rewardConfig.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp -
                rewardConfig.lastRewardUpdate;
            uint256 rewards = timeElapsed * rewardConfig.rewardsPerSecond;

            if (rewards > rewardConfig.rewardPoolBalance) {
                rewards = rewardConfig.rewardPoolBalance;
            }

            accRewardPerShare += (rewards * 1e36) / rewardConfig.totalStaked;
        }

        uint256 baseReward = (stakeInfo.amount * accRewardPerShare) / 1e36;
        uint256 effectiveReward = (baseReward *
            tierMultipliers[stakeInfo.tier]) / 10000;

        uint256 totalRewards = effectiveReward > stakeInfo.rewardDebt
            ? effectiveReward - stakeInfo.rewardDebt
            : 0;

        return totalRewards + pendingRewards[account];
    }

    function calculateTierAPY(uint8 tier) public view returns (uint256) {
        if (rewardConfig.totalStaked == 0 || !rewardConfig.rewardsActive)
            return 0;

        uint256 annualRewards = rewardConfig.rewardsPerSecond * 365 days;
        uint256 baseAPY = (annualRewards * 10000) / rewardConfig.totalStaked;
        return (baseAPY * tierMultipliers[tier]) / 10000;
    }

    function getUserAPY(address account) external view returns (uint256) {
        uint8 tier = stakes[account].tier;
        if (tier == TIER_NONE) return 0;
        return calculateTierAPY(tier);
    }

    function stake(
        uint256 amount,
        uint256 lockDuration
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(lockDuration >= 30 days, "Min 30 days lock");
        require(lockDuration <= 1460 days, "Max 4 years lock");

        _updateRewards();

        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (stakeInfo.amount > 0) {
            uint256 pending = calculatePendingRewards(msg.sender);
            if (pending > 0) {
                pendingRewards[msg.sender] += pending;
            }
        }

        _transfer(msg.sender, address(this), amount);

        rewardConfig.totalStaked += amount;
        stakeInfo.amount += amount;
        stakeInfo.lockEndTime = block.timestamp + lockDuration;
        stakeInfo.tier = _calculateTier(stakeInfo.amount);

        stakeInfo.rewardDebt =
            (stakeInfo.amount *
                rewardConfig.accRewardPerShare *
                tierMultipliers[stakeInfo.tier]) / (1e36 * 10000);
        stakeInfo.lastRewardClaim = block.timestamp;

        emit Staked(msg.sender, amount, lockDuration, stakeInfo.tier);
    }

    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount >= amount, "Insufficient staked");
        require(block.timestamp >= stakeInfo.lockEndTime, "Still locked");
        require(lockedForDispute[msg.sender] == 0, "Tokens locked in dispute");

        _updateRewards();

        uint256 pending = calculatePendingRewards(msg.sender);
        if (pending > 0) {
            pendingRewards[msg.sender] += pending;
        }

        rewardConfig.totalStaked -= amount;
        stakeInfo.amount -= amount;
        stakeInfo.tier = _calculateTier(stakeInfo.amount);

        if (stakeInfo.amount > 0) {
            stakeInfo.rewardDebt =
                (stakeInfo.amount *
                    rewardConfig.accRewardPerShare *
                    tierMultipliers[stakeInfo.tier]) / (1e36 * 10000);
        } else {
            stakeInfo.rewardDebt = 0;
        }

        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant whenNotPaused {
        _updateRewards();

        uint256 pending = calculatePendingRewards(msg.sender);
        require(pending > 0, "No rewards to claim");

        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (stakeInfo.amount > 0) {
            stakeInfo.rewardDebt =
                (stakeInfo.amount *
                    rewardConfig.accRewardPerShare *
                    tierMultipliers[stakeInfo.tier]) / (1e36 * 10000);
        }

        pendingRewards[msg.sender] = 0;
        stakeInfo.lastRewardClaim = block.timestamp;

        _transfer(address(this), msg.sender, pending);

        emit RewardsClaimed(msg.sender, pending);
    }

    function compoundRewards() external nonReentrant whenNotPaused {
        _updateRewards();

        uint256 pending = calculatePendingRewards(msg.sender);
        require(pending > 0, "No rewards to compound");

        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount > 0, "No active stake");

        rewardConfig.totalStaked += pending;
        stakeInfo.amount += pending;
        stakeInfo.tier = _calculateTier(stakeInfo.amount);

        pendingRewards[msg.sender] = 0;
        stakeInfo.rewardDebt =
            (stakeInfo.amount *
                rewardConfig.accRewardPerShare *
                tierMultipliers[stakeInfo.tier]) / (1e36 * 10000);
        stakeInfo.lastRewardClaim = block.timestamp;

        emit Staked(
            msg.sender,
            pending,
            stakeInfo.lockEndTime - block.timestamp,
            stakeInfo.tier
        );
        emit RewardsClaimed(msg.sender, pending);
    }

    function _calculateTier(uint256 amount) internal view returns (uint8) {
        if (amount >= PLATINUM_THRESHOLD) return TIER_PLATINUM;
        if (amount >= GOLD_THRESHOLD) return TIER_GOLD;
        if (amount >= SILVER_THRESHOLD) return TIER_SILVER;
        if (amount >= BRONZE_THRESHOLD) return TIER_BRONZE;
        return TIER_NONE;
    }

    function initializePublicSale(
        uint256 saleAmount,
        uint256 priceInBaseToken
    ) external onlyOwner whenNotPaused {
        require(minted, "Tokens not minted");
        require(!publicSale.active, "Sale already active");
        require(saleAmount <= balanceOf(msg.sender), "Insufficient balance");
        require(priceInBaseToken > 0, "Invalid price");
        require(priceInBaseToken >= 1e9, "Price too low"); // Ensure reasonable precision
        require(address(baseToken) != address(0), "Base token not set");

        _transfer(msg.sender, address(this), saleAmount);

        publicSale = PublicSale({
            active: true,
            tokensAvailable: saleAmount,
            priceInBaseToken: priceInBaseToken,
            tokensSold: 0,
            raised: 0
        });

        emit PublicSaleStarted(saleAmount, priceInBaseToken);
    }

    function buyTokensInSale(
        uint256 baseTokenAmount
    ) external nonReentrant whenNotPaused {
        require(publicSale.active, "Sale not active");
        require(baseTokenAmount > 0, "Invalid amount");

        uint256 tokensToReceive = (baseTokenAmount * 1e36) /
            publicSale.priceInBaseToken;
        require(tokensToReceive > 0, "Tokens too small");
        require(
            tokensToReceive <= publicSale.tokensAvailable,
            "Insufficient tokens"
        );

        baseToken.transferFrom(msg.sender, owner(), baseTokenAmount);
        _transfer(address(this), msg.sender, tokensToReceive);

        publicSale.tokensAvailable -= tokensToReceive;
        publicSale.tokensSold += tokensToReceive;
        publicSale.raised += baseTokenAmount;

        emit TokensPurchased(msg.sender, baseTokenAmount, tokensToReceive);
    }

    function endPublicSale() external onlyOwner whenNotPaused {
        require(publicSale.active, "Sale not active");

        publicSale.active = false;

        if (publicSale.tokensAvailable > 0) {
            _transfer(address(this), owner(), publicSale.tokensAvailable);
        }

        emit PublicSaleEnded(publicSale.tokensSold);
    }

    function isSaleActive() external view returns (bool) {
        return publicSale.active;
    }

    function lockForDispute(
        address account,
        uint256 amount
    ) external onlyPlatform whenNotPaused returns (bool) {
        require(stakes[account].amount >= amount, "Insufficient staked");
        lockedForDispute[account] += amount;
        emit TokensLocked(account, amount);
        return true;
    }

    function unlockFromDispute(
        address account,
        uint256 amount
    ) external onlyPlatform whenNotPaused returns (bool) {
        require(lockedForDispute[account] >= amount, "Nothing locked");
        lockedForDispute[account] -= amount;
        emit TokensUnlocked(account, amount);
        return true;
    }

    function slashTokens(
        address account,
        uint256 amount
    ) external onlyPlatform whenNotPaused returns (bool) {
        require(lockedForDispute[account] >= amount, "Insufficient locked");

        lockedForDispute[account] -= amount;
        stakes[account].amount -= amount;
        rewardConfig.totalStaked -= amount;
        stakes[account].tier = _calculateTier(stakes[account].amount);

        _burn(address(this), amount);

        emit TokensSlashed(account, amount);
        return true;
    }

    function getTradingFeeDiscount(
        address account
    ) external view returns (uint256) {
        uint8 tier = stakes[account].tier;
        if (tier == TIER_PLATINUM) return 5000;
        if (tier == TIER_GOLD) return 3000;
        if (tier == TIER_SILVER) return 2000;
        if (tier == TIER_BRONZE) return 1000;
        return 0;
    }

    function getMarketCreationDiscount(
        address account
    ) external view returns (uint256) {
        uint8 tier = stakes[account].tier;
        if (tier == TIER_PLATINUM) return 7000;
        if (tier == TIER_GOLD) return 5000;
        if (tier == TIER_SILVER) return 3000;
        if (tier == TIER_BRONZE) return 1500;
        return 0;
    }

    function getLPBoost(address account) external view returns (uint256) {
        uint8 tier = stakes[account].tier;
        if (tier == TIER_PLATINUM) return 25000;
        if (tier == TIER_GOLD) return 20000;
        if (tier == TIER_SILVER) return 15000;
        if (tier == TIER_BRONZE) return 12000;
        return 10000;
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return stakes[account].amount;
    }

    function getStakingTier(address account) external view returns (uint8) {
        return stakes[account].tier;
    }

    function getLockEndTime(address account) external view returns (uint256) {
        return stakes[account].lockEndTime;
    }

    function getAvailableToUnstake(
        address account
    ) public view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[account];
        if (block.timestamp < stakeInfo.lockEndTime) return 0;
        if (lockedForDispute[account] > 0) return 0;
        return stakeInfo.amount;
    }

    function getPublicSaleInfo()
        external
        view
        returns (
            bool active,
            uint256 tokensAvailable,
            uint256 priceInBaseToken,
            uint256 tokensSold,
            uint256 raised
        )
    {
        return (
            publicSale.active,
            publicSale.tokensAvailable,
            publicSale.priceInBaseToken,
            publicSale.tokensSold,
            publicSale.raised
        );
    }

    function getTokenInfo()
        external
        view
        returns (
            string memory _name,
            string memory _symbol,
            uint256 _totalSupply,
            uint256 _totalSupplyCap,
            string memory _logoURI,
            string memory _website,
            bool _minted,
            bool _seedifyLaunched
        )
    {
        return (
            name(),
            symbol(),
            totalSupply(),
            totalSupplyCap,
            logoURI,
            website,
            minted,
            seedifyLaunched
        );
    }

    function getStakingInfo(
        address account
    )
        external
        view
        returns (
            uint256 stakedAmount,
            uint8 tier,
            uint256 lockEndTime,
            uint256 pendingRewardsAmount,
            uint256 lastClaim,
            uint256 currentAPY,
            bool canUnstake
        )
    {
        StakeInfo memory stakeInfo = stakes[account];
        return (
            stakeInfo.amount,
            stakeInfo.tier,
            stakeInfo.lockEndTime,
            calculatePendingRewards(account),
            stakeInfo.lastRewardClaim,
            stakeInfo.tier > 0 ? calculateTierAPY(stakeInfo.tier) : 0,
            getAvailableToUnstake(account) > 0
        );
    }

    function getRewardPoolInfo()
        external
        view
        returns (
            uint256 poolBalance,
            uint256 rewardsPerSecond,
            uint256 totalStaked,
            bool active,
            uint256 estimatedDaysRemaining
        )
    {
        uint256 daysRemaining = 0;
        if (rewardConfig.rewardsActive && rewardConfig.rewardsPerSecond > 0) {
            uint256 secondsRemaining = rewardConfig.rewardPoolBalance /
                rewardConfig.rewardsPerSecond;
            daysRemaining = secondsRemaining / 1 days;
        }

        return (
            rewardConfig.rewardPoolBalance,
            rewardConfig.rewardsPerSecond,
            rewardConfig.totalStaked,
            rewardConfig.rewardsActive,
            daysRemaining
        );
    }

    function getAllTierAPYs()
        external
        view
        returns (
            uint256 bronzeAPY,
            uint256 silverAPY,
            uint256 goldAPY,
            uint256 platinumAPY
        )
    {
        return (
            calculateTierAPY(TIER_BRONZE),
            calculateTierAPY(TIER_SILVER),
            calculateTierAPY(TIER_GOLD),
            calculateTierAPY(TIER_PLATINUM)
        );
    }
}
