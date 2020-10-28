// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGasFeed.sol";

interface IVNFT {
    function fatality(uint256 _deadId, uint256 _tokenId) external;

    function buyAccesory(uint256 nftId, uint256 itemId) external;

    function claimMiningRewards(uint256 nftId) external;

    function addCareTaker(uint256 _tokenId, address _careTaker) external;

    function careTaker(uint256 _tokenId, address _user)
        external
        view
        returns (address _careTaker);

    function ownerOf(uint256 _tokenId) external view returns (address _owner);

    function itemPrice(uint256 itemId) external view returns (uint256 _amount);
}

contract NiftyTools is Ownable {
    using SafeMath for uint256;

    // External contracts
    IVNFT public vnft;
    IERC20 public muse;
    IGasFeed public gasFeed = IGasFeed(0xA417221ef64b1549575C977764E651c9FAB50141);

    // Contrac Variables
    uint256 public maxIds = 20;
    uint256 public fee;
    address public feeRecipient;
    bool paused;

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

    modifier notPaused() {
        require(!paused, "PAUSED");
        _;
    }

    /**
        @notice claim MUSE tokens from multiple vNFTs
        @dev contract should be whitelisted as caretaker beforehand
     */
    function claimMultiple(uint256[] memory ids) external notPaused {
        require(ids.length <= maxIds, "LENGTH");

        for (uint256 i = 0; i < ids.length; i++) {
            require(vnft.ownerOf(ids[i]) == msg.sender);
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
            require(vnft.ownerOf(ids[i]) == msg.sender);
            vnft.buyAccesory(ids[i], itemIds[i]);
        }
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
