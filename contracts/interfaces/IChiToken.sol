pragma solidity ^0.6.0;

interface IChiToken {
    function approve(address, uint256) external;

    function transfer(address, uint256) external;

    function balanceOf(address account) external view returns (uint256);

    function allowance(address user, address spender)
        external
        view
        returns (uint256);

    function freeUpTo(uint256 value) external returns (uint256 freed);

    function freeFromUpTo(address from, uint256 value)
        external
        returns (uint256 freed);

    function mint(uint256 value) external;
}
