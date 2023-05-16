import { deployContract, run } from "./helper";

run(async () => {
  const tokenContract = await deployContract("SaladToken");
  const rewardContract = await deployContract("SaladReward");
  const bowlContract = await deployContract("SaladBowl", tokenContract.address, rewardContract.address);
});
