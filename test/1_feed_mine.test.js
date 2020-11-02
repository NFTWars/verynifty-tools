const NiftyTools = artifacts.require("NiftyTools");
const MuseToken = artifacts.require("MuseToken");
const VNFT = artifacts.require("VNFT");
const ChiToken = artifacts.require("ChiToken");

const { expectRevert } = require("@openzeppelin/test-helpers");

require("./utils");

const MUSE_FEE = 5000; //  5% MUSE per service
const toWei = (amount) => web3.utils.toWei(String(amount));
const fromWei = (amount) => Number(web3.utils.fromWei(String(amount)));

contract("NiftyTools", ([operator, alice, bob, charlie]) => {
  let tools, muse, vNFT;

  before(async function () {
    chi = await ChiToken.new();
    muse = await MuseToken.new();
    vNFT = await VNFT.new(muse.address);
    tools = await NiftyTools.new(
      vNFT.address,
      muse.address,
      chi.address,
      MUSE_FEE
    );

    await muse.grantRole(
      "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6",
      vNFT.address
    );
  });

  describe("Initial Values", () => {
    it("should get correct contract addresses", async function () {
      const _vnft = await tools.vnft();
      assert.equal(_vnft, vNFT.address);

      const _muse = await tools.muse();
      assert.equal(_muse, muse.address);
    });

    it("should get correct fee", async function () {
      const _fee = await tools.fee();
      assert.equal(_fee, MUSE_FEE);
    });

    it("should get correct maxIds", async function () {
      const _maxIds = await tools.maxIds();
      assert.equal(_maxIds, 20);
    });
  });

  describe("Tools", () => {
    let IDS = [];

    before(async function () {
      // fund address with MUSE
      await muse.transfer(alice, toWei(100), { from: operator });

      // Mint 10 vNFTs
      for (let i = 0; i < 10; i++) {
        await vNFT.mint(alice, { from: operator });
        await vNFT.addCareTaker(i, tools.address, { from: alice });
        IDS.push(i);
      }

      await vNFT.createItem("simple", 5, 100, 3 * 24 * 60 * 60);
    });

    it("should have muse and vnft tokens", async function () {
      const balance = await muse.balanceOf(alice);
      assert.equal(balance, toWei(100));

      const owner = await vNFT.ownerOf(0);
      assert.equal(owner, alice);
    });

    it("should get correct available rewards to claim", async function () {
      await advanceTimeAndBlock(25 * 60 * 60); // 25h later

      for (let i = 0; i < IDS.length; i++) {
        const rewards = await vNFT.getRewards(i);
        assert.equal(rewards, toWei(6));
      }
    });

    it("should be able to claim mining rewards from multiple tokens", async function () {
      const initialBalance = await muse.balanceOf(alice);
      const initialOperatorBalance = await muse.balanceOf(operator);

      await tools.claimMultiple(IDS, { from: alice });
      const finalBalance = await muse.balanceOf(alice);

      assert.equal(
        fromWei(finalBalance),
        fromWei(initialBalance) + 60 * (1 - 0.05)
      ); // 10*6 -5% fee

      const toolsBalance = await muse.balanceOf(tools.address);
      assert.equal(toolsBalance, 0);

      const finalOperatorBalance = await muse.balanceOf(operator);
      assert.equal(
        fromWei(finalOperatorBalance) - fromWei(initialOperatorBalance),
        60 * 0.05
      );
    });

    it("should not be able to feed multiple tokens without approving MUSE", async function () {
      await muse.approve(tools.address, toWei(100), { from: alice });
      await expectRevert(
        tools.feedMultiple(IDS, Array(10).fill(1), { from: alice }),
        "revert ERC20: transfer amount exceeds allowance"
      );
    });

    it("should be able to feed multiple tokens", async function () {
      // One time approval
      await tools.approveMuse(toWei(10000), { from: operator });
      await muse.approve(tools.address, toWei(100), { from: alice });

      const initialBalance = await muse.balanceOf(alice);
      const initialOperatorBalance = await muse.balanceOf(operator);
      await tools.feedMultiple(IDS, Array(10).fill(1), { from: alice });
      const finalBalance = await muse.balanceOf(alice);

      assert.equal(
        fromWei(finalBalance),
        fromWei(initialBalance) - 50 * (1 + 0.05)
      ); // 10*5 -5% fee

      const toolsBalance = await muse.balanceOf(tools.address);
      assert.equal(toolsBalance, 0);

      const finalOperatorBalance = await muse.balanceOf(operator);
      assert.equal(
        fromWei(finalOperatorBalance),
        fromWei(initialOperatorBalance) + 50 * 0.05
      );
    });
  });
});
