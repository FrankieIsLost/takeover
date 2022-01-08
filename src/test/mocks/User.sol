// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import { ERC721TokenReceiver } from "solmate/tokens/ERC721.sol";


contract User is ERC721TokenReceiver{

    function onERC721Received(
        address operator, 
        address from,
        uint256 id,
        bytes calldata data
    ) external view returns (bytes4) {
        return this.onERC721Received.selector;
    }

    fallback() external payable {}
}