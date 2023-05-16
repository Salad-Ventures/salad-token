import { ethers } from "hardhat";
import * as networkHelpers from "@nomicfoundation/hardhat-network-helpers";
import { deployContract, run } from "./helper";
import { BigNumber } from "bignumber.js";

run(async () => {
  const tokenContract = await deployContract("SaladToken");
  const rewardContract = await deployContract("SaladReward");
  const bowlContract = await deployContract("SaladBowlP", tokenContract.address, rewardContract.address);

  const [owner, wallet1, wallet2] = await ethers.getSigners();

  await rewardContract.connect(owner).updateSaladBowl(bowlContract.address);

  console.log("height", await ethers.provider.getBlockNumber());

  const decimals = await tokenContract.decimals();
  const amount1 = new BigNumber(100).shiftedBy(decimals);
  const amount2 = new BigNumber(200).shiftedBy(decimals);

  await tokenContract.connect(owner).mint(wallet1.address, amount1.toString(10));
  await tokenContract.connect(wallet1).approve(bowlContract.address, amount1.toString(10));
  await bowlContract.connect(wallet1).deposit(amount1.toString(10));

  await tokenContract.connect(owner).mint(wallet2.address, amount2.toString(10));
  await tokenContract.connect(wallet2).approve(bowlContract.address, amount2.toString(10));
  await bowlContract.connect(wallet2).deposit(amount2.toString(10));

  await networkHelpers.mine(1000);

  console.log("1 token balance", await tokenContract.balanceOf(wallet1.address));
  console.log("1 vault balance", await bowlContract.balanceOf(wallet1.address));

  console.log("2 token balance", await tokenContract.balanceOf(wallet2.address));
  console.log("2 vault balance", await bowlContract.balanceOf(wallet2.address));

  await bowlContract.connect(wallet1).withdraw(amount1.toString(10));
  await bowlContract.connect(wallet2).harvest();

  console.log("1 token balance", await tokenContract.balanceOf(wallet1.address));
  console.log("1 vault balance", await bowlContract.balanceOf(wallet1.address));
  console.log("1 reward balance", await rewardContract.balanceOf(wallet1.address));

  console.log("2 token balance", await tokenContract.balanceOf(wallet2.address));
  console.log("2 vault balance", await bowlContract.balanceOf(wallet2.address));
  console.log("2 reward balance", await rewardContract.balanceOf(wallet2.address));

  console.log("height", await ethers.provider.getBlockNumber());
});
