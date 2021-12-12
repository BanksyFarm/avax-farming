/*
     ,-""""-.
   ,'      _ `.
  /       )_)  \
 :              :
 \              /
  \            /
   `.        ,'
     `.    ,'
       `.,'
        /\`.   ,-._
            `-'         Banksy.farm

 */

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BanksyLockerLiquidity is Ownable {
    using SafeERC20 for IERC20;

    uint256 public immutable UNLOCK_END_BLOCK;

    event Claim(IERC20 banksyToken, address to);


    /**
     * @notice Constructs the Banksy contract.
     */
    constructor(uint256 blockNumber) {
        UNLOCK_END_BLOCK = blockNumber;
    }

    /**
     * @notice claimSanManLiquidity
     * claimbanksyToken allows the banksy Team to send banksy Liquidity to the new delirum kingdom.
     * It is only callable once UNLOCK_END_BLOCK has passed.
     * Banksy Liquidity Policy: https://docs.banksy.farm/token-info/banksy-token/liquidity-lock-policy
     */

    function claimSanManLiquidity(IERC20 banksyLiquidity, address to) external onlyOwner {
        require(block.number > UNLOCK_END_BLOCK, "Banksy is still dreaming...");

        banksyLiquidity.safeTransfer(to, banksyLiquidity.balanceOf(address(this)));

        emit Claim(banksyLiquidity, to);
    }
}