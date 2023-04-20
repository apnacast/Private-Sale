// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface BEP20 {
    function totalSupply() external view returns (uint256 theTotalSupply);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transfer(
        address _to,
        uint256 _value
    ) external returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function approve(
        address _spender,
        uint256 _value
    ) external returns (bool success);

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
}

contract ApnaPrivateSale {

    struct PrivateSale {
        uint256 price;
        uint256 supply;
        uint256 clif;
        uint256 vestingPeriod;
        uint256 releaseDays;
        uint256 startTime;
        uint256 endTime;
        bool onGoing;
    }

    struct ClaimRemainingToken {
        uint256 claimAmout;
        uint256 claimAt;
        uint256 vestingPeriod;
        uint256 releaseDays;
        bool transfered;
    }

    struct RewardsAccordingSpend{
        uint256 minSpend;
        uint256 maxSpend;
        uint256 purchaseBonus;
        uint256 tge;
    }

    uint256 privateSalePlanId;
    uint256 rewardsPlanId;
    address public owner;
    address private constant TOKENADDRESS =
        0xd9145CCE52D386f254917e481eB44e9943F39138; //Mainnet Token
    uint256 bonusPercent;
    uint256 private priceOfBNB;

    mapping(address => mapping(uint256 => uint256)) userReleaseTokens;
    mapping(address => bool) isEligibleForRef;
    mapping(address => mapping(uint256 => uint256)) public userId;
    mapping(uint256 => PrivateSale) public privateSale;
    mapping(uint256 => RewardsAccordingSpend) public rewardsAccordingSpend;
    mapping(address => mapping(uint => ClaimRemainingToken))
        public userClaimableTokenDetails;
    mapping(address => mapping(address => bool)) refAddress;
    mapping(address => uint256) public claimableTokens;
    mapping(uint256 => uint256) public soldToken;
    mapping(address => uint256) public lockToken;
    mapping(address => mapping(uint256 => uint256)) public releaseTime;

    event Received(address, uint256);
    event TokensBought(address, uint256);
    event OwnershipTransferred(address);
    event SetEndTime(uint256);
    event SetStartTime(uint256);
    event SetBonusPercentages(address, uint256);
    event Claim(address, uint256);
    event SetUsdPrice(address, uint256);
    event SetBuyPrice(address, uint256);
    event PrivateSaleCreated(
        address creator,
        uint256 tokenPrice,
        uint256 tokenSupply,
        uint256 clif,
        uint256 vestingPeriod,
        uint256 releaseDays,
        uint256 startTime,
        uint256 endTime
    );
    event RewardPlanCreated(uint256, uint256, uint256, uint256);

    constructor() {
        owner = msg.sender;
        isEligibleForRef[msg.sender] = true;

        privateSalePlanId++;
        privateSale[privateSalePlanId] = PrivateSale({
            price: 100,
            supply: 50000000 ether,
            clif: 300,
            vestingPeriod: 1500,
            releaseDays: 300,
            startTime: block.timestamp,
            endTime: block.timestamp + 3000,
            onGoing: true
        });
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not the owner!");
        _;
    }

    // Set price of BNB in usd
    function setUsdPrice(uint256 price) external onlyOwner {
        emit SetUsdPrice(msg.sender, price);
        priceOfBNB = price;
    }

    function stopPrivateSale(
        uint256 privateSaleId
    ) external onlyOwner returns (bool) {
        PrivateSale storage plan = privateSale[privateSaleId];
        plan.onGoing = false;
        return true;
    }

    function startPrivateSale(
        uint256 privateSaleId
    ) external onlyOwner returns (bool) {
        PrivateSale storage plan = privateSale[privateSaleId];

        require(
            plan.endTime > block.timestamp,
            "this private sale already finished!"
        );

        plan.onGoing = true;
        return true;
    }

    function createIbvestmentPlan(
        uint256 minSpend, 
        uint256 maxSpend, 
        uint256 rewards, 
        uint256 tokenGeneration
    ) 
        external 
        onlyOwner
    {
        rewardsPlanId++;
        rewardsAccordingSpend[rewardsPlanId] = RewardsAccordingSpend({
            minSpend:minSpend,
            maxSpend: maxSpend,
            purchaseBonus: rewards,
            tge: tokenGeneration
        });

        emit RewardPlanCreated(minSpend, maxSpend, rewards, tokenGeneration);
    }

    function createPrivateSale(
        uint256 tokenPrice,
        uint256 tokenSupply,
        uint256 clif,
        uint256 vestingPeriod,
        uint256 releaseDays,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner returns (uint256) {
        privateSalePlanId++;

        privateSale[privateSalePlanId] = PrivateSale({
            price: tokenPrice,
            supply: tokenSupply,
            clif: clif,
            vestingPeriod: vestingPeriod,
            releaseDays: releaseDays,
            startTime: block.timestamp + startTime,
            endTime: block.timestamp + endTime,
            onGoing: true
        });

        emit PrivateSaleCreated(
            msg.sender,
            tokenPrice,
            tokenSupply,
            clif,
            vestingPeriod,
            releaseDays,
            startTime,
            endTime
        );

        return privateSalePlanId;
    }



    function buyToken(
        address referer,
        uint256 privateSaleId
    ) external payable returns (bool) {
        require(msg.value > 0, "Zero value");
        uint256 refToken;
        uint256 amount = ((msg.value * priceOfBNB)) / 1 ether;
        BEP20 token = BEP20(TOKENADDRESS);
        (uint256 tokenGeneration, uint256 planBonus) = getRewardsPlan(amount);
        PrivateSale storage plan = privateSale[privateSaleId];
        uint256 tokens = ((amount * 1 ether * 10 ** 4) / plan.price);

        require(plan.onGoing, "private sale stopped! or finished!");
        require(plan.price != 0, "Buy price not set");
        require(block.timestamp > plan.startTime, "Start time not defined");
        require(block.timestamp < plan.endTime, "privatesale is finished!");
        require(
            token.balanceOf(address(this)) >= tokens,
            "Not enough balance on contract"
        );

        uint256 totalTransfarableToken = ((tokens * tokenGeneration) / 100) +
            ((tokens * planBonus) / 100);

        uint256 claimableToken = tokens - totalTransfarableToken;

        require(tokenGeneration != 1, "invalid privateSale");
        require(
            plan.supply >= (soldToken[privateSaleId] + tokens),
            "not enough tokens or private sale end!"
        );

        soldToken[privateSaleId] = soldToken[privateSaleId] + tokens;

        userId[msg.sender][privateSaleId]++;

        userClaimableTokenDetails[msg.sender][
            userId[msg.sender][privateSaleId]
        ] = ClaimRemainingToken({
            claimAmout: claimableToken,
            claimAt: block.timestamp + plan.clif * 1 days, // need to add days conversion here
            vestingPeriod: plan.vestingPeriod,
            releaseDays: plan.releaseDays,
            transfered: false
        });

        isEligibleForRef[msg.sender] = true;
        if ((!refAddress[msg.sender][referer]) && (msg.sender != referer)) {
            if (isEligibleForRef[referer]) {
                refToken = ((tokens * bonusPercent) / 100);
                refAddress[msg.sender][referer] = true;
                require(
                    token.transfer(referer, refToken),
                    "token sending fail to ref!"
                );
            }
        }

        require(
            token.transfer(msg.sender, totalTransfarableToken),
            "token buy fail!"
        );
        return true;
    }

    // Set bonus percent
    function setRefBonusPercentage(uint256 bonus) external onlyOwner {
        bonusPercent = bonus;
        emit SetBonusPercentages(msg.sender, bonus);
    }

    //  claim tokens
    function claimTokens(uint256 privateSaleId) external {
        BEP20 token = BEP20(TOKENADDRESS);
        ClaimRemainingToken storage claims = userClaimableTokenDetails[
            msg.sender
        ][privateSaleId];

        require(block.timestamp >= claims.claimAt, "clif time not over");
        require(!claims.transfered, "already transferd");

        lockToken[msg.sender] = lockToken[msg.sender] + claims.claimAmout;
        claims.transfered = true;
        releaseTime[msg.sender][privateSaleId] =
            claims.claimAt +
            claims.releaseDays *
            1 days;

        require(
            token.transfer(msg.sender, claims.claimAmout),
            "token claim fail!"
        );
    }

    // View Current Bonus
    function viewRefBonusPercent() external view returns (uint256) {
        return bonusPercent;
    }

    // Show USD Price of 1 BNB
    function usdPrice() external view returns (uint256) {
        uint256 Amount = priceOfBNB;
        return Amount;
    }

    function releaseTokens(uint256 privateSaleId) external returns (bool) {
        userReleaseTokens[msg.sender][privateSaleId]++;
        ClaimRemainingToken storage release = userClaimableTokenDetails[
            msg.sender
        ][privateSaleId];

        require(block.timestamp > release.claimAt, "clif time not over");
        require(
            block.timestamp > releaseTime[msg.sender][privateSaleId],
            "wait for vesting time over"
        );
        releaseTime[msg.sender][privateSaleId] =
            releaseTime[msg.sender][privateSaleId] +
            release.releaseDays *
            1 days; // need to add  86400
        uint256 noOfRelease;
        if (release.releaseDays > 0) {
            noOfRelease = release.vestingPeriod / release.releaseDays;
        } else {
            noOfRelease = 1;
        }
        if ((release.claimAt + release.vestingPeriod) > block.timestamp) {
            uint256 amountToBereleased = release.claimAmout / noOfRelease;
            require(
                userReleaseTokens[msg.sender][privateSaleId] <= noOfRelease,
                "all tokens are released"
            );
            lockToken[msg.sender] = lockToken[msg.sender] - amountToBereleased;
        } else {
            require(lockToken[msg.sender] != 0, "all tokens are released!");
            lockToken[msg.sender] = 0;
        }
        return true;
    }

    // Owner Token Withdraw
    function withdrawToken(
        address contractAddress,
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        require(to != address(0), "can't transfer at this address");
        BEP20 token = BEP20(contractAddress);
        require(token.transfer(to, amount), "token withdraw fail!");
        return true;
    }

    // Owner BNB Withdraw
    function withdrawBNB(
        address payable to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        require(to != address(0), "can't transfer at this address");
        to.transfer(amount);
        return true;
    }

    // Ownership Transfer
    function transferOwnership(address to) external onlyOwner returns (bool) {
        require(to != address(0), "can't transfer at this address");
        owner = to;
        emit OwnershipTransferred(to);
        return true;
    }

    function getRewardsPlan(
        uint256 amount
    ) internal view returns (uint256 bonus, uint256 tge) {

        for (uint256 i = 0; i < rewardsPlanId; i++) {
            RewardsAccordingSpend storage rewards = rewardsAccordingSpend[i];
            if (amount < rewards.maxSpend+1){
                continue;
            }else {
                return (rewards.purchaseBonus, rewards.tge);
            }
        }
        return (1,1);
    }
}
