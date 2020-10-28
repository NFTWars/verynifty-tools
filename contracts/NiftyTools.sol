// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/UintSet.sol";
import "./interfaces/IGasFeed.sol";
import "./interfaces/IChiToken.sol";
import "./interfaces/IVNFT.sol";

contract EventsPage is Ownable {
    event StartCareTaker(address indexed user, uint256 tokenId);
    event StopCareTaker(address indexed user, uint256 tokenId);
}

contract NiftyTools is EventsPage {
    using SafeMath for uint256;
    using UintSet for UintSet.Set;

    // Unordered list of tokens to caretake
    UintSet.Set careTakerSet;

    // External contracts
    IVNFT public vnft;
    IERC20 public muse;
    IGasFeed public gasFeed = IGasFeed(
        0xA417221ef64b1549575C977764E651c9FAB50141
    );
    IChiToken public chi = IChiToken(
        0x0000000000004946c0e9F43F4Dee607b0eF1fA1c
    );

    // Contrac Variables
    uint256 public maxIds = 20;
    uint256 public fee;
    uint256 public minGasPrice = 50e9;
    uint256 public nextIndex = 0;
    address public feeRecipient;
    bool paused;

    // Keep track of the MUSE balance for each user
    mapping(address => uint256) public museBalance;

    constructor(
        IVNFT _vnft,
        IERC20 _muse,
        uint256 _fee
    ) public {
        vnft = _vnft;
        muse = _muse;
        fee = _fee;
        feeRecipient = msg.sender;
    }

    /**
        @dev only allows the function execution when paused=false
     */
    modifier notPaused() {
        require(!paused, "PAUSED");
        _;
    }

    /**
        @dev calculates used gas and burns CHI gas tokens accordingly
     */
    modifier discountCHI {
        uint256 gasStart = gasleft();
        _;

        if (uint256(gasFeed.latestAnswer()) >= minGasPrice) {
            uint256 tokensToBurn = (21000 +
                (gasStart - gasleft()) +
                16 *
                msg.data.length +
                14154) / 41947;

            // if user approved this contract to spend CHI tokens
            if (chi.allowance(msg.sender, address(this)) >= tokensToBurn)
                chi.freeFromUpTo(msg.sender, tokensToBurn);
        }
    }

    /**
        @notice claim MUSE tokens from multiple vNFTs
        @dev contract should be whitelisted as caretaker beforehand
     */
    function claimMultiple(uint256[] memory ids)
        external
        notPaused
        discountCHI
    {
        require(ids.length <= maxIds, "LENGTH");

        for (uint256 i = 0; i < ids.length; i++) {
            require(vnft.ownerOf(ids[i]) == msg.sender, "VNFT:OWNERSHIP");
            vnft.claimMiningRewards(ids[i]);
        }

        // Charge fees
        uint256 feeAmt = muse.balanceOf(address(this)).mul(fee).div(100000);
        require(muse.transfer(feeRecipient, feeAmt));

        // Send rest to user
        require(muse.transfer(msg.sender, muse.balanceOf(address(this))));
    }

    function _checkAmount(uint256[] memory _itemIds)
        public
        view
        returns (uint256 totalAmt)
    {
        for (uint256 i = 0; i < _itemIds.length; i++) {
            totalAmt = totalAmt.add(vnft.itemPrice(_itemIds[i]));
        }
    }

    /**
        @notice feed multiple vNFTs with items/gems
        @dev contract should be whitelisted as caretaker beforehand   
        @dev contract should have MUSE allowance  
     */
    function feedMultiple(uint256[] memory ids, uint256[] memory itemIds)
        external
        notPaused
        discountCHI
    {
        require(ids.length <= maxIds, "Too many ids");
        uint256 museCost = _checkAmount(itemIds);
        require(
            muse.transferFrom(msg.sender, address(this), museCost),
            "MUSE:Items"
        );

        uint256 feeAmt = museCost.mul(fee).div(100000);
        require(
            muse.transferFrom(msg.sender, feeRecipient, feeAmt),
            "MUSE:fee"
        );

        require(muse.approve(address(vnft), museCost), "MUSE:approve");

        for (uint256 i = 0; i < ids.length; i++) {
            vnft.buyAccesory(ids[i], itemIds[i]);
        }
    }

    /**
        @notice start caretaking user vNFTs
        @dev contract should be whitelisted as caretaker beforehand 
     */
    function startCareTaking(uint256[] memory ids)
        external
        notPaused
        discountCHI
    {
        require(ids.length <= maxIds, "LENGTH");

        for (uint256 i = 0; i < ids.length; i++) {
            require(
                vnft.careTaker(ids[i], vnft.ownerOf(ids[i])) == address(this),
                "VNFT: NOT CARETAKER"
            );
            careTakerSet.insert(ids[i]);

            emit StartCareTaker(vnft.ownerOf(ids[i]), ids[i]);
        }
    }

    /**
        @notice stop caretaking user vNFTs
     */
    function stopCareTaking(uint256[] memory ids)
        external
        notPaused
        discountCHI
    {
        require(ids.length <= maxIds, "LENGTH");

        for (uint256 i = 0; i < ids.length; i++) {
            require(
                vnft.careTaker(ids[i], vnft.ownerOf(ids[i])) == address(this),
                "VNFT: NOT CARETAKER"
            );
            careTakerSet.remove(ids[i]);

            emit StopCareTaker(vnft.ownerOf(ids[i]), ids[i]);
        }
    }

    /**
        @dev trigger feed of care taken vNFTs
     */
    function triggerFeed() external onlyOwner discountCHI {
        uint256 totalFee = 0;
        uint256 i;
        for (
            i = nextIndex;
            i <
            (
                careTakerSet.count().sub(nextIndex) > maxIds
                    ? maxIds
                    : careTakerSet.count().sub(nextIndex)
            );
            i++
        ) {
            uint256 _id = careTakerSet.keyAtIndex(i);

            uint256 initialBalance = muse.balanceOf(address(this));
            vnft.claimMiningRewards(_id);
            uint256 halfAmtMined = muse
                .balanceOf(address(this))
                .sub(initialBalance)
                .div(2);

            totalFee = totalFee.add(halfAmtMined);

            // Add balance to user mapping
            museBalance[vnft.ownerOf(_id)] = museBalance[vnft.ownerOf(_id)].add(
                halfAmtMined
            );
        }

        nextIndex = i + 1;

        // Collect 50% of mined MUSE
        require(muse.transfer(feeRecipient, totalFee));
    }

    /**
        @notice claim mined muse by user
     */
    function withdrawMuse() external {
        uint256 toWithdraw = museBalance[msg.sender];
        require(toWithdraw > 0, "ZERO BALANCE");

        museBalance[msg.sender] = 0;

        // Send muse to user
        require(muse.transfer(msg.sender, toWithdraw));
    }

    // OWNER FUNCTIONS

    function setVNFT(IVNFT _vnft) public onlyOwner {
        vnft = _vnft;
    }

    function setMaxIds(uint256 _maxIds) public onlyOwner {
        maxIds = _maxIds;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function setMinGasPrice(uint256 _minGasPrice) public onlyOwner {
        minGasPrice = _minGasPrice;
    }

    function setFeeRecipient(address _feeRecipient) public onlyOwner {
        require(_feeRecipient != address(0));
        feeRecipient = _feeRecipient;
    }

    function setGasFeed(IGasFeed _gasFeed) public onlyOwner {
        gasFeed = _gasFeed;
    }

    function setPause(bool _paused) public onlyOwner {
        paused = _paused;
    }
}
