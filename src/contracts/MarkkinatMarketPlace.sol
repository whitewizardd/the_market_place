// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import {LibMarketPlaceErrors, LibMarketPlaceEvents} from "../lib/LibMarketplace.sol";
import {console} from "lib/forge-std/src/Test.sol";

// we have two tyoes if listing
// 1. Direct listing & EnglishAuctions
contract MarkkinatMarketPlace is Ownable {
    uint256 auctionIndex;
    uint256 listingIndex;
    address daoAddress;

    Auction[] public allAuctions;
    Listing[] public allListings;

    mapping(uint256 => mapping(address => bool)) private reservedFor;
    mapping(uint256 => mapping(address => uint256)) private reservedForTokenId;

    mapping(uint256 => mapping(address => bool)) private approvedCurrencyForListing;
    mapping(uint256 => mapping(address => uint256)) private approvedCurrencyForAmount;

    mapping(uint256 => bool) public paidAuctionCreator;
    // mapping(uint256 => Listing) public listings;

    enum TokenType {
        ERC721,
        ERC1155
    }

    enum Status {
        CREATED,
        COMPLETED,
        CANCELLED
    }

    struct ListingParameters {
        address assetContract;
        uint256 tokenId;
        uint256 quantity;
        address currency;
        uint256 price;
        uint128 startTimestamp;
        uint128 endTimestamp;
        bool reserved;
        address intiator;
        TokenType tokenType;
    }

    struct Listing {
        uint256 listingId;
        address listingCreator;
        address assetContract;
        uint256 tokenId;
        address currency;
        uint256 price;
        uint128 startTimestamp;
        uint128 endTimestamp;
        bool reserved;
        TokenType tokenType;
        Status status;
    }

    struct AuctionParameters {
        address assetContract;
        uint256 tokenId;
        address currency;
        uint256 minimumBidAmount;
        uint256 buyoutBidAmount;
        uint128 startTimestamp;
        uint128 endTimestamp;
        TokenType tokenType;
    }

    struct Auction {
        uint256 auctionId;
        address auctionCreator;
        address assetContract;
        uint256 tokenId;
        address currency;
        address currentBidOwner;
        uint256 currentBidPrice;
        uint256 minimumBidAmount;
        uint256 buyoutBidAmount;
        uint128 startTimestamp;
        uint128 endTimestamp;
        TokenType tokenType;
        Status status;
        bool paidBuyOutBid;
    }

    constructor(address daoaddress, address initialOwner) payable Ownable(initialOwner) {
        daoAddress = daoaddress;
    }

    modifier isAuctionExpired(uint256 auctionId) {
        if (block.timestamp > allAuctions[auctionId].endTimestamp) {
            revert LibMarketPlaceErrors.AuctionEnded();
        }
        _;
    }

    modifier onlyAfterCompletedAuction(uint256 auctionId) {
        require(isAuctionCompleted(auctionId), "Auction Still In Progress");
        _;
    }

    function isAuctionCompleted(uint256 auctionId) internal view returns (bool) {
        return
            allAuctions[auctionId].endTimestamp <= block.timestamp || allAuctions[auctionId].status == Status.COMPLETED;
    }

    function createListing(ListingParameters memory params) external returns (uint256 listingId) {
        address interactor = params.intiator;
        if (params.tokenType != TokenType.ERC721) {
            revert LibMarketPlaceErrors.InvalidCategory();
        }

        if (params.startTimestamp > block.timestamp || params.startTimestamp >= params.endTimestamp) {
            revert LibMarketPlaceErrors.InvalidTime();
        }

        if (!isContract(params.assetContract)) {
            revert LibMarketPlaceErrors.MustBeContract();
        }

        IERC721 nftCollection = IERC721(params.assetContract);

        // check onwner of nft
        if (nftCollection.ownerOf(params.tokenId) != interactor) {
            revert LibMarketPlaceErrors.NotOwner();
        }

        if (nftCollection.getApproved(params.tokenId) != address(this)) {
            revert LibMarketPlaceErrors.MarketPlaceNotApproved();
        }

        nftCollection.transferFrom(interactor, address(this), params.tokenId);

        Listing memory listing = Listing({
            listingId: listingIndex,
            listingCreator: interactor,
            assetContract: params.assetContract,
            tokenId: params.tokenId,
            currency: params.currency,
            price: params.price,
            startTimestamp: params.startTimestamp,
            endTimestamp: params.endTimestamp,
            reserved: params.reserved,
            tokenType: TokenType.ERC721,
            status: Status.CREATED
        });

        listingIndex++;

        allListings.push(listing);

        // emit event
        emit LibMarketPlaceEvents.CreateListingSucessful(listing.listingId, interactor);

        return listing.listingId;
    }

    function updateListing(uint256 listingId, ListingParameters memory params) external {
        if (params.startTimestamp > block.timestamp || params.startTimestamp >= params.endTimestamp) {
            revert LibMarketPlaceErrors.InvalidTime();
        }
        // get listing
        Listing storage listing = allListings[listingId];

        if (
            listing.listingCreator != msg.sender
        ) {
            revert LibMarketPlaceErrors.NotOwner();
        }

        if (listing.status != Status.CREATED) {
            revert LibMarketPlaceErrors.CantUpdateIfStatusNotCreated();
        }

        listing.currency = params.currency;
        listing.price = params.price;

        // update event
        emit LibMarketPlaceEvents.ListingUpdatedSuccessfully(listingId,listing.currency, listing.price);
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = allListings[listingId];

        if (listing.listingCreator != msg.sender) {
            revert LibMarketPlaceErrors.NotOwner();
        }

        if (listing.status == Status.COMPLETED) {
            revert LibMarketPlaceErrors.CantCancelCompletedListing();
        }

        if (listing.status == Status.CANCELLED) {
            revert LibMarketPlaceErrors.ListingAlreadyCompleted();
        }

        listing.status = Status.CANCELLED;

        // emit event
        emit LibMarketPlaceEvents.ListingCancelledSuccessfully(listingId);
    }

    function approveCurrencyForListing(uint256 listingId, address currency, uint256 priceInCurrency) external {
        Listing storage listing = allListings[listingId];

        if (listing.listingCreator != msg.sender) {
            revert LibMarketPlaceErrors.NotOwner();
        }

        if (listing.status != Status.CREATED) {
            revert LibMarketPlaceErrors.CantUpdateIfStatusNotCreated();
        }

        approvedCurrencyForListing[listingId][currency] = true;
        approvedCurrencyForAmount[listingId][currency] = priceInCurrency;

        // emit event
        emit LibMarketPlaceEvents.ApproveListingCurrency(listingId, currency, priceInCurrency);
    }

    // Get total listings
    function totalListings() external view returns (uint256) {
        return allListings.length;
    }

    function getAllListings() external view returns (Listing[] memory listings) {
        return allListings;
    }

    function getListing(uint256 listingId) external view returns (Listing memory listing) {
        return allListings[listingId];
    }

    function buyFromListing(uint256 listingId, address buyFor, address currency, uint256 expectedTotalPrice)
    external
    payable
        // isAuctionExpired(listingId)
    {
        Listing storage listing = allListings[listingId];

        if (listing.status != Status.CREATED) {
            revert LibMarketPlaceErrors.StatusMustBeCreated();
        }

        if (listing.reserved) {
            if (!reservedFor[listing.listingId][buyFor]) {
                revert LibMarketPlaceErrors.NotReservedAddress();
            }
            if (reservedForTokenId[listingId][buyFor] != listing.tokenId) {
                revert LibMarketPlaceErrors.NotReservedTokenId();
            }
        }

        bool isApprovedCurrency = approvedCurrencyForListing[listingId][currency];
        uint256 approvedCurrencyAmount = approvedCurrencyForAmount[listingId][currency];

        if (listing.currency != currency ) {
            revert LibMarketPlaceErrors.InvalidCurrency();
        }

        if (listing.price != expectedTotalPrice ) {
            revert LibMarketPlaceErrors.IncorrectPrice();
        }

        address currencyToBeUsed = isApprovedCurrency ? currency : listing.currency;
        uint256 priceToBeUsed = approvedCurrencyAmount > 0 ? expectedTotalPrice : listing.price;

        //TODO calculate percentage and remove it.
        uint256 burn = calculateIncentiveBurned(priceToBeUsed);
        uint256 dao = calculateIncentiveDAO(priceToBeUsed);

        // transfer the currency
        IERC20 erc20Token = IERC20(currencyToBeUsed);
        erc20Token.transferFrom(msg.sender, daoAddress, dao);
        erc20Token.transferFrom(msg.sender, listing.assetContract, burn);
        erc20Token.transferFrom(msg.sender, listing.listingCreator, (priceToBeUsed - dao - burn));

        // transfer the nft
        IERC721 nftCollection = IERC721(listing.assetContract);
        nftCollection.safeTransferFrom(address(this), buyFor, listing.tokenId);

        // update the listing status
        listing.status = Status.COMPLETED;

        // emit event
        emit LibMarketPlaceEvents.BuyListing(listingId, msg.sender, priceToBeUsed);
    }

    function createAuction(AuctionParameters memory params) external returns (uint256 auctionId) {
        // wea re taking only erc 721 for now
        if (params.tokenType != TokenType.ERC721) {
            revert LibMarketPlaceErrors.InvalidCategory();
        }

        if (params.startTimestamp > block.timestamp || params.startTimestamp >= params.endTimestamp) {
            revert LibMarketPlaceErrors.InvalidTime();
        }

        if (!isContract(params.assetContract)) {
            revert LibMarketPlaceErrors.MustBeContract();
        }

        IERC721 nftCollection = IERC721(params.assetContract);

        // check onwner of nft
        if (nftCollection.ownerOf(params.tokenId) != msg.sender) {
            revert LibMarketPlaceErrors.NotOwner();
        }

        if (nftCollection.getApproved(params.tokenId) != address(this)) {
            revert LibMarketPlaceErrors.MarketPlaceNotApproved();
        }

        nftCollection.transferFrom(msg.sender, address(this), params.tokenId);

        address payable currentBidOwner = payable(address(0));

        Auction memory auction = Auction({
            auctionId: auctionIndex,
            auctionCreator: msg.sender,
            assetContract: params.assetContract,
            tokenId: params.tokenId,
            currency: params.currency,
            currentBidOwner: currentBidOwner,
            currentBidPrice: 0,
            minimumBidAmount: params.minimumBidAmount,
            buyoutBidAmount: params.buyoutBidAmount,
            startTimestamp: params.startTimestamp,
            endTimestamp: params.endTimestamp,
            tokenType: TokenType.ERC721,
            status: Status.CREATED,
            paidBuyOutBid: false
        });
        paidAuctionCreator[auctionIndex] = false;

        auctionIndex++;

        // push the auction to the array
        allAuctions.push(auction);

        //emit event
        emit LibMarketPlaceEvents.CreateAuction(auction.auctionId, msg.sender, auction.tokenId);

        return auction.auctionId;
    }

    function bidInAuction(address interactor,uint256 auctionId, uint256 bidAmount) external payable isAuctionExpired(auctionId) {
        Auction storage auction = allAuctions[auctionId];

        if (auction.status != Status.CREATED || auction.startTimestamp > block.timestamp) {
            revert LibMarketPlaceErrors.AuctionNotStarted();
        }

        if (auction.endTimestamp <= block.timestamp) {
            revert LibMarketPlaceErrors.AuctionEnded();
        }

        if (bidAmount < auction.minimumBidAmount) {
            revert LibMarketPlaceErrors.IncorrectPrice();
        }

        address previousHighestBidder = auction.currentBidOwner;
        uint256 previousHighestBid = auction.currentBidPrice;

        if (bidAmount >= auction.buyoutBidAmount) {
            // update the auction status
            auction.status = Status.COMPLETED;
            auction.endTimestamp = uint128(block.timestamp);
            auction.paidBuyOutBid = true;

            IERC20 erc20Token = IERC20(auction.currency);
            erc20Token.transferFrom(interactor, address(this), bidAmount);

            // transfer the nft
            IERC721 nftCollection = IERC721(auction.assetContract);
            nftCollection.safeTransferFrom(address(this), interactor, auction.tokenId);

            if (previousHighestBidder != address(0)) {
                // calculate Incentive
                uint256 incentive = calculateIncentiveOutbid(previousHighestBid);
                erc20Token.transfer(previousHighestBidder, previousHighestBid + incentive);
            }
            auction.currentBidOwner = interactor;
            auction.currentBidPrice = bidAmount;
            // emit event
            emit LibMarketPlaceEvents.AuctionCompleteBuyout(auctionId, interactor, bidAmount);
        }

        else if (bidAmount > auction.currentBidPrice) {

            IERC20 erc20Token = IERC20(auction.currency);
            erc20Token.transferFrom(msg.sender, address(this), bidAmount);
            // transfer the currency
            if (previousHighestBidder != address(0)) {
                // calculate Incentive
                uint256 incentive = calculateIncentiveOutbid(previousHighestBid);
                erc20Token.transfer(previousHighestBidder, previousHighestBid + incentive);
            }
            // update the current bid owner
            auction.currentBidOwner = msg.sender;
            auction.currentBidPrice = bidAmount;
            // emit event
            emit LibMarketPlaceEvents.BidSuccessfullyPlaced(auctionId, msg.sender, bidAmount);
        }

        if (block.timestamp >= auction.endTimestamp && auction.status != Status.COMPLETED){
            auction.status = Status.COMPLETED;
        }
    }

    function cancelAuction(uint256 auctionId) external {
        Auction storage auction = allAuctions[auctionId];

        if (auction.auctionCreator != msg.sender) {
            revert LibMarketPlaceErrors.NotOwner();
        }

        if (auction.status == Status.COMPLETED) {
            revert LibMarketPlaceErrors.CantCancelCompletedListing();
        }

        if (auction.status == Status.CANCELLED) {
            revert LibMarketPlaceErrors.ListingAlreadyCompleted();
        }

        if (auction.currentBidOwner != address(0)) {
            revert LibMarketPlaceErrors.AuctionStillInProgress();
        }

        auction.status = Status.CANCELLED;

        // transfer the nft back to the owner
        IERC721 nftCollection = IERC721(auction.assetContract);
        nftCollection.safeTransferFrom(address(this), auction.auctionCreator, auction.tokenId);

        // emit event
        emit LibMarketPlaceEvents.AuctionCancelledSuccessfully(auctionId);
    }

    function claimAuction(address interactor, uint256 auctionId) external {
        Auction storage auction = allAuctions[auctionId];

        require(auction.endTimestamp < block.timestamp, "Deadline not yet met");
        require(!auction.paidBuyOutBid, "Asset Already Claimed");
        require(auction.currentBidOwner == interactor, "Not the last bidder");

        auction.status = Status.COMPLETED;

        IERC721 nftCollection = IERC721(auction.assetContract);
        nftCollection.safeTransferFrom(address(this), interactor, auction.tokenId);
    }

    function collectAuctionPayout(uint256 auctionId) external onlyAfterCompletedAuction(auctionId) {
        Auction storage auction = allAuctions[auctionId];

        // Only owner or highestBidder should claim or finalize auction
        if(msg.sender != auction.auctionCreator) revert LibMarketPlaceErrors.NotOwnerOrHighestBidder();
        require(auction.endTimestamp < block.timestamp, "Auction Not Ended");
        require(!paidAuctionCreator[auctionId], "Double Cliam not permitted");

        paidAuctionCreator[auctionId] = true;
        auction.status = Status.COMPLETED;

        // calculate the dues
        (uint256 burn, uint256 dao, uint256 outbidder) = calculateDues(auction.currentBidPrice);

        //calculate amount to be sent
        uint256 amountToBeSent = auction.currentBidPrice - (burn + dao + outbidder);

        // transfer the currency
        IERC20 erc20Token = IERC20(auction.currency);
        erc20Token.transfer(auction.auctionCreator, amountToBeSent);
        erc20Token.transfer(daoAddress, dao);

        // emit event
        emit LibMarketPlaceEvents.AuctionPayout(auctionId, msg.sender, amountToBeSent, auctionId);
    }

    function isNewWinningBid(uint256 auctionId, uint256 bidAmount) external view returns (bool) {
        Auction storage auction = allAuctions[auctionId];
        return bidAmount > auction.currentBidPrice;
    }

    function totalAuctions() external view returns (uint256) {
        return allAuctions.length;
    }

    function getAuction(uint256 auctionId) external view returns (Auction memory auction) {
        return allAuctions[auctionId];
    }

    function getAllAuctions() external view returns (Auction[] memory auctions) {
        return allAuctions;
    }

    function getWinningBid(uint256 auctionId)
    external
    view
    returns (address bidder, address currency, uint256 bidAmount)
    {
        Auction storage auction = allAuctions[auctionId];
        return (auction.currentBidOwner, auction.currency, auction.currentBidPrice);
    }

    function calculateDues(uint256 bidPrice) private pure returns (uint256, uint256, uint256) {
        uint256 burn = calculateIncentiveBurned(bidPrice);
        uint256 dao = calculateIncentiveDAO(bidPrice);
        uint256 outbidder = calculateIncentiveOutbid(bidPrice);
        return (burn, dao, outbidder);
    }

    function isContract(address _addr) internal view returns (bool addressCheck) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        addressCheck = (size > 0);
    }

    //Get Address of NFt owner
    function getNFTCurrentOwner(address _nftAddress, uint256 _tokenId) private view returns (address) {
        IERC721 nftCollection = IERC721(_nftAddress);
        return nftCollection.ownerOf(_tokenId);
    }

    function onlyNftOwner(address _nftAddress, uint256 _tokenId) private view returns (bool) {
        IERC721 nftCollection = IERC721(_nftAddress);
        return nftCollection.ownerOf(_tokenId) == msg.sender;
    }

    function calculateIncentiveBurned(uint256 _totalFee) private pure returns (uint256) {
        uint256 burned = (_totalFee * 2) / 100;
        return burned;
    }

    // function to amount to be sent to dAO address
    function calculateIncentiveDAO(uint256 _totalFee) private pure returns (uint256) {
        uint256 dao = (_totalFee * 4) / 100;
        return dao;
    }

    // function to amount to be sent to outbid bidder
    function calculateIncentiveOutbid(uint256 _totalFee) private pure returns (uint256) {
        uint256 outbid = (_totalFee * 2) / 100;
        return outbid;
    }
}