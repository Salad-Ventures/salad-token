import { ethers } from "hardhat";
import { run } from "./helper";

run(async () => {
  const [owner] = await ethers.getSigners();
  const rewardCF = await ethers.getContractFactory("SaladReward");
  if (!process.env.ADDR_REWARD_TOKEN)
    throw new Error("ADDR_REWARD_TOKEN env variable not set");

  const rewardContract = rewardCF.attach(process.env.ADDR_REWARD_TOKEN);

  if (!process.env.ADDR_SALAD_BOWL)
    throw new Error("ADDR_SALAD_BOWL env variable not set");

  await rewardContract.connect(owner).updateSaladBowl(process.env.ADDR_SALAD_BOWL);
});
