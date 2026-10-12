// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { RelayEnvelopeLib } from "../src/RelayEnvelopeLib.sol";
import { Vectors } from "./Vectors.sol";

/// @dev A contract that calls the library the way a pool contract will: `address(this)` is the destination.
contract EnvelopeHarness {
    function verify(RelayEnvelopeLib.Envelope calldata e, bytes calldata sig, address relayer) external view {
        RelayEnvelopeLib.verify(e, sig, relayer);
    }

    function digest(RelayEnvelopeLib.Envelope calldata e) external pure returns (bytes32) {
        return RelayEnvelopeLib.digest(e);
    }
}

/// @dev An ERC-1271 relayer (a multisig or smart account) that approves one digest.
contract Mock1271Relayer {
    bytes32 public approved;

    function approve(bytes32 d) external {
        approved = d;
    }

    function isValidSignature(bytes32 d, bytes calldata) external view returns (bytes4) {
        return d == approved ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @notice RelayEnvelopeLib (A.7, spec 2.9): the EIP-712 digest equals viem's for every envelope in
///         test/vectors/js/relay-envelope.json, the one-relayer check accepts exactly the right signatures,
///         refuses a wrong destination and a tampered envelope, and accepts an ERC-1271 relayer.
contract RelayEnvelopeLibTest is Vectors {
    uint256 internal constant SECP256K1_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    string internal J;
    EnvelopeHarness internal h;
    address internal relayer;
    address internal dst;

    function setUp() public {
        J = _js("relay-envelope.json");
        relayer = _addr(J, ".relayer");
        dst = _addr(J, ".dstContract");
        vm.chainId(uint256(_uint(J, ".chainId")));
        EnvelopeHarness impl = new EnvelopeHarness();
        vm.etch(dst, address(impl).code);
        h = EnvelopeHarness(dst);
    }

    function _env(string memory base) internal view returns (RelayEnvelopeLib.Envelope memory e) {
        e.dstChainId = _uint(J, string.concat(base, ".dstChainId"));
        e.dstContract = _addr(J, string.concat(base, ".dstContract"));
        e.poolId = _bytes32(J, string.concat(base, ".poolId"));
        e.srcSite = _bytes32(J, string.concat(base, ".srcSite"));
        e.blockNum = uint64(_uint(J, string.concat(base, ".blockNum")));
        e.blockId = _bytes32(J, string.concat(base, ".blockId"));
        e.trxId = _bytes32(J, string.concat(base, ".trxId"));
        e.opIndex = uint32(vm.parseJsonUint(J, string.concat(base, ".opIndex")));
        e.payloadNi = _bytes32(J, string.concat(base, ".payloadNi"));
        e.nonce = uint64(_uint(J, string.concat(base, ".nonce")));
    }

    function _sig(uint256 i) internal view returns (bytes memory) {
        return vm.parseJsonBytes(J, _at(".cases", i, ".signature"));
    }

    function test_typeString() public view {
        assertEq(
            keccak256(bytes(_str(J, ".typeString"))), RelayEnvelopeLib.ENVELOPE_TYPEHASH, "typehash is the twin's type string"
        );
    }

    function test_everyVectorDigestMatches() public view {
        uint256 n = _len(J, ".cases");
        assertEq(n, 8);
        for (uint256 i; i < n; ++i) {
            RelayEnvelopeLib.Envelope memory e = _env(_at(".cases", i, ".envelope"));
            assertEq(h.digest(e), _bytes32(J, _at(".cases", i, ".digest")), _str(J, _at(".cases", i, ".label")));
        }
    }

    function test_everyVectorVerifies() public view {
        uint256 n = _len(J, ".cases");
        for (uint256 i; i < n; ++i) {
            RelayEnvelopeLib.Envelope memory e = _env(_at(".cases", i, ".envelope"));
            bytes32 expect = keccak256(bytes(_str(J, _at(".cases", i, ".expect"))));
            if (expect == keccak256("ok")) {
                h.verify(e, _sig(i), relayer);
            } else {
                bytes4 sel = expect == keccak256("WrongDestination")
                    ? RelayEnvelopeLib.WrongDestination.selector
                    : RelayEnvelopeLib.BadRelayerSignature.selector;
                (bool ok, bytes memory ret) = address(h).staticcall(abi.encodeCall(h.verify, (e, _sig(i), relayer)));
                assertFalse(ok, _str(J, _at(".cases", i, ".label")));
                assertEq(bytes4(ret), sel, _str(J, _at(".cases", i, ".label")));
            }
        }
    }

    function test_chainMustMatchTheRuntime() public {
        RelayEnvelopeLib.Envelope memory e = _env(".cases[0].envelope");
        vm.chainId(1);
        vm.expectRevert(RelayEnvelopeLib.WrongDestination.selector);
        h.verify(e, _sig(0), relayer);
    }

    function test_highSMalleatedSignatureIsRefused() public {
        RelayEnvelopeLib.Envelope memory e = _env(".cases[0].envelope");
        bytes memory sig = _sig(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        bytes memory twin = abi.encodePacked(r, bytes32(SECP256K1_N - uint256(s)), v == 27 ? uint8(28) : uint8(27));
        vm.expectRevert(RelayEnvelopeLib.BadRelayerSignature.selector);
        h.verify(e, twin, relayer);
    }

    function test_truncatedAndEmptySignaturesAreRefused() public {
        RelayEnvelopeLib.Envelope memory e = _env(".cases[0].envelope");
        vm.expectRevert(RelayEnvelopeLib.BadRelayerSignature.selector);
        h.verify(e, hex"", relayer);
        vm.expectRevert(RelayEnvelopeLib.BadRelayerSignature.selector);
        h.verify(e, hex"1234", relayer);
    }

    function test_erc1271RelayerApprovesItsDigest() public {
        RelayEnvelopeLib.Envelope memory e = _env(".cases[0].envelope");
        Mock1271Relayer safe = new Mock1271Relayer();
        vm.expectRevert(RelayEnvelopeLib.BadRelayerSignature.selector);
        h.verify(e, hex"00", address(safe));
        safe.approve(h.digest(e));
        h.verify(e, hex"00", address(safe));
        // a different envelope is not approved
        e.nonce += 1;
        vm.expectRevert(RelayEnvelopeLib.BadRelayerSignature.selector);
        h.verify(e, hex"00", address(safe));
    }

    function testFuzz_anyFieldChangeInvalidatesTheSignature(uint8 which, uint256 delta) public {
        RelayEnvelopeLib.Envelope memory e = _env(".cases[0].envelope");
        delta = bound(delta, 1, type(uint32).max);
        which = uint8(bound(which, 0, 7));
        if (which == 0) e.poolId = bytes32(uint256(e.poolId) ^ delta);
        else if (which == 1) e.srcSite = bytes32(uint256(e.srcSite) ^ delta);
        else if (which == 2) e.blockNum += uint64(delta);
        else if (which == 3) e.blockId = bytes32(uint256(e.blockId) ^ delta);
        else if (which == 4) e.trxId = bytes32(uint256(e.trxId) ^ delta);
        else if (which == 5) e.opIndex += uint32(delta);
        else if (which == 6) e.payloadNi = bytes32(uint256(e.payloadNi) ^ delta);
        else e.nonce += uint64(delta);
        vm.expectRevert(RelayEnvelopeLib.BadRelayerSignature.selector);
        h.verify(e, _sig(0), relayer);
    }
}
