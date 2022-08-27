const myContract = artifacts.require("FANToken");

module.exports = async function (deployer) {
  deployer.deploy(myContract);
};
