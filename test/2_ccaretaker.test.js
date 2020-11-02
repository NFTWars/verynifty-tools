const NiftyTools = artifacts.require("NiftyTools");
const MuseToken = artifacts.require("MuseToken");
const VNFT = artifacts.require("VNFT");
const ChiToken = artifacts.require("ChiToken");

const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");

require("./utils");

const toWei = (amount) => web3.utils.toWei(String(amount));
const fromWei = (amount) => Number(web3.utils.fromWei(String(amount)));

const MUSE_FEE = 5000; //  5% MUSE per service

contract("NiftyTools", ([owner, alice, bob, feeRecipient]) => {
  let niftyTools, muse, vNFT;

  let IDS = [];

  before(async function () {
    chi = await ChiToken.new();
    muse = await MuseToken.new();
    vNFT = await VNFT.new(muse.address);
    niftyTools = await NiftyTools.new(
      vNFT.address,
      muse.address,
      chi.address,
      MUSE_FEE
    );

    await muse.grantRole(
      "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
      vNFT.address
    );

    await niftyTools.setFeeRecipient(feeRecipient);

    await niftyTools.approveMuse(toWei(100000), { from: owner });

    // fund address with MUSE
    await muse.transfer(alice, toWei(200), { from: owner });

    // Mint 10 vNFTs
    for (let i = 0; i < 10; i++) {
      await vNFT.mint(alice, { from: owner });
      await vNFT.addCareTaker(i, niftyTools.address, { from: alice });
      IDS.push(i);
    }

    await vNFT.createItem("simple", 5, 100, 3 * 24 * 60 * 60);
  });

  describe("Care Taker Mining", () => {
    it("should be able to start care taking", async function () {
      await niftyTools.startCareTaking(IDS, { from: alice });

      for (let i = 0; i < IDS.length; i++) {
        const isCareTaking = await niftyTools.isCareTaking(IDS[i], {
          from: alice,
        });
        assert(isCareTaking);
      }
    });

    it("should be able to trigger care taking mining", async function () {
      await advanceTimeAndBlock(25 * 60 * 60); // 25h later
      const tx = await niftyTools.triggerMine({ from: owner });
      console.log("\tGas Used:", tx.receipt.gasUsed);

      // 10 IDS = 884477 gas
    });

    it("feeRecipient should receive 50% of MUSE mined", async function () {
      const balance = await muse.balanceOf(feeRecipient);
      assert.equal(fromWei(balance), 30);
    });

    it("tools address should have 50% of MUSE mined", async function () {
      const toolsBalance = await muse.balanceOf(niftyTools.address);
      assert.equal(fromWei(toolsBalance), 30);
    });

    it("user address be able to withdraw 50% of mined muse", async function () {
      const available = await niftyTools.museBalance(alice);
      assert.equal(fromWei(available), 30);

      await niftyTools.withdrawMuse({ from: alice });

      const toolsBalance = await muse.balanceOf(niftyTools.address);
      assert.equal(fromWei(toolsBalance), 0);
    });
  });

  describe("Care Taker Feeding", () => {
    it("should be able to deposit MUSE for care taking", async function () {
      await expectRevert(
        niftyTools.depositMuse(toWei(10), { from: alice }),
        "revert ERC20: transfer amount exceeds allowance "
      );

      await muse.approve(niftyTools.address, toWei(100), { from: alice });
      await niftyTools.depositMuse(toWei(50), { from: alice });

      const balance = await niftyTools.museBalance(alice);

      assert.equal(fromWei(balance), 50);
    });

    it("should be able to trigger care taking feeding", async function () {
      // User needs to have enough MUSE balance on the contract to be able to feed it correctly
      const { receipt } = await niftyTools.triggerFeed(1, { from: owner });

      console.log("\tGas Used:", receipt.gasUsed);

      for (let i = 0; i < IDS.length; i++) {
        const id = IDS[i];

        expectEvent(receipt, "Fed", {
          tokenId: new BN(id),
          itemId: new BN(1),
        });
      }

      // 10 IDS = 988277 gas
    });

    it("should be able to trigger care taking feeding with CHI tokens", async function () {
      await muse.approve(niftyTools.address, toWei(100), { from: alice });
      await niftyTools.depositMuse(toWei(100), { from: alice });

      // await chi.mint(150, { from: owner });
      // await chi.approve(niftyTools.address, 150, { from: owner });

      // let chiBalance = await chi.balanceOf(owner);
      // console.log(String(chiBalance));

      const { receipt } = await niftyTools.triggerFeed(1, { from: owner });

      console.log("\tGas Used:", receipt.gasUsed);

      for (let i = 0; i < IDS.length; i++) {
        const id = IDS[i];

        expectEvent(receipt, "Fed", {
          tokenId: new BN(id),
          itemId: new BN(1),
        });
      }

      // chiBalance = await chi.balanceOf(owner);
      // console.log(String(chiBalance));

      // 10 IDS = 988277 gas
    });
  });
});
