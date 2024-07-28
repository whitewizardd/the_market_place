// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IMarkkinatNFT} from "../interfaces/IMarkkinatNFT.sol";
import {ERC721} from "@openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {CollectionNFT} from "./CollectionNFT.sol";

contract MarkkinatNFTFactory {
    address private owner;
    IMarkkinatNFT private iMarkkinatNFT;
    uint256 public collectionId;
    mapping(uint256 collId => address contractColl) private collectionsNft;

    constructor(address _owner, address _collection) {
        owner = _owner;
        iMarkkinatNFT = IMarkkinatNFT(_collection);
    }

    function createCollection(
        address _creator,
        string calldata _name,
        string calldata symbol,
        string calldata desc,
        string memory uri
    ) external {
        CollectionNFT newCollection = new CollectionNFT(_name, symbol, desc, uri, _creator);
        collectionsNft[++collectionId] = address(newCollection);
    }
}