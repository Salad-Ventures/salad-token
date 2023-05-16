require('dotenv').config();

import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";

const accounts: string[] = [];

if (process.env.DEPLOY_KEY)
  accounts.push(process.env.DEPLOY_KEY);


const config: HardhatUserConfig = {
  solidity: "0.8.18",
  networks: {
    goerli: {
      url: process.env.RPC_URL_GOERLI,
      accounts,
    },
  },
};

export default config;
