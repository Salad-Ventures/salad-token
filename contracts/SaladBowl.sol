// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

// import "hardhat/console.sol";

import "./ISaladBowl.sol";
import "./ISaladReward.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SaladBowl is ISaladBowl, Ownable, Pausable, ReentrancyGuard {
  using Math for uint256;

  uint256 private constant REWARD_PRECISION = 1e12;

  // staked ERC20 asset
  IERC20 private immutable _asset;

  // ERC20 reward token
  ISaladReward private immutable _reward;

  // total reward emission per block
  uint256 public rewardPerBlock = 0;

  // last rewarded block
  uint public lastRewardBlock = 0;

  // asset deposit balances
  mapping(address => uint256) private _balances;

  // total asset deposited
  uint256 private _totalSupply;

  // array of staker addresses
  address[] private _stakers;

  // index of staker address, for gas optimisation
  mapping(address => uint) private _stakerIndex;

  // reward owed to each staker up to lastRewardBlock
  mapping(address => uint256) private _rewardDebts;

  constructor(IERC20 asset_, ISaladReward reward_) {
    _asset = asset_;
    _reward = reward_;

    lastRewardBlock = block.number;
  }

  // @dev deposits `amount` of underlying asset into vault and records
  // the balance of the staker. Any pending reward token is harvested
  // during the deposit.
  function deposit(uint256 amount) whenNotPaused nonReentrant public virtual {
    address account = _msgSender();

    _withdrawRewards(account);
    uint256 balance = _mintBalance(account, amount);
    SafeERC20.safeTransferFrom(_asset, account, address(this), amount);

    emit Deposit(account, amount, balance);
  }

  // @dev withdraws `amount` of underlying asset from vault and updates
  // the balance of the staker. Any pending reward token is harvested
  // during the withdraw. 
  function withdraw(uint256 amount) whenNotPaused nonReentrant public virtual {
    address account = _msgSender();

    _withdrawRewards(account);
    uint256 balance = _burnBalance(account, amount);
    SafeERC20.safeTransfer(_asset, account, amount);

    emit Withdraw(account, amount, balance);
  }

  // @dev harvests all pending reward token for staker.
  function harvest() whenNotPaused nonReentrant public virtual {
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
  function rewardDebt(address account) public view virtual returns (uint256) {
    return _rewardDebts[account];
  }

  // @dev calculate and update every staker's reward debt up to current block,
  // and updates `rewardPerBlock`.
  function setRewardPerBlock(uint256 rewardPerBlock_) onlyOwner public {
    _updateRewards();
    rewardPerBlock = rewardPerBlock_;

    emit SetRewardPerBlock(_msgSender(), rewardPerBlock);
  }

  // @dev contract pause unpause function by contract owner.
  function setPause(bool pause) onlyOwner public {
    if (pause) _pause();
    else _unpause();
  }

  // @dev calculate and update every staker's reward debt up to current block,
  // and set `lastRewardBlock` to current block.
  function _updateRewards() internal {
    uint currentBlock = block.number;

    // no need to update again if already done for the block.
    if (lastRewardBlock == currentBlock) return;

    // only update reward debts if necessary.
    if (rewardPerBlock > 0 && _totalSupply > 0) {
      uint length = _stakers.length;
      for (uint256 i = 0; i < length; i++) {
        uint256 balance = _balances[_stakers[i]];
        uint256 share = (balance * REWARD_PRECISION) / _totalSupply;
        uint blocks = currentBlock - lastRewardBlock;
        uint256 rewards = (blocks * rewardPerBlock * share) / REWARD_PRECISION;
        _rewardDebts[_stakers[i]] += rewards;
      }
    }

    lastRewardBlock = currentBlock;
  }

  // @dev updates reward debts and sends rewards owed to staker `account`.
  function _withdrawRewards(address account) internal {
    _updateRewards();

    uint256 rewardOwed = _rewardDebts[account];
    if (rewardOwed == 0) return;

    delete _rewardDebts[account];
    _reward.mint(account, rewardOwed);
  }

  // @dev records deposited asset balance and updates total supply,
  // returns account's new balance.
  function _mintBalance(address account, uint256 amount) internal returns (uint256) {
    if (_balances[account] == 0) {
      _addStaker(account);
    }

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
      _removeStaker(account);
    }

    return _balances[account];
  }

  // @dev adds new staker to tracking array and index map
  function _addStaker(address account) internal {
    require(account != address(0), "SaladBowl: zero address cannot be staker");
    _stakerIndex[account] = _stakers.length;
    _stakers.push(account);
  }

  // @dev remove given staker from tracking array and index map
  function _removeStaker(address account) internal {
    // @dev gas efficient method to remove element from array.
    uint stakerIndex = _stakerIndex[account];
    if (_stakers.length > 1) {
      address substituteStaker = _stakers[_stakers.length - 1];
      _stakers[stakerIndex] = substituteStaker;
      _stakerIndex[substituteStaker] = stakerIndex;
    }
    delete _stakerIndex[account];
    _stakers.pop();
  }
}
