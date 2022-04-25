// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IGovernor} from "openzeppelin-contracts/governance/IGovernor.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC4626, ERC20, IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import {Votes, EIP712} from "openzeppelin-contracts/governance/utils/Votes.sol";

/**
 * @dev Extension of ERC4626 which allows for voting based on an account's underlying asset balance
 */
contract MaliciousERC4626Votes is ERC4626, Votes {
    constructor(IERC20Metadata _asset)
        ERC4626(_asset)
        ERC20("Malicious Token Vault", "mvaTOK")
        EIP712("ERC4626Votes", "v1.0")
    {}

    /**
     * @dev Adjusts votes when tokens are transferred.
     *
     * Emits a {Votes-DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        _transferVotingUnits(from, to, amount);
        super._afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Returns the underlying asset balance of `account` which can be used by Governor
     */
    function _getVotingUnits(address account)
        internal
        virtual
        override
        returns (uint256)
    {
        return convertToAssets(balanceOf(account));
    }

    // These functions try to vote as the vault, shouldn't be allowed by governance

    function tryToDelegateVotes() public {
      Votes(asset()).delegate(address(this));
    }

    function tryToCastVote(IGovernor governor, uint256 proposalId, uint8 support) public {
      governor.castVote(proposalId, support);
    }
}
