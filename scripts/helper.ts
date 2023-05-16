import { Contract } from "ethers";
import { ethers } from "hardhat";

/**
 * Executes async scripts with process termination handlers.
 * 
 * @param runnable function to be executed
 */
export const run = (runnable: () => Promise<void> | void) => {
  const result = runnable();

  // non-async runnable function
  if (!result) return result;

  // async runnable function
  return result
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
}

/**
 * Deploys contract using Hardhat contract deployment helper
 * 
 * @param contractName name of contract to be deployed
 * @param deployArgs constructor arguments of contract to be deployed.
 * @returns an ethers contract instance
 */
export const deployContract = async (contractName: string, ...deployArgs: any[]): Promise<Contract> => {
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = await contractFactory.deploy(...deployArgs);

  console.log("Deployed contract", contractName, contract.address);

  return contract;
}
