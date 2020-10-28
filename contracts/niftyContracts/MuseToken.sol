// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract MuseToken is ERC20PresetMinterPauser {
    constructor() public ERC20PresetMinterPauser("Muse Token", "MUSE") {
        _mint(msg.sender, 100e6 * 1 ether);
    }
}
