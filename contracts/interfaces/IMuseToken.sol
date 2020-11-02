pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMuseToken is IERC20 {
    function decreaseAllowance(address, uint256) external returns (bool);
}
