const myContract = artifacts.require("FANVesting");

module.exports = async function (deployer) {
  deployer.deploy(myContract);
};
