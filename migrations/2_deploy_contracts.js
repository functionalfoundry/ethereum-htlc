var HTLC = artifacts.require('./HTLC.sol')

module.exports = deployer => {
  deployer.deploy(HTLC)
}
