// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import { ERC721, ERC721TokenReceiver } from "solmate/tokens/ERC721.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

/// @title NFT Takeover
/// @author @FrankieIsLost
/// @notice A contract to place a bid for a "takeover" of an NFT collection. Bid is valid for a set amount of time, and 
/// succeeds when a pre-specified number of tokens are wrapped in the takeover contract. Once this happens, the original tokens 
/// become permanently locked, and the rewards is paid to the NFT holders. If attempt fails, holders can unwrap their NFTs, 
/// and bidder can remove bid. 
contract Takeover is ERC721, ERC721TokenReceiver {

    /// ------------------------
    /// ----- Parameters -------
    /// ------------------------

    ///@notice token being targeted in takeover 
    ERC721 public immutable token;

    ///@notice bidder intiating takeover attempt
    address public immutable bidder;

    ///@notice takeover bid amount 
    uint256 public bidAmount;

    ///@notice block at which the takeover bid end
    uint256 public bidEndBlock;

    ///@notice number of tokens which must accept takeover for bid to be succesful
    uint256 public successCutoff;

    /// ----------------------
    /// -------- State -------
    /// ----------------------
    
    ///@notice possible states for takeover
    enum TakeoverState { inactive, active, succeeded, failed }
    
    ///@notice current takeover state
    TakeoverState public state;

    ///@notice number of tokens that have accepted takeover 
    uint256 numAcceptances;

    ///@notice mapping used to calculate rewards to tokens that accept bids
    mapping(uint256 => uint256) tokenRewards;

    ///@notice accumulator used to calculate reward payoffs
    uint256 totalRewardBlocks;

    /// ---------------------------
    /// -------- Events -----------
    /// ---------------------------

    event TakeoverStarted(uint256 bidAmount, uint256 bidEndBlock, uint256 successCutoff);

    event TakeoverAccepted(uint256 tokenId);

    event TakeoverFinalized(bool success);

    /// ---------------------------
    /// --------- Errors ----------
    /// ---------------------------

    error Unauthorized();

    error IncorrectState();

    error NotEligibleForRewards();

    error InvalidToken();
 
    constructor(address _token, string memory _name, string memory _symbol) 
    ERC721(_name, _symbol) {
        token = ERC721(_token);
        state = TakeoverState.inactive;
        bidder = msg.sender;
    }

    ///@notice takeover initiator can set bid parameters and move state to active
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

    ///@notice token owners can accept takeover attempt, wrapping token temporarily
    function acceptTakeover(uint256 tokenId) public {
        if(state != TakeoverState.active || block.number > bidEndBlock) {
            revert IncorrectState();
        }
        //transfer original token to contract and mint wrapped token
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        _mint(msg.sender, tokenId);

        //number of blocks for which token is eligible for rewards
        uint256 tokenReward = bidEndBlock - block.number;

        //update state
        tokenRewards[tokenId] = tokenReward;
        totalRewardBlocks += tokenReward;
        numAcceptances += 1;
        emit TakeoverAccepted(tokenId);
    }

    ///@notice takeover can be finalized after specified number of blocks pass 
    function finalizeTakeover() public {
        //can only finalize if state is currently active and block number is larger than takeover end block
        if(state != TakeoverState.active || block.number <= bidEndBlock) {
            revert IncorrectState();
        }
        //update state according to number of tokens that accepted 
        bool sucess = numAcceptances >= successCutoff;
        if (sucess) {
            state = TakeoverState.succeeded;
        }
        else {
            state = TakeoverState.failed;
        }
        emit TakeoverFinalized(sucess);
    }

    ///@notice token owners can unwrap token if takeover attempt fails
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
    
    ///@notice bidder can withdraw bid if takeover attempt fails 
    function withdrawBid() public {
         if(msg.sender != bidder) {
            revert Unauthorized();
        }
        if (state != TakeoverState.failed) {
            revert IncorrectState();
        }
        SafeTransferLib.safeTransferETH(msg.sender, bidAmount);
    }

    ///@notice any original token owner can wrap token if takeover is successful 
    function wrapTokenAfterSuccess(uint256 tokenId) public {
        if (state != TakeoverState.succeeded) {
            revert IncorrectState();
        }
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        _mint(msg.sender, tokenId);
    }

    ///@notice token owners can claim rewards after succesful takeover 
    function claimRewards(uint256 tokenId) public {
        if (state != TakeoverState.succeeded) {
            revert IncorrectState();
        }
        if (tokenRewards[tokenId] == 0) {
            revert NotEligibleForRewards();
        }
        if (msg.sender != this.ownerOf(tokenId) ) {
            revert Unauthorized();
        }
        //calculate proportianal share of rewards
        uint256 rewardAmount = bidAmount * tokenRewards[tokenId] / totalRewardBlocks;
        tokenRewards[tokenId] = 0;
        SafeTransferLib.safeTransferETH(msg.sender, rewardAmount);
    }

    function onERC721Received(
        address operator, 
        address from,
        uint256 id,
        bytes calldata data
    ) external view returns (bytes4) {
        //revert if erc721 is not target token 
        if(msg.sender != address(token)) {
                revert InvalidToken();
        }
        return this.onERC721Received.selector;
    }


    function tokenURI(uint256 id) public view override returns (string memory) {
        return token.tokenURI(id);
    }
}
