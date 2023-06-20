// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

// import "hardhat/console.sol";

import "./ISaladBowl.sol";
import "./ISaladReward.sol";

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract SaladBowl is ISaladBowl, Context, ReentrancyGuard {
  using Math for uint256;

  uint256 private constant REWARD_PRECISION = 1e12;

  // staked ERC20 asset
  IERC20 private immutable _asset;

  // ERC20 reward token
  ISaladReward private immutable _reward;

  // total reward emission per block
  uint256 public immutable rewardPerBlock;

  // first block of reward emission
  uint public immutable rewardStartBlock;

  // last block of reward emission
  uint public immutable rewardEndBlock;

  // last rewarded block
  uint public lastRewardBlock = 0;

  // asset deposit balances
  mapping(address => uint256) private _balances;

  // total asset deposited
  uint256 private _totalSupply;

  // total asset deposited
  uint256 private _rewardPerShare;

  // reward owed to each staker up to lastRewardBlock
  mapping(address => uint256) private _rewardDebtPerShare;

  constructor(
    IERC20 asset_, 
    ISaladReward reward_,
    uint256 rewardPerBlock_,
    uint256 rewardStartBlock_,
    uint256 rewardEndBlock_
  ) {
    _asset = asset_;
    _reward = reward_;

    lastRewardBlock = block.number;

    require(rewardStartBlock_ > block.number, "SaladBowl: rewardStartBlock must be greater than current block");
    require(rewardEndBlock_ > rewardStartBlock_, "SaladBowl: rewardEndBlock must be greater than rewardStartBlock");
    require(rewardPerBlock_ > 0, "SaladBowl: rewardPerBlock must be greater than zero");

    rewardPerBlock = rewardPerBlock_;
    rewardStartBlock = rewardStartBlock_;
    rewardEndBlock = rewardEndBlock_;
  }

  // @dev deposits `amount` of underlying asset into vault and records
  // the balance of the staker. Any pending reward token is harvested
  // during the deposit.
  function deposit(uint256 amount) nonReentrant public virtual {
    require(amount > 0, "SaladBowl: deposit amount must be greater than zero");
    address account = _msgSender();

    _withdrawRewards(account);
    uint256 balance = _mintBalance(account, amount);
    SafeERC20.safeTransferFrom(_asset, account, address(this), amount);

    emit Deposit(account, amount, balance);
  }

  // @dev withdraws `amount` of underlying asset from vault and updates
  // the balance of the staker. Any pending reward token is harvested
  // during the withdraw. 
  function withdraw(uint256 amount) nonReentrant public virtual {
    address account = _msgSender();

    _withdrawRewards(account);
    uint256 balance = _burnBalance(account, amount);
    SafeERC20.safeTransfer(_asset, account, amount);

    emit Withdraw(account, amount, balance);
  }

  // @dev harvests all pending reward token for staker.
  function harvest() nonReentrant public virtual {
    _withdrawRewards(_msgSender());
  }

  // @dev withdraws staker's entire balance of underlying asset from
  // vault and updates the balance of the staker. Pending rewards will
  // not be harvested, and can be executed when contract is paused.
  function emergencyWithdraw() nonReentrant public virtual {
    address account = _msgSender();

    uint256 amount = _balances[account];
    uint256 balance = _burnBalance(account, amount);
    SafeERC20.safeTransfer(_asset, account, amount);

    emit Withdraw(account, amount, balance);
  }

  // @dev underlying staked ERC20 asset.
  function asset() external view returns (address) {
    return address(_asset);
  }

  // @dev total staked underlying asset.
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  // @dev deposited `asset` balance of a given `account`.
  function balanceOf(address account) public view virtual returns (uint256) {
    return _balances[account];
  }

  // @dev reward tokens owed to a given `account` up to `lastRewardBlock`.
  function pendingRewards(address account) public view virtual returns (uint256) {
    uint256 shares = _balances[account];
    uint256 pendingRewardPerShare = _rewardPerShare - _rewardDebtPerShare[account];
    return shares * pendingRewardPerShare / REWARD_PRECISION;
  }

  // @dev calculate and update every staker's reward debt up to current block,
  // and set `lastRewardBlock` to current block.
  function _updateRewards() internal {
    uint currentBlock = block.number;

    if (
      // skip update again if already done for the block.
      lastRewardBlock == currentBlock 

      // skip update if final reward emission already included.
      || lastRewardBlock >= rewardEndBlock

      // skip update if reward not started.
      || currentBlock < rewardStartBlock
    ) return;

    uint rewardUntilBlock = Math.min(currentBlock, rewardEndBlock);

    // skip update on first deposit.
    if (_totalSupply > 0) {
      uint blocks = rewardUntilBlock - Math.max(lastRewardBlock, rewardStartBlock);
      uint256 newReward = blocks * rewardPerBlock;
      _rewardPerShare = _rewardPerShare + (newReward * REWARD_PRECISION / _totalSupply);
    }

    lastRewardBlock = rewardUntilBlock;
  }

  // @dev updates reward debts and sends rewards owed to staker `account`.
  function _withdrawRewards(address account) internal {
    _updateRewards();

    uint256 rewardOwed = pendingRewards(account);

    _rewardDebtPerShare[account] = _rewardPerShare;

    if (rewardOwed > 0) {
      _reward.mint(account, rewardOwed);
    }
  }

  // @dev records deposited asset balance and updates total supply,
  // returns account's new balance.
  function _mintBalance(address account, uint256 amount) internal returns (uint256) {
    unchecked {
      _balances[account] += amount;
      _totalSupply += amount;
    }

    return _balances[account];
  }

  // @dev records asset balance after withdraw and updates total supply,
  // returns account's new balance.
  function _burnBalance(address account, uint256 amount) internal returns (uint256) {
    uint256 fromBalance = _balances[account];
    require(fromBalance >= amount, "SaladBowl: withdraw amount exceeds balance");

    unchecked {
      _balances[account] -= amount;
      _totalSupply -= amount;
    }

    if (_balances[account] == 0) {
      delete _balances[account];
    }

    return _balances[account];
  }
}
