// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Token} from "src/Token.sol";
import {ERC4626Votes} from "src/ERC4626Votes.sol";
import {GovernorERC4626Aware} from "src/GovernorERC4626Aware.sol";

import {MaliciousERC4626Votes} from "./MaliciousERC4626Votes.sol";

contract TestERC4626Votes is Test {
    Token t;
    ERC4626Votes v;
    GovernorERC4626Aware g;

    event ImportantEvent();

    function setUp() public {
        t = new Token();
        v = new ERC4626Votes(t);
        g = new GovernorERC4626Aware("Governance", t, 4, 16, 10);

        // Governor assumes block number is greater than 0, so we set it to 1000 here
        vm.roll(1000);
    }

    function addVaultToGovernance(address _vault) internal {
        // Setup our tokens for voting
        t.delegate(address(this));
        assertEq(t.delegates(address(this)), address(this));

        // Add proposal to add the vault as another governance token
        address[] memory targets = new address[](1);
        targets[0] = address(g);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(g.addVaultForVoting, address(_vault));

        string memory description = "Add Vault to governance";

        uint256 proposalId = g.propose(targets, values, calldatas, description);

        // Cast our vote For the proposal
        vm.roll(block.number + 1 + g.votingDelay());
        g.castVote(proposalId, 1);

        // Execute the proposal
        vm.roll(block.number + 1 + g.votingPeriod());
        g.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function testCannotCallOnlyGovernanceFunctions() public {
        vm.expectRevert(bytes("Governor: onlyGovernance"));
        g.addVaultForVoting(address(v));

        vm.expectRevert(bytes("Governor: onlyGovernance"));
        g.veryImportantFunction();
    }

    function testCannotAchieveQuorumWithLessThan10Percent() public {
        // Remove 91% of tokens
        t.transfer(address(1), t.balanceOf(address(this)) * 91 / 100);

        // Setup our tokens for voting
        t.delegate(address(this));
        assertEq(t.delegates(address(this)), address(this));

        // Add proposal to add the vault as another governance token
        address[] memory targets = new address[](1);
        targets[0] = address(g);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(g.addVaultForVoting, address(v));

        string memory description = "Add Vault to governance";

        uint256 proposalId = g.propose(targets, values, calldatas, description);

        // Cast our vote For the proposal
        vm.roll(block.number + 1 + g.votingDelay());
        g.castVote(proposalId, 1);

        // Execute the proposal but expect it to revert
        vm.roll(block.number + 1 + g.votingPeriod());
        vm.expectRevert(bytes("Governor: proposal not successful"));
        g.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function testCanAddVaultWithGovernance() public {
        addVaultToGovernance(address(v));

        // Check that vault was added
        assertTrue(g.hasVault(address(v)));
    }

    function testVaultTokenVotingWorks() public {
        // We need to add the vault as a voting token as tests run separately
        addVaultToGovernance(address(v));
        vm.roll(block.number + 1);

        // First, mint some vault tokens
        t.approve(address(v), t.balanceOf(address(this)));
        uint256 depositAmount = v.previewDeposit(t.balanceOf(address(this)));
        v.deposit(t.balanceOf(address(this)), address(this));

        assertEq(t.balanceOf(address(this)), 0);
        assertEq(v.balanceOf(address(this)), depositAmount);

        // Setup our tokens for voting
        v.delegate(address(this));
        assertEq(v.delegates(address(this)), address(this));

        // Add proposal to call some important function
        address[] memory targets = new address[](1);
        targets[0] = address(g);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(g.veryImportantFunction.selector);

        string memory description = "Call very important function";

        uint256 proposalId = g.propose(targets, values, calldatas, description);

        // Cast our vote For the proposal
        vm.roll(block.number + 1 + g.votingDelay());
        g.castVote(proposalId, 1);

        // Execute the proposal and ensure it was called
        vm.roll(block.number + 1 + g.votingPeriod());
        vm.expectEmit(true, true, true, true);
        emit ImportantEvent();
        g.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function testVotePowerCountsBothTokenAndVault() public {
        // We need to add the vault as a voting token as tests run separately
        addVaultToGovernance(address(v));
        vm.roll(block.number + 1);

        uint256 originalVotePower = g.getVotes(address(this), block.number - 1);

        // First, mint some vault tokens
        uint256 balanceToMint = t.balanceOf(address(this)) / 2;
        t.approve(address(v), balanceToMint);
        uint256 depositAmount = v.previewDeposit(balanceToMint);
        v.deposit(balanceToMint, address(this));

        assertEq(t.balanceOf(address(this)), balanceToMint);
        assertEq(v.balanceOf(address(this)), depositAmount);

        // Setup our tokens for voting
        v.delegate(address(this));
        assertEq(v.delegates(address(this)), address(this));
        assertEq(t.delegates(address(this)), address(this));

        vm.roll(block.number + 1);

        uint256 newVotePower = g.getVotes(address(this), block.number - 1);

        assertEq(newVotePower, originalVotePower);
    }

    function testVaultTokenCanVoteToRemoveItself() public {
        // We need to add the vault as a voting token as tests run separately
        addVaultToGovernance(address(v));
        vm.roll(block.number + 1);

        // First, mint some vault tokens
        t.approve(address(v), t.balanceOf(address(this)));
        uint256 depositAmount = v.previewDeposit(t.balanceOf(address(this)));
        v.deposit(t.balanceOf(address(this)), address(this));

        assertEq(t.balanceOf(address(this)), 0);
        assertEq(v.balanceOf(address(this)), depositAmount);

        // Setup our tokens for voting
        v.delegate(address(this));
        assertEq(v.delegates(address(this)), address(this));

        // Add proposal to call some important function
        address[] memory targets = new address[](1);
        targets[0] = address(g);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(g.removeVaultForVoting, address(v));

        string memory description = "Remove vault";

        uint256 proposalId = g.propose(targets, values, calldatas, description);

        // Cast our vote For the proposal
        vm.roll(block.number + 1 + g.votingDelay());
        g.castVote(proposalId, 1);

        // Execute the proposal and ensure it was called
        vm.roll(block.number + 1 + g.votingPeriod());
        g.execute(targets, values, calldatas, keccak256(bytes(description)));

        // Check that vault was removed
        assertFalse(g.hasVault(address(v)));
    }

    function testVaultTokenPowerIncreasesAfterShareValueChanges() public {
        // We need to add the vault as a voting token as tests run separately
        addVaultToGovernance(address(v));
        vm.roll(block.number + 1);

        uint256 votingPowerBeforeVault = g.getVotes(address(this), block.number - 1);

        // First, mint some vault tokens
        t.approve(address(v), t.balanceOf(address(this)));
        uint256 depositAmount = v.previewDeposit(t.balanceOf(address(this)));
        v.deposit(t.balanceOf(address(this)), address(this));

        assertEq(t.balanceOf(address(this)), 0);
        assertEq(v.balanceOf(address(this)), depositAmount);

        // Change the vaults underlying balance with imaginary yield farming
        // so that the shares are not 1:1 and we have more voting power
        t.imaginaryYieldFarm(address(v));
        assertGt(v.convertToAssets(v.balanceOf(address(this))), v.balanceOf(address(this)));

        // Setup our tokens for voting
        v.delegate(address(this));
        assertEq(v.delegates(address(this)), address(this));

        // Check that out voting power has also increases
        vm.roll(block.number + 1);
        uint256 votingPowerAfterVault = g.getVotes(address(this), block.number - 1);
        assertGt(votingPowerAfterVault, votingPowerBeforeVault);

        // Add proposal to call some important function
        address[] memory targets = new address[](1);
        targets[0] = address(g);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(g.veryImportantFunction.selector);

        string memory description = "Call very important function";

        uint256 proposalId = g.propose(targets, values, calldatas, description);

        // Cast our vote For the proposal
        vm.roll(block.number + 1 + g.votingDelay());
        g.castVote(proposalId, 1);

        // Execute the proposal and ensure it was called
        vm.roll(block.number + 1 + g.votingPeriod());
        vm.expectEmit(true, true, true, true);
        emit ImportantEvent();
        g.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function testCannotVoteAsVault() public {
        MaliciousERC4626Votes m = new MaliciousERC4626Votes(t);
        addVaultToGovernance(address(m));

        // Check that vault was added
        assertTrue(g.hasVault(address(m)));

        m.tryToDelegateVotes();
        vm.roll(block.number + 1);

        // Add proposal to call some important function
        address[] memory targets = new address[](1);
        targets[0] = address(g);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(g.veryImportantFunction.selector);

        string memory description = "Call very important function";

        uint256 proposalId = g.propose(targets, values, calldatas, description);

        // Malicious vault cannot vote itself
        vm.roll(block.number + 1 + g.votingDelay());
        vm.expectRevert(bytes("GovernorERC4626Aware: The vault cannot vote with its underlying asset tokens as that would be double voting"));
        m.tryToCastVote(g, proposalId, 1);

        // But users still can
        // Cast our vote For the proposal
        vm.roll(block.number + 1 + g.votingDelay());
        g.castVote(proposalId, 1);

        // Execute the proposal and ensure it was called
        vm.roll(block.number + 1 + g.votingPeriod());
        vm.expectEmit(true, true, true, true);
        emit ImportantEvent();
        g.execute(targets, values, calldatas, keccak256(bytes(description)));
    }
}
