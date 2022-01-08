// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import { ERC721 } from "solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721 {

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function tokenURI(uint256) public pure virtual override returns (string memory) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

     function multiMint(address to, uint256[] calldata tokenIds) public {
         for(uint256 i = 0; i < tokenIds.length; i++) {
              _mint(to, tokenIds[i]);
         }
    }
}
