// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import { DSTest } from "ds-test/test.sol";
import { MockERC721 } from "./mocks/MockERC721.sol";
import { User } from "./mocks/User.sol";
import { Takeover } from "../Takeover.sol";

interface Vm {
    function roll(uint256) external;
    function deal(address, uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert(bytes calldata) external;
}
 

contract TakeoverTest is DSTest {

    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    MockERC721 mockERC721;
    Takeover takeover;

    uint256 bidAmount = 90 ether;
    uint256 successCutoff = 3;
    uint256 bidNumBlocks = 100;
    
    User user1 = new User();
    User user2 = new User();

    mapping(address => uint256[]) tokenIds;

    //encodings for expectRevert
    bytes incorrectState = abi.encodeWithSignature("IncorrectState()");


    function setUp() public {
        mockERC721 = new MockERC721("NFT", "NFT");
        tokenIds[address(user1)] = [0, 1];
        tokenIds[address(user2)] = [2, 3];

        mockERC721.multiMint(address(user1), tokenIds[address(user1)]);
        mockERC721.multiMint(address(user2), tokenIds[address(user2)]);

        takeover = new Takeover(address(mockERC721), "Takeover", "Takeover");
        vm.deal(address(this), 200 ether);
        takeover.setTakeoverBid{value: bidAmount}(bidNumBlocks, successCutoff);

    }

    function testSetTakeoverBid() public {
        assertEq(takeover.bidAmount(), bidAmount);
        assertEq(takeover.bidEndBlock(), block.number + bidNumBlocks);
    }

    function testAcceptTakeover() public {
        uint256 tokenId = tokenIds[address(user1)][0];
        assertEq(mockERC721.ownerOf(tokenId), address(user1));
        acceptTakeover(user1, tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(takeover));
        assertEq(takeover.ownerOf(tokenId), address(user1));
    }

    function testCanUnwrapAfterFailure() public {
        uint256 tokenId = tokenIds[address(user1)][0];
        acceptTakeover(user1, tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(takeover));
        mineBlocks(bidNumBlocks + 1);
        takeover.finalizeTakeover();
        unwrapToken(user1, tokenId);
        assertEq(mockERC721.ownerOf(tokenId), address(user1));
    }

    function testCanWithdrawAfterFailure() public {
        mineBlocks(bidNumBlocks + 1);
        takeover.finalizeTakeover();
        uint256 initialBidBalance = address(takeover).balance;
        uint256 initialContractBalance = address(this).balance;
        takeover.withdrawBid();
        uint256 finalBidBalance = address(takeover).balance;
        uint256 finalContractBalance = address(this).balance;
        assertEq(initialBidBalance, bidAmount);
        assertEq(finalBidBalance, 0);
        assertEq(initialContractBalance + bidAmount, finalContractBalance);
    }

     function testCannotUnwrapAfterSuccess() public {
        multiAcceptTakeover(user1, tokenIds[address(user1)]);
        multiAcceptTakeover(user2, tokenIds[address(user2)]);
        mineBlocks(bidNumBlocks + 1);
        takeover.finalizeTakeover();
        assertTrue(takeover.state() == Takeover.TakeoverState.succeeded);
        vm.expectRevert(incorrectState);
        unwrapToken(user1, tokenIds[address(user1)][0]);
    }

    function testRewardsArePaidProportionally() public {
        multiAcceptTakeover(user1, tokenIds[address(user1)]);
        multiAcceptTakeover(user2, tokenIds[address(user2)]);
        mineBlocks(bidNumBlocks + 1);
        takeover.finalizeTakeover();
        assertTrue(takeover.state() == Takeover.TakeoverState.succeeded);

        uint256 initialBalance = address(user1).balance;
        claimRewards(user1, tokenIds[address(user1)][0]);
        uint256 finalBalance = address(user1).balance;
        uint256 expectedReward = bidAmount / 4;
        uint256 actualReward = finalBalance - initialBalance;
        assertEq(expectedReward, actualReward);
    }

    function testRewardsArePaidProportionallyOverTime() public {
        multiAcceptTakeover(user1, tokenIds[address(user1)]);
        uint256 tokenId = tokenIds[address(user2)][0];
        mineBlocks(bidNumBlocks / 2);
        acceptTakeover(user2, tokenId);
        mineBlocks(bidNumBlocks);
        takeover.finalizeTakeover();
        assertTrue(takeover.state() == Takeover.TakeoverState.succeeded);
        uint256 initialBalance = address(user2).balance;
        claimRewards(user2, tokenIds[address(user2)][0]);
        uint256 finalBalance = address(user2).balance;
        //expected reward is only 1/5 of bid given block in which takeover offer was accepted 
        uint256 expectedReward = bidAmount / 5;
        uint256 actualReward = finalBalance - initialBalance;
        assertEq(expectedReward, actualReward);
    }

    function claimRewards(User user, uint256 tokenId) private {
        vm.startPrank(address(user));
        takeover.claimRewards(tokenId);(tokenId);
        vm.stopPrank();
    }


    function unwrapToken(User user, uint256 tokenId) private {
        vm.startPrank(address(user));
        takeover.unwrapToken(tokenId);
        vm.stopPrank();
    }

    function multiAcceptTakeover(User user, uint256[] storage tokenIdList) private {
        for(uint256 i = 0; i < tokenIdList.length; i++) {
            acceptTakeover(user, tokenIdList[i]);
        }
    }

    function acceptTakeover(User user, uint256 tokenId) public {
        vm.startPrank(address(user));
        mockERC721.approve(address(takeover), tokenId);
        takeover.acceptTakeover(tokenId);
        vm.stopPrank();
    }

    function mineBlocks(uint256 numBlocks) private {
        uint256 currentBlock = block.number;
        vm.roll(currentBlock + numBlocks);
    }

    fallback() payable external {}
}
