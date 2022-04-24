// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketPlace is Ownable {
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
        Status status;
        uint256 price;
    }

    mapping(uint256 => Sale) public s_sales;
    mapping(uint256 => uint256) s_securty;

    //////////////////////////////////////////////////////////////////////////////////////////////////
    // Modifiers
    //////////////////////////////////////////////////////////////////////////////////////////////////

    modifier securityFrontRunning(uint256 p_nftID) {
        require(
            s_securty[p_nftID] == 0 ||
            s_securty[p_nftID] < block.number,
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
        if (s_sales[p_nftID].owner == address(0)) {
            s_NFTs.transferFrom(msg.sender, address(this), p_nftID);

            s_sales[p_nftID] = Sale(
                msg.sender,
                Status.open,
                p_price
            );
        } else {
            require(
                msg.sender == s_sales[p_nftID].owner,
                "Without permission"
            );

            s_NFTs.transferFrom(msg.sender, address(this), p_nftID);

            s_sales[p_nftID].status = Status.open;
            s_sales[p_nftID].price = p_price;
        }
    }

    function cancelSale(uint256 p_nftID) public securityFrontRunning(p_nftID) {
        require(
            msg.sender == s_sales[p_nftID].owner,
            "Without permission"
        );

        require(s_sales[p_nftID].status == Status.open, "Is not Open");

        s_sales[p_nftID].status = Status.cancelled;

        s_NFTs.transferFrom(address(this), s_sales[p_nftID].owner, p_nftID);
    }

    function buy(uint256 p_nftID, uint256 p_price) public  securityFrontRunning(p_nftID) {
        require(s_sales[p_nftID].status == Status.open, "Is not Open");

        address oldOwner = s_sales[p_nftID].owner;
        uint256 price = s_sales[p_nftID].price;
        
        require(price == p_price, "Manipulated price");

        s_sales[p_nftID].owner = msg.sender;
        s_sales[p_nftID].status = Status.executed;

        require(s_token.transferFrom(msg.sender, oldOwner, price), "Error transfer token - price");
        require(s_token.transferFrom(msg.sender, address(this), (price / 100) * 3), "Error transfer fee"); // fee 3%

        s_NFTs.transferFrom(address(this), msg.sender, p_nftID);
    }

    function getFees() public onlyOwner {
        require(
            s_token.transfer(msg.sender, s_token.balanceOf(address(this))),
            "Error transfer total fees"
        );
    }
}
