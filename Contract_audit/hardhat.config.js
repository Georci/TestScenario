require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();


ALCHEMY_SEPOLIA_URL = process.env.ALCHEMY_SEPOLIA_URL;
ANVIL_URL = process.env.ANVIL_URL;
PRIVATE_KEY = process.env.PRIVATE_KEY;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
    version: "0.8.20"
  },
  defaultNetwork: "localhost",
  networks: {
    anvil: {
      url: ANVIL_URL,
      accounts: [PRIVATE_KEY]
    }
  }

};