import BigNumber from "bignumber.js";
import { ethers } from "hardhat";
import { run } from "./helper";



run(async () => {
  const [owner] = await ethers.getSigners();
  const saladCF = await ethers.getContractFactory("SaladToken");
  if (!process.env.ADDR_SALAD_TOKEN)
    throw new Error("ADDR_SALAD_TOKEN env variable not set");

  const saladContract = saladCF.attach(process.env.ADDR_SALAD_TOKEN);

  const tx = await saladContract.connect(owner).mint(owner.address, new BigNumber(10000).shiftedBy(18).toString(10));
  console.log(tx);
});
