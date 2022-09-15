const HDWalletProvider = require("@truffle/hdwallet-provider");
const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {

  plugins: ["truffle-contract-size"],
  networks: {
    matic_testnet: {
      provider: () => new HDWalletProvider(mnemonic, 'https://matic-mumbai.chainstacklabs.com/'),
      network_id: 80001,
      skipDryRun: true,
    },
  },
  mocha: {
    // timeout: 100000
  },
  compilers: {
    solc: {
      version: "0.5.7",
      docker: false,
      parser: "solcjs",
      settings: {
       optimizer: {
         enabled: true,
         runs: 200
       },
       evmVersion: "byzantium"
      }
    }
  },
};
