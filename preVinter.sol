// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract preVinter is ERC20, ERC20Snapshot, Ownable, Pausable {
    using SafeMath for uint256;

    uint256 public priceWL = 25 * 10**(decimals() - 2);
    uint256 public price = 30 * 10**(decimals() - 2);
    uint256 public minBuy = 100 * 10**decimals();
    uint256 public softCap = 100000 * 10**decimals();
    uint256 public hardCap = 250000 * 10**decimals();

    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint256 public totalRaised;

    mapping(address => bool) public whitelist;
    mapping(address => uint256) public contributionBUSD;

    address public presaleSafe = 0x5F66437fcBeBAC618140620b9Bc768C017b687Aa;
    IERC20 BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    constructor(uint256 _saleStartTime, uint256 _saleEndTime)
        ERC20("preVinter", "pVNTR")
    {
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
    }

    modifier whenSaleActive() {
        require(block.timestamp >= saleStartTime, "Sale has not started");
        require(block.timestamp <= saleEndTime, "Sale has ended");
        _;
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function addWhitelist(address[] memory addresses) external onlyOwner {
        for (uint8 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
    }

    function removeWhitelist(address[] memory addresses) external onlyOwner {
        for (uint8 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
        }
    }

    function updateSaleStartTime(uint256 _saleStartTime) external onlyOwner {
        saleStartTime = _saleStartTime;
    }

    function updateSaleEndTime(uint256 _saleEndTime) external onlyOwner {
        saleEndTime = _saleEndTime;
    }

    function getAllocation() public view returns (uint256) {
        if (block.timestamp < saleStartTime) {
            return 0;
        } else if (block.timestamp.sub(saleStartTime) < 120 minutes) {
            return 5000 * 10**decimals();
        } else {
            return 10000 * 10**decimals();
        }
    }

    function buy(uint256 amountBUSD) external whenSaleActive returns (bool) {
        require(amountBUSD >= minBuy, "Minimum buy amount is 100 $BUSD");
        uint256 salePrice;
        address sender = _msgSender();
        if (block.timestamp.sub(saleStartTime) < 120 minutes) {
            require(
                whitelist[sender],
                "Your address is not Whitelisted for the Whitelist Sale"
            );
            salePrice = priceWL;
        } else {
            salePrice = price;
        }
        BUSD.transferFrom(sender, presaleSafe, amountBUSD);
        contributionBUSD[sender] += amountBUSD;
        totalRaised += amountBUSD;
        _mint(sender, amountBUSD.div(salePrice) * 10**decimals());
        require(
            contributionBUSD[sender] <= getAllocation(),
            "You are crossing your maximum allocation, please reduce the amount and try again"
        );
        require(totalRaised <= hardCap, "Sale is crossing HardCap");
        return true;
    }
}
