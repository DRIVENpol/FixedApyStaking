// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IToken {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Staking is Ownable {

    /// @dev ROI for each period
    uint256[] public roi;

    /// @dev Periods
    uint256[] public periods;

    /// @dev Tokens
    IToken public stakedToken;
    IToken public rewardToken;

    /// @dev Struct for deposits
    struct Deposit {
        uint256 id;
        uint256 amount;
        uint256 period;
        uint256 startDate;
        uint256 endDate;
        address owner;
        bool ended;
    }

    /// @dev Array of deposits
    Deposit[] public deposits;

    /// @dev Link user's address to deposits
    mapping(address => Deposit[]) public usersDeposits;

    /// @dev Errors
    error InvalidPeriod();
    error InvalidAmount();
    error ERC20TransferFailed();
    error InvalidDepositOwner();
    error DepositEnded();
    error CantUnstakeNow();
    error NotEnoughTokensForRewards();
    error ArrayTooBig();

    /// @dev Events
    event Stake(uint256 id, address user, uint256 amount, uint256 period);
    event Unstake(uint256 id, address user, uint256 amount);

    /// @dev Constructor
    /// @param p1 Period 1 @param p2 Period 2 @param p3 Period 3
    /// @param r1 ROI For Period 1 @param r2 ROI For Period 2 @param r3 ROI for Period 3
    /// @param sToken Staked Token @param rToken Reward Token
    constructor(uint256 p1, uint256 p2, uint256 p3, uint256 r1, uint256 r2, uint256 r3, address sToken, address rToken) {
        periods[0] = p1;
        periods[1] = p2;
        periods[2] = p3;

        roi[0] = r1;
        roi[1] = r2;
        roi[2] = r3;

        stakedToken = IToken(sToken);
        rewardToken = IToken(rToken);
    }

    /// @dev Stake function
    function stake(uint256 amount, uint256 period) external {
        if(period != periods[0] || period != periods[1] || period!= periods[2]) revert InvalidPeriod();
        if(amount > stakedToken.balanceOf(msg.sender)) revert InvalidAmount();

        if(stakedToken.transferFrom(msg.sender, address(this), amount) == false) revert ERC20TransferFailed();

        uint256 _period = period * 1 days;

        Deposit memory newDeposit = Deposit(deposits.length, amount, period, block.timestamp, block.timestamp + _period, msg.sender, false);
        deposits.push(newDeposit);

        emit Stake(deposits.length - 1, msg.sender, amount, period);
    }

    /// @dev Unstake function
    function unstake(uint256 id) external {
        if(msg.sender != deposits[id].owner) revert InvalidDepositOwner();
        if(deposits[id].ended == true) revert DepositEnded();
        if(deposits[id].endDate <= block.timestamp) revert CantUnstakeNow();
        if(deposits[id].amount > rewardToken.balanceOf(address(this))) revert NotEnoughTokensForRewards(); 

        deposits[id].ended = true;

        uint256 _amount = deposits[id].amount;
        deposits[id].amount = 0;

        // Compute the rewards
        uint256 _rewards = computePendingRewards(id);
        uint256 _tAmount = _amount + _rewards;

        if(rewardToken.transferFrom(address(this), msg.sender, _tAmount) == false) revert ERC20TransferFailed();

        emit Unstake(id, msg.sender, _tAmount);
    }

    /// @dev Function to get the pending rewards
    function computePendingRewards(uint256 id) public view returns (uint256) {
        Deposit memory myDeposit = deposits[id];

        // See the seconds left
        uint256 _elapsedTime = block.timestamp - myDeposit.startDate;
        uint256 _roi;

        if (myDeposit.period == periods[0]) {
            _roi = roi[0];
        } else if (myDeposit.period == periods[1]) {
            _roi =  roi[1];
        } else if (myDeposit.period == periods[2]) {
            _roi = roi[2];
        }

        uint256 _pendingRewardsPerYear = myDeposit.amount * _roi / 100;
        uint256 _pendingRewardsPerDay = _pendingRewardsPerYear / 365;
        uint256 _pendingRewardsPerHour = _pendingRewardsPerDay / 24;
        uint256 _pendingRewardsPerMinute = _pendingRewardsPerHour / 60;
        uint256 _pendingRewardsPerSecond = _pendingRewardsPerMinute / 60;

        uint256 _totalPendingRewards = _elapsedTime * _pendingRewardsPerSecond;
        return _totalPendingRewards;
    }

    /// @dev Set periods
    function setPeriods(uint256[] calldata p) external onlyOwner {
        if(p.length > 3) revert ArrayTooBig();
        periods[0] = p[0];
        periods[1] = p[1];
        periods[2] = p[2];
    }

    /// @dev Set ROI for each period
    function setRoi(uint256[] calldata r) external onlyOwner {
        if(r.length > 3) revert ArrayTooBig();
        roi[0] = r[0];
        roi[1] = r[1];
        roi[2] = r[2];
    }
}
