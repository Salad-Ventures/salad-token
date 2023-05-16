// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.18;

interface ISaladReward {
  function mint(address to, uint256 amount) external;

  event UpdateSaladBowl(address indexed saladBowl, address indexed previous);
}
