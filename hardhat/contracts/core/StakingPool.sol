// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import "../interfaces/IERC20.sol";

contract StakingPool {
    IERC20 public rewardToken;
    IERC20 public stakingToken;
    uint256 private _totalSupply;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public decimalFactor;
    uint256 public constant fixedAPY = 12;
    bool public rewardRateSet = false;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public staked;

    /// @dev - modifier that will calculate the amount of rewards earned and add it to the rewards mapping
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        rewards[_account] = rewardEarned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        _;
    }

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        uint256 rewardTokenDecimals = rewardToken.decimals();
        decimalFactor = 10 ** rewardTokenDecimals;
    }

    /// @dev - to stake tokens into the pool
    /// @param _amount - the amount of tokens to stake
    function stakeToken(
        uint256 _amount,
        address _user
    ) external updateReward(_user) {
        require(_amount > 0, "Cannot stake 0 tokens");
        _totalSupply += _amount;
        staked[_user] += _amount;

        if (!rewardRateSet) {
            _setRewardRate();
        }
    }

    /// @dev - to withdraw tokens from the pool
    /// @param _amount - the amount of tokens to withdraw
    function withdrawToken(
        uint256 _amount,
        address _user
    ) external updateReward(_user) {
        require(_amount > 0, "Cannot withdraw 0 tokens");
        _totalSupply -= _amount;
        staked[_user] -= _amount;
    }

    /// @dev - To calculuate the amount of rewards per token staked
    /// @return uint256 - The amount of rewards per token staked
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * decimalFactor) /
                _totalSupply);
    }

    function getStakedAmount(address _user) public view returns (uint256) {
        return staked[_user];
    }

    /**
     * @dev - to calculate the earned rewards for a user based on the amount of tokens staked
     * @param _account - the address of the user
     * @return uint256 - the amount of rewards earned
     */

    function rewardEarned(address _account) public view returns (uint256) {
        return
            ((staked[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) /
                decimalFactor) + rewards[_account];
    }

    function claimReward(address _user) external updateReward(msg.sender) {
        uint256 reward = rewards[_user];
        if (reward > 0) {
            rewards[_user] = 0;
            rewardToken.transfer(_user, reward);
        }
    }

    function _setRewardRate() internal {
        require(!rewardRateSet, "Reward rate already set");
        rewardRate =
            (stakingToken.balanceOf(address(this)) * fixedAPY) /
            (365 * 100);
        rewardRateSet = true;
    }
}
