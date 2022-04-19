// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MarketPlace {
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // State
    //////////////////////////////////////////////////////////////////////////////////////////////////

    IERC20 s_token; 
    IERC721 s_NFTs;

    enum Status {
        open,
        cancelled,
        executed
    }

    struct Sale {
        address owner;
        uint256 nftID;
        uint256 price;
        Status status;
    }

    mapping(uint256 => Sale) public s_sales;
    mapping(uint256 => uint256) s_refNFTs;
    mapping(uint256 => uint256) s_securty;

    using Counters for Counters.Counter;
    Counters.Counter s_counter;

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Modifiers
    //////////////////////////////////////////////////////////////////////////////////////////////////

    modifier securityFrontRunning(uint256 p_nftID) {
        require(
            s_securty[p_nftID] == 0 ||
            s_securty[p_nftID] > block.number,
            "Error security"
        );

        s_securty[p_nftID] = block.number;

        _;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Constructor
    //////////////////////////////////////////////////////////////////////////////////////////////////

    constructor (address p_stableCoinUsdContract, address p_nftsContract) {
        s_token = IERC20(p_stableCoinUsdContract);
        s_NFTs = IERC721(p_nftsContract);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Public functions
    //////////////////////////////////////////////////////////////////////////////////////////////////

    function openSale(uint256 p_nftID, uint256 p_price) public securityFrontRunning(p_nftID) {
        if (s_refNFTs[p_nftID] == 0) {
            s_NFTs.transferFrom(msg.sender, address(this), p_nftID);

            s_counter.increment();
            s_sales[s_counter.current()] = Sale(
                msg.sender,
                p_nftID,
                p_price,
                Status.open
            );

            s_refNFTs[p_nftID] = s_counter.current();
        } else {
            uint256 pos = s_refNFTs[p_nftID];

            require(
                msg.sender == s_sales[pos].owner,
                "Not allowed"
            );

            s_NFTs.transferFrom(msg.sender, address(this), p_nftID);

            s_sales[pos].status = Status.open;
            s_sales[pos].price = p_price;
        }
    }

    function cancelTrade(uint256 p_nftID) public  securityFrontRunning(p_nftID) {
        uint256 pos = s_refNFTs[p_nftID];

        require(
            msg.sender == s_sales[pos].owner,
            "Not allowed"
        );

        require(s_sales[pos].status == Status.open, "Is not Open");

        s_sales[pos].status = Status.cancelled;

        s_NFTs.transferFrom(address(this), s_sales[pos].owner, p_nftID);
    }



    function buy(uint256 p_nftID) public  securityFrontRunning(p_nftID) {
        uint256 pos = s_refNFTs[p_nftID];

        require(s_sales[pos].status == Status.open, "Is not Open");

        address oldOwner = s_sales[pos].owner;
        uint256 price = s_sales[pos].price;

        s_sales[pos].owner = msg.sender;
        s_sales[pos].status = Status.executed;

        require(s_token.transferFrom(msg.sender, oldOwner, price), "Error transfer token");
        require(s_token.transferFrom(msg.sender, address(this), (price / 100) * 3), "Error transfer token"); // fee 3%

        s_NFTs.transferFrom(address(this), msg.sender, p_nftID);
    }


}