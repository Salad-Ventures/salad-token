import { ethers } from "hardhat";
import { deployContract, run } from "./helper";

run(async () => {
  const [owner] = await ethers.getSigners();
  const tokenContract = await deployContract("SaladToken");
  const rewardContract = await deployContract("SaladReward");

  const height = await ethers.provider.getBlockNumber();
  const bowlContract = await deployContract(
    "SaladBowl",
    tokenContract.address,
    rewardContract.address,
    1e9,
    height + 10,
    height + 10 + 5000,
  );

    // Call a function from the deployed bowl contract
    const result = await rewardContract.connect(owner).updateSaladBowl(bowlContract.address);
    console.log(result)
});
