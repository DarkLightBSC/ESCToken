import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";

import 'hardhat-contract-sizer';
import "@tenderly/hardhat-tenderly"


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();
  
  for (const account of accounts) {
    console.log(account.address);
  }
});



// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

import { HardhatUserConfig } from "hardhat/config";
import * as dotenv from "dotenv";

dotenv.config();
const mnemonic = process.env.MNEMONIC;

const config: HardhatUserConfig = {
  defaultNetwork: "localhost",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      allowUnlimitedContractSize: true,
    },
    hardhat: {
      forking: {
        url: "https://bsc.getblock.io/testnet/?api_key=7e4db454-9535-4a89-9572-bf15e930adb3",
        // blockNumber: 9371729,
      },
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      accounts: {mnemonic: mnemonic},
      allowUnlimitedContractSize: true,
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      // url: "https://bsc.getblock.io/mainnet/?api_key=7e4db454-9535-4a89-9572-bf15e930adb3",
      chainId: 97,
      gasPrice: 20000000000,
      gas: 20e10,
      // blockGasLimit: 0x1fffffffffffff,
      accounts: {mnemonic: mnemonic},
      timeout: 20000
    },
    mainnet: {
      // url: "https://bsc-dataseed.binance.org/",
      url: "https://bsc-dataseed1.defibit.io/",
      chainId: 56,
      gasPrice: 20000000000,
      // accounts: {mnemonic: mnemonic}
      accounts: ['7dab77b56d3f6df8addf21fa81fd41af4601c9fc142746e44bf8b33927b5c24c']
    }
  },

  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "EDDHJNNF5FNSH26TP2R67IMZACCFHXZ3A9", //bscsan
  },

  solidity: {
    compilers: [
      {
        version: '0.7.3',
        settings:{
          optimizer: {
            enabled: true,
            runs: 200
          },
          // evmVersion: "byzantium"
        }
      },
      {
        version: '0.6.12',
        settings:{
          optimizer: {
            enabled: true,
            runs: 200
          },
          // evmVersion: "byzantium"
        }
      },
    ], 
  },

  mocha: {
    timeout: 60000
  },

  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },

  tenderly: {
    project: "esctoken",
    username: "guange",
  }
};

export default config;

