// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import { ERC721 } from "solmate/tokens/ERC721.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

contract Takeover is ERC721 {

    enum TakeoverState { inactive, active, succeeded, failed }

    ERC721 token;
    
    TakeoverState state;

    address public bidder;

    ///@notice takeover bid amount 
    uint256 bidAmount;

    ///@notice block at which the takeover bid end
    uint256 bidEndBlock;

    ///@notice number of tokens which must accept takeover for bid to be succesful
    uint256 successCutoff;

    ///@notice number of tokens that have accepted takeover 
    uint256 numAcceptances;

    ///@notice mapping used to calculate rewards to tokens that accept bids
    mapping(uint256 => uint256) tokenRewards;

    ///@notice accumulator used to calculate reward payoffs
    uint256 totalRewardBlocks;

    event TakeoverStarted(uint256 bidAmount, uint256 bidEndBlock, uint256 successCutoff);

    event TakeoverAccepted(uint256 tokenId);

    event TakeoverFinalized(bool success);

    error Unauthorized();

    error IncorrectState();

    error NotEligibleForRewards();
 
    constructor(address _token, string memory _name, string memory _symbol) 
    ERC721(_name, _symbol) {
        token = ERC721(_token);
        state = TakeoverState.inactive;
        bidder = msg.sender;
    }

    function setTakeoverBid(uint256 bidLengthNumBlocks, uint256 _successCutoff) public payable{
        if(msg.sender != bidder) {
            revert Unauthorized();
        }
        if (state != TakeoverState.inactive) {
            revert IncorrectState();
        }
        bidAmount = msg.value;
        bidEndBlock = block.number + bidLengthNumBlocks;
        successCutoff = _successCutoff;
        state = TakeoverState.active;
        emit TakeoverStarted(bidAmount, bidEndBlock, successCutoff);
    }

    //accept takeover attempt, wrapping token temporarily
    function acceptTakeover(uint256 tokenId) public {
        if(state != TakeoverState.active && block.number > bidEndBlock) {
            revert IncorrectState();
        }
        //transfer token to contract
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        //mint wrapped token
        _mint(msg.sender, tokenId);
        //number of blocks for which token is eligible for rewards
        uint256 tokenReward = bidEndBlock - block.number;
        //update state
        tokenRewards[tokenId] = tokenReward;
        totalRewardBlocks += tokenReward;
        numAcceptances += 1;
        emit TakeoverAccepted(tokenId);
    }

    function finalizeTakeover() public {
        //can only finalize if state is currently active and block number is larger than takeover end block
        if(state != TakeoverState.active || block.number <= bidEndBlock) {
            revert IncorrectState();
        }
        bool sucess = numAcceptances >= successCutoff;
        if (sucess) {
            state = TakeoverState.succeeded;
        }
        else {
            state = TakeoverState.failed;
        }
        emit TakeoverFinalized(sucess);
    }

    //unwrap token if takeover attempt fails
    function unwrapToken(uint256 tokenId) public {
        if (state != TakeoverState.failed) {
            revert IncorrectState();
        }
        if (msg.sender != this.ownerOf(tokenId)) {
            revert Unauthorized();
        }
        //unwrap
        _burn(tokenId);
        token.safeTransferFrom(address(this), msg.sender, tokenId);
    }
    
    //withdraw bid if takeover attempt fails 
    function withdrawBid() public {
         if(msg.sender != bidder) {
            revert Unauthorized();
        }
        if (state != TakeoverState.failed) {
            revert IncorrectState();
        }
        SafeTransferLib.safeTransferETH(msg.sender, bidAmount);
    }

    //any owner can wrap token if takeover is successful 
    function wrapTokenAfterSuccess(uint256 tokenId) public {
        if (state != TakeoverState.succeeded) {
            revert IncorrectState();
        }
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        _mint(msg.sender, tokenId);
    }

    //claim rewards after succesful takeover 
    function claimRewards(uint256 tokenId) public {
        if (state != TakeoverState.succeeded) {
            revert IncorrectState();
        }
        if (tokenRewards[tokenId] == 0) {
            revert NotEligibleForRewards();
        }
        if (msg.sender != token.ownerOf(tokenId) ) {
            revert Unauthorized();
        }

        uint256 rewardAmount = bidAmount * tokenRewards[tokenId] / totalRewardBlocks;
        tokenRewards[tokenId] = 0;
        SafeTransferLib.safeTransferETH(msg.sender, rewardAmount);
    }


    function tokenURI(uint256 id) public view override returns (string memory) {
        return token.tokenURI(id);
    }
}
