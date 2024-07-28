// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library LibMarketPlaceEvents {
    event CreateListingSucessful(uint256 indexed, address);
    event ListingUpdatedSuccessfully(uint256 indexed, address, uint256);
    event ListingCancelledSuccessfully(uint256 indexed);
    event ApproveListingCurrency(uint256 indexed, address, uint256);
    event BuyListing(uint256 indexed, address indexed, uint256);
    event CreateAuction(uint256, address, uint256);
    event AuctionCompleteBuyout(uint256 indexed, address indexed, uint256);
    event BidSuccessfullyPlaced(uint256 indexed, address indexed, uint256);
    event AuctionCancelledSuccessfully(uint256 indexed);
    event AuctionPayout(uint256 indexed, address indexed, uint256, uint256);
}

library LibMarketPlaceErrors {
    error RecordExists();
    error NotOwner();
    error NotOwnerOrHighestBidder();
    error RecordDoesNotExist();
    error InvalidCategory();
    error InvalidTime();
    error MustBeContract();
    error MarketPlaceNotApproved();
    error CantUpdateIfStatusNotCreated();
    error CantCancelCompletedListing();
    error ListingAlreadyCompleted();
    error CantUpdate();
    error StatusMustBeCreated();
    error NotReservedTokenId();
    error NotReservedAddress();
    error InvalidCurrency();
    error IncorrectPrice();
    error AuctionEnded();
    error AuctionNotStarted();
    error AuctionStillInProgress();
    error InvalidAddress();
    error NoAuction();
}
