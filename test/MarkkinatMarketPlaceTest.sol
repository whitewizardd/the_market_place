// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {MarkkinatMarketPlace} from "src/contracts/MarkkinatMarketPlace.sol";
import { CollectionNFT } from "src/contracts/CollectionNFT.sol";
import { LibMarketPlaceErrors } from "src/lib/LibMarketplace.sol";
import { Token } from "src/contracts/Token.sol";

contract MarkkinatMarketPlaceTest is Test {
    MarkkinatMarketPlace private marketPlace;
    CollectionNFT private collectionNft;
    Token private tokenUsed;
    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);
    address D = address(0xd);


    function setUp() external {
        marketPlace = new MarkkinatMarketPlace(address(1), address(2));
        collectionNft = new CollectionNFT("", "", "", "", A);
        tokenUsed = new Token("", "");
        fundUserEth(A);
        fundUserEth(B);
        fundUserEth(C);
        fundUserEth(D);
        fundUserEth(address(marketPlace));
    }

    function fundUserEth(address userAdress) private {
        switchSigner(userAdress);
        tokenUsed.runMint();
        vm.deal(address(userAdress), 1 ether);
    }

    function runCreateListing() private returns(MarkkinatMarketPlace.ListingParameters memory){
        collectionNft.mint(A);
        MarkkinatMarketPlace.ListingParameters memory params;
        params.assetContract = address(collectionNft);
        params.tokenId = 1;
        params.quantity = 1;
        params.currency = address(tokenUsed);
        params.price = 1 ether;
        params.startTimestamp = uint128(block.timestamp);
        params.endTimestamp = uint128(block.timestamp + 30 minutes);
        params.reserved = true;
        params.tokenType = MarkkinatMarketPlace.TokenType.ERC721;
        params.intiator = A;
        return params;
    }

    function runCreateAuction() private returns(MarkkinatMarketPlace.AuctionParameters memory) {
        collectionNft.mint(A);
        MarkkinatMarketPlace.AuctionParameters memory params;
        params.assetContract = address(collectionNft);
        params.tokenId = 1;
        params.currency = address(tokenUsed);
        params.minimumBidAmount = 1 ether;
        params.buyoutBidAmount = 1.9 ether;
        params.startTimestamp = uint128(block.timestamp);
        params.endTimestamp = 2 days;
        params.tokenType = MarkkinatMarketPlace.TokenType.ERC721;
        return params;
    }

    function testCreateListing() external {
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        vm.stopPrank();
        marketPlace.createListing(params);

        assertEq(marketPlace.totalListings(), 1);
        assertEq(marketPlace.getListing(0).listingId, 0);
    }

    function testthrowsErrorWhenTheTokenIsNotERC721() external {
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        params.tokenType = MarkkinatMarketPlace.TokenType.ERC1155;
        vm.expectRevert(LibMarketPlaceErrors.InvalidCategory.selector);
        marketPlace.createListing(params);
    }

    function testParamsListOnTime() external {
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        vm.warp(1 hours);
        params.startTimestamp = uint128(block.timestamp);
        vm.expectRevert(LibMarketPlaceErrors.InvalidTime.selector);
        marketPlace.createListing(params);
    }

    function testThatAssetContractMustBeAContract() external {
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        params.assetContract = address(0xab);
        vm.expectRevert(LibMarketPlaceErrors.MustBeContract.selector);
        marketPlace.createListing(params);
    }

    function testThatOnlyAssetOwnerCanListAsset() external {
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        params.tokenId = 2;
        vm.expectRevert();
        marketPlace.createListing(params);
    }

    function testThatMarketPlaceMustBeApprovedBeforeBeforeListingCanBeCreated() external {
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();

        vm.expectRevert();
        marketPlace.createListing(params);
    }

    function testCancelListing() external {
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        vm.stopPrank();
        marketPlace.createListing(params);
        switchSigner(A);
        marketPlace.cancelListing(0);
        MarkkinatMarketPlace.Listing memory listed = marketPlace.getListing(0);
        bool isListed = listed.status == MarkkinatMarketPlace.Status.CANCELLED;
        assertTrue(isListed);
    }

    function testThatOnlyOwnerOfListedAssetCancelListing() external {
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        vm.stopPrank();
        marketPlace.createListing(params);
        switchSigner(B);
        vm.expectRevert(LibMarketPlaceErrors.NotOwner.selector);
        marketPlace.cancelListing(0);
    }

    function testUpdateListedAsset() external {
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        vm.stopPrank();
        marketPlace.createListing(params);

        params.price = 2 ether;
        params.currency = address(0xaaaa);

        switchSigner(A);
        marketPlace.updateListing(0, params);

        MarkkinatMarketPlace.Listing memory listed = marketPlace.getListing(0);

        assertEq(listed.price, 2 ether);

    }

    function testThatOnlyListedAssetWithCreatedStatusCanBeUpdated() external{
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        vm.stopPrank();
        marketPlace.createListing(params);

        switchSigner(A);
        marketPlace.cancelListing(0);

        params.price = 1.5 ether;

        vm.expectRevert(LibMarketPlaceErrors.CantUpdateIfStatusNotCreated.selector);
        marketPlace.updateListing(0, params);
    }

    function confirmThatWhenAListingIsCancelledTheAssetIsTransferBackToTheOwner() external{

    }

    function testBuyListing() external{
        switchSigner(A);

        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        params.reserved = false;
        
        vm.stopPrank();

        marketPlace.createListing(params);

        assertTrue(tokenUsed.balanceOf(A) == 3 ether);

        switchSigner(B);
        // tokenUsed.runMint();
        tokenUsed.approve(address(marketPlace), 1 ether);

        marketPlace.buyFromListing(0, B, address(tokenUsed), 1 ether);

        bool ownerBalance = tokenUsed.balanceOf(A) > 0.8 ether;

        assertTrue(ownerBalance);
    }

    function testBuyListedAsset() external {
        switchSigner(A);
        MarkkinatMarketPlace.ListingParameters memory params = runCreateListing();
        collectionNft.approve(address(marketPlace), 1);
        params.reserved = false;
        // vm.stopPrank();

        marketPlace.createListing(params);

        switchSigner(B);
        // tokenUsed.runMint();
        tokenUsed.approve(address(marketPlace), 1 ether);
        assertEq(tokenUsed.balanceOf(B), 3 ether);
        console.log(tokenUsed.balanceOf(B));
        marketPlace.buyFromListing(0, B, address(tokenUsed), 1 ether);

        bool buyerBalance = tokenUsed.balanceOf(B) == 2 ether;
        MarkkinatMarketPlace.Listing memory listed = marketPlace.getListing(0);

        bool isCompleted = listed.status == MarkkinatMarketPlace.Status.COMPLETED;

        assertEq(collectionNft.ownerOf(listed.tokenId), B);
        assertTrue(buyerBalance);
        assertTrue(isCompleted);
    }

    function testCreateAuctionWithUnsupportedTokenType() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();
        params.tokenType = MarkkinatMarketPlace.TokenType.ERC1155;
        vm.expectRevert(LibMarketPlaceErrors.InvalidCategory.selector);
        marketPlace.createAuction(params);
    }

    function testAuctionCannotBeCreatedWithInValidStartTime() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();
        params.startTimestamp = 2 days;

        vm.expectRevert(LibMarketPlaceErrors.InvalidTime.selector);
        marketPlace.createAuction(params);
    }

    function onlyAssetOwnerCanCreateAuctionOnThatParticularAsset() external {
        switchSigner(B);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();

        vm.expectRevert(LibMarketPlaceErrors.NotOwner.selector);
        marketPlace.createAuction(params);
    }

    function testMarketPlaceNeedsToApprovedForThatParticularAssetSoAuctionCanBeCreated() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();

        vm.expectRevert(LibMarketPlaceErrors.MarketPlaceNotApproved.selector);
        marketPlace.createAuction(params);
    }

    function testCreateAuction() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();

        collectionNft.approve(address(marketPlace), 1);

        marketPlace.createAuction(params);

        MarkkinatMarketPlace.Auction memory auction = marketPlace.getAuction(0);

        bool createdAuctionStatus = auction.status == MarkkinatMarketPlace.Status.CREATED;
        assertEq(auction.auctionCreator, A);
        assertEq(auction.endTimestamp, 2 days);
        assertEq(collectionNft.ownerOf(1), address(marketPlace));
        assertTrue(createdAuctionStatus);
    }

    function testAuctionCancellation() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();
        collectionNft.approve(address(marketPlace), 1);
        marketPlace.createAuction(params);

        switchSigner(B);
        vm.expectRevert(LibMarketPlaceErrors.NotOwner.selector);
        marketPlace.cancelAuction(0);
    }

    function testBidInAuctionCanOnlyBeDoneWhenCurrentTimeIsLessThanTheEndTime() external{
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();
        collectionNft.approve(address(marketPlace), 1);
        marketPlace.createAuction(params);


        switchSigner(B);
        vm.warp(3 days);

        vm.expectRevert(LibMarketPlaceErrors.AuctionEnded.selector);
        marketPlace.bidInAuction(B, 0, 1 ether);
    }

    function testBidAuction() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();
        collectionNft.approve(address(marketPlace), 1);
        marketPlace.createAuction(params);

        switchSigner(C);
        tokenUsed.approve(address(marketPlace), 2 ether);
//        vm.stopPrank();
        marketPlace.bidInAuction(C, 0, 2 ether);

        MarkkinatMarketPlace.Auction memory auction = marketPlace.getAuction(0);

        assertEq(auction.auctionCreator, A);

        bool isCompleted = auction.status == MarkkinatMarketPlace.Status.COMPLETED;

        vm.warp(5 minutes);
        switchSigner(A);
        marketPlace.collectAuctionPayout(0);

//        switchSigner(C);
        vm.expectRevert("Asset Already Claimed");
        marketPlace.claimAuction(C, 0);

        assertEq(collectionNft.ownerOf(1), C);
        assertTrue(isCompleted);
        assertTrue(tokenUsed.balanceOf(A) > 4.8 ether);
    }

    function testBidAuctionMultipleWays() external {
        switchSigner(A);
        MarkkinatMarketPlace.AuctionParameters memory params = runCreateAuction();
        collectionNft.approve(address(marketPlace), 1);

        marketPlace.createAuction(params);

        switchSigner(C);
        tokenUsed.approve(address(marketPlace), 1.3 ether);
//        vm.stopPrank();
        marketPlace.bidInAuction(C, 0, 1.3 ether);

        uint day = 1 days + 23 hours + 59 minutes + 59 seconds;
        vm.warp(day);

        switchSigner(B);
        tokenUsed.approve(address(marketPlace), 1.4 ether);
//        vm.stopPrank();
        marketPlace.bidInAuction(B, 0, 1.4 ether);

        vm.warp(1 days + 23 hours + 61 minutes);
//        switchSigner(B);
        marketPlace.claimAuction(B, 0);

        switchSigner(A);
        marketPlace.collectAuctionPayout(0);

        assertEq(collectionNft.ownerOf(1), B);
        assertTrue(tokenUsed.balanceOf(A) > 4.2 ether);
        assertTrue(tokenUsed.balanceOf(C) > 3 ether);
        assertTrue(tokenUsed.balanceOf(B) >  1.5 ether);

        vm.warp(2.25 days);
        switchSigner(A);
        vm.expectRevert("Double Cliam not permitted");
        marketPlace.collectAuctionPayout(0);
    }

    function switchSigner(address _newSigner) private {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }
}