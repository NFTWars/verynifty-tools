const NiftyTools = artifacts.require("NiftyTools");

const VNFT_CONTRACT = "0x57f0B53926dd62f2E26bc40B30140AbEA474DA94";
const MUSE_TOKEN = "0xB6Ca7399B4F9CA56FC27cBfF44F4d2e4Eef1fc81";
const CHI_TOKEN = "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c";
const MUSE_FEE = 5000; //  5% fee

module.exports = async function (deployer, network) {
  if (network !== "development")
    await deployer.deploy(
      NiftyTools,
      VNFT_CONTRACT,
      MUSE_TOKEN,
      CHI_TOKEN,
      MUSE_FEE
    );
};
