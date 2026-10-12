// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { MockERC4626Lossy } from "./mocks/MockERC4626Lossy.sol";
import { MockUSDC3009 } from "./mocks/MockUSDC3009.sol";
import { MockUptimeFeed } from "./mocks/MockUptimeFeed.sol";

contract MocksTest is Test {
    MockUSDC3009 internal usdc;
    MockERC4626Lossy internal vault;
    address internal alice = makeAddr("alice");

    function setUp() public {
        usdc = new MockUSDC3009();
        vault = new MockERC4626Lossy(usdc, "Lossy Vault", "lUSDC");
        usdc.mint(alice, 1_000e6);
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
    }

    // - MockERC4626Lossy -

    function test_vaultDonateRaisesTheSharePrice() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100e6, alice);
        usdc.mint(address(this), 10e6);
        usdc.approve(address(vault), 10e6);
        vault.donate(10e6);
        assertApproxEqAbs(vault.convertToAssets(shares), 110e6, 1);
        assertEq(vault.totalAssets(), 110e6);
    }

    function test_vaultBurnLowersTheSharePrice() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100e6, alice);
        vault.burnAssets(40e6);
        assertApproxEqAbs(vault.convertToAssets(shares), 60e6, 1);
        assertEq(usdc.balanceOf(vault.BURN()), 40e6);
    }

    function test_vaultMaxWithdrawCap() public {
        vm.prank(alice);
        vault.deposit(100e6, alice);
        assertEq(vault.maxWithdraw(alice), 100e6);
        vault.setMaxWithdraw(30e6);
        assertEq(vault.maxWithdraw(alice), 30e6);
        assertLe(vault.convertToAssets(vault.maxRedeem(alice)), 30e6);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(31e6, alice, alice);
        vm.prank(alice);
        vault.withdraw(30e6, alice, alice);
        vault.setMaxWithdraw(type(uint256).max);
        assertEq(vault.maxWithdraw(alice), 70e6);
    }

    // - MockUSDC3009 -

    function _digest(bytes32 typehash, address from, address to, uint256 value, uint256 va, uint256 vb, bytes32 nonce)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(typehash, from, to, value, va, vb, nonce));
        return keccak256(abi.encodePacked("\x19\x01", usdc.DOMAIN_SEPARATOR(), structHash));
    }

    function test_receiveWithAuthorization() public {
        (address signer, uint256 pk) = makeAddrAndKey("member");
        usdc.mint(signer, 50e6);
        address desk = makeAddr("desk");
        bytes32 nonce = keccak256("drawId");
        bytes32 d = _digest(usdc.RECEIVE_WITH_AUTHORIZATION_TYPEHASH(), signer, desk, 30e6, 0, block.timestamp + 1 days, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, d);
        // payee must be the caller
        vm.expectRevert(MockUSDC3009.CallerMustBePayee.selector);
        usdc.receiveWithAuthorization(signer, desk, 30e6, 0, block.timestamp + 1 days, nonce, v, r, s);
        vm.prank(desk);
        usdc.receiveWithAuthorization(signer, desk, 30e6, 0, block.timestamp + 1 days, nonce, v, r, s);
        assertEq(usdc.balanceOf(desk), 30e6);
        assertTrue(usdc.authorizationState(signer, nonce));
        vm.prank(desk);
        vm.expectRevert(MockUSDC3009.AuthorizationAlreadyUsed.selector);
        usdc.receiveWithAuthorization(signer, desk, 30e6, 0, block.timestamp + 1 days, nonce, v, r, s);
    }

    function test_transferWithAuthorizationBytesSignatureAndWindow() public {
        (address signer, uint256 pk) = makeAddrAndKey("member2");
        usdc.mint(signer, 5e6);
        address to = makeAddr("to");
        bytes32 nonce = keccak256("n");
        uint256 vb = block.timestamp + 1000;
        bytes32 d = _digest(usdc.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(), signer, to, 5e6, 10, vb, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, d);
        vm.expectRevert(MockUSDC3009.AuthorizationNotYetValid.selector);
        usdc.transferWithAuthorization(signer, to, 5e6, 10, vb, nonce, abi.encodePacked(r, s, v));
        vm.warp(11);
        usdc.transferWithAuthorization(signer, to, 5e6, 10, vb, nonce, abi.encodePacked(r, s, v));
        assertEq(usdc.balanceOf(to), 5e6);
        bytes32 nonce2 = keccak256("n2");
        bytes32 d2 = _digest(usdc.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(), signer, to, 1, 0, 50, nonce2);
        (v, r, s) = vm.sign(pk, d2);
        vm.warp(60);
        vm.expectRevert(MockUSDC3009.AuthorizationExpired.selector);
        usdc.transferWithAuthorization(signer, to, 1, 0, 50, nonce2, v, r, s);
    }

    function test_wrongSignerRefused() public {
        (, uint256 pk) = makeAddrAndKey("not-the-member");
        address member = makeAddr("member3");
        usdc.mint(member, 5e6);
        bytes32 d = _digest(usdc.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(), member, alice, 5e6, 0, block.timestamp + 10, bytes32(uint256(1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, d);
        vm.expectRevert(MockUSDC3009.InvalidSignature.selector);
        usdc.transferWithAuthorization(member, alice, 5e6, 0, block.timestamp + 10, bytes32(uint256(1)), v, r, s);
    }

    function test_blacklistBlocksOnlyTheListedParty() public {
        address bad = makeAddr("bad");
        address good = makeAddr("good");
        usdc.mint(address(this), 10e6);
        usdc.setBlacklisted(bad, true);
        vm.expectRevert(abi.encodeWithSelector(MockUSDC3009.Blacklisted.selector, bad));
        usdc.transfer(bad, 1e6);
        usdc.transfer(good, 1e6);
        assertEq(usdc.balanceOf(good), 1e6);
        assertEq(usdc.decimals(), 6);
    }

    // - MockUptimeFeed -

    function test_feedUpDownRecoveredRevert() public {
        vm.warp(1_000_000);
        MockUptimeFeed feed = new MockUptimeFeed();
        (, int256 answer, uint256 startedAt,,) = feed.latestRoundData();
        assertEq(answer, 0);
        assertGt(startedAt, 0);
        feed.setDown();
        (, answer, startedAt,,) = feed.latestRoundData();
        assertEq(answer, 1);
        assertEq(startedAt, 1_000_000);
        feed.setUp(1_000_500);
        (, answer, startedAt,,) = feed.latestRoundData();
        assertEq(answer, 0);
        assertEq(startedAt, 1_000_500);
        feed.setReverting(true);
        vm.expectRevert(MockUptimeFeed.FeedUnavailable.selector);
        feed.latestRoundData();
        feed.setReverting(false);
        feed.setStartedAt(0);
        (, , startedAt,,) = feed.latestRoundData();
        assertEq(startedAt, 0);
    }
}
