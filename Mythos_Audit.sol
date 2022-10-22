// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Mythos is ERC721, ERC721Enumerable, Pausable, Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    
    address public constant GameDevWallet = 0x45ce3ce7b4327EA4597CA6674168455155cEE79E; // address will be changed to dedicated multisig
    address public constant FantomLotteryWallet = 0x45ce3ce7b4327EA4597CA6674168455155cEE79E; // address will be changed to dedicated multisig
    uint public MythosPrice = 300 ether;
    uint public constant GameDevFee = 60;    
    uint public constant GiveawayLimit = 142;
    uint public constant MaxSupply = 10000;
    IERC20 public acceptedPayment = IERC20(0x02aB647b676E7534DB5cF896Fe38b710224dBAaC);
    string public baseURI;
    string public baseExtension = ".json";
    string public notRevealedUri;
    bool public revealed = false;
    bool public onlyAllowlisted = true;
    mapping(address => bool) public allowlistedAddresses;
    Counters.Counter private _tokenIdCounter;

    event setBulkAllowlistEvent(address executedBy, address[] addressArray);
    event setSingleAllowlistEvent(address executedBy, address addressAllowed);
    event removeSingleAllowlistEvent(address executedBy, address addressRemoved);
    event setOnlyAllowlistedEvent(address executedBy, bool state);
    event setBaseURIEvent(address executedBy, string newURI);
    event setBaseExtensionEvent(address executedBy, string newExtension);
    event setNotRevealedURIEvent(address executedBy, string newURI);
    event revealEvent(address executedBy, bool state);

    constructor() ERC721("Mythos", "MYTH") { }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _unrevealedURI() internal view virtual returns (string memory) {
        return notRevealedUri;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function changePrice(uint256 _newPrice) external onlyOwner {
        MythosPrice = _newPrice;
    }

    function changeAcceptedPayment(address _newToken) external onlyOwner {
        require(_newToken != address(0));
        acceptedPayment = IERC20(_newToken);
    }

    function preMint(uint256 _mintAmount) external onlyOwner {
        require(_tokenIdCounter.current() + _mintAmount <= MaxSupply, "Max supply exceeded!");
        require(_tokenIdCounter.current() + _mintAmount <= GiveawayLimit, "Premint limit reach");
        _mintLoop(msg.sender, _mintAmount);
    }

    function mint(uint256 _mintAmount) external payable whenNotPaused {
        if (onlyAllowlisted) {
            require(allowlistedAddresses[msg.sender], "Not allowlisted!");
        }
        require(_mintAmount <= 10, "Max 10 per transaction");
        require(_tokenIdCounter.current() + _mintAmount <= MaxSupply, "Max supply exceeded!");
        uint256 amountToPay = MythosPrice * _mintAmount;
        require(acceptedPayment.allowance(msg.sender, address(this)) >= amountToPay && acceptedPayment.balanceOf(msg.sender) >= amountToPay, "Insufficient acceptedPayment allowance or funds");
        acceptedPayment.safeTransferFrom(msg.sender, address(this), amountToPay);
        uint256 ToGameDev = (amountToPay * GameDevFee) / 100;
        uint256 ToGiveaways = amountToPay - ToGameDev;
        acceptedPayment.safeTransfer(GameDevWallet, ToGameDev);
        acceptedPayment.safeTransfer(FantomLotteryWallet, ToGiveaways);
        _mintLoop(msg.sender, _mintAmount);
    }

    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            _tokenIdCounter.increment();
            _safeMint(_receiver, _tokenIdCounter.current());           
        }
    }

    function setBulkAllowlist(address[] calldata _addressArray) external onlyOwner {       
        for (uint256 i = 0; i < _addressArray.length; i++) {
            allowlistedAddresses[_addressArray[i]] = true;
        }
        emit setBulkAllowlistEvent(msg.sender, _addressArray);
    }

    function setSingleAllowlist(address _address) external onlyOwner {
        allowlistedAddresses[_address] = true;
        emit setSingleAllowlistEvent(msg.sender, _address);
    }

    function removeSingleAllowlist(address _address) external onlyOwner {
        allowlistedAddresses[_address] = false;
        emit removeSingleAllowlistEvent(msg.sender, _address);
    }

    function setOnlyAllowlisted(bool _state) external onlyOwner {
        onlyAllowlisted = _state;
        emit setOnlyAllowlistedEvent(msg.sender, _state);
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
        emit setBaseURIEvent(msg.sender, _newBaseURI);
    }

    function setBaseExtension(string memory _newBaseExtension) external onlyOwner {
        baseExtension = _newBaseExtension;
        emit setBaseExtensionEvent(msg.sender, _newBaseExtension);
    }
    
    function setNotRevealedURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedUri = _notRevealedURI;
        emit setNotRevealedURIEvent(msg.sender, _notRevealedURI);
    }

    function reveal(bool _state) external onlyOwner {
        revealed = _state;
        emit revealEvent(msg.sender, _state);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
        if (revealed) {
            string memory currentBaseURI = _baseURI();
            return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)) : "";
        } else {
            string memory currentNotRevealedURI = _unrevealedURI();
            return bytes(currentNotRevealedURI).length > 0 ? string(abi.encodePacked(notRevealedUri, tokenId.toString(), baseExtension)) : "";
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
