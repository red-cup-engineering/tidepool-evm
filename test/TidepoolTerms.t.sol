// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SignCell } from "@red-cup-engineering/signstuff-evm/SignCell.sol";
import { TidepoolTerms } from "../src/TidepoolTerms.sol";
import { TidepoolPredicates } from "../src/TidepoolPredicates.sol";
import { Vectors } from "./Vectors.sol";

/// @notice Every Solidity term and witness builder equals the JS twin's bytes for every row of
///         test/vectors/js/tidepool-terms.json (TP-EVM-001 acceptance).
contract TidepoolTermsTest is Vectors {
    string internal J;

    function setUp() public {
        J = _js("tidepool-terms.json");
    }

    function test_members() public view {
        uint256 n = _len(J, ".members");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            address a = _addr(J, _at(".members", i, ".address"));
            assertEq(string(TidepoolTerms.memberLabel(a)), _str(J, _at(".members", i, ".label")));
            assertEq(TidepoolTerms.memberTerm(a), _hexBytes(J, _at(".members", i, ".encoded")), "memberTerm");
            assertEq(TidepoolTerms.memberWitness(a), _hexBytes(J, _at(".members", i, ".encoded")), "memberWitness");
            assertEq(
                TidepoolTerms.witnessId(TidepoolTerms.memberWitness(a)), _bytes32NoPrefix(J, _at(".members", i, ".witnessId"))
            );
        }
    }

    function test_sleeves() public view {
        uint256 n = _len(J, ".sleeves");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            address a = _addr(J, _at(".sleeves", i, ".address"));
            assertEq(string(TidepoolTerms.sleeveLabel(a)), _str(J, _at(".sleeves", i, ".label")));
            assertEq(TidepoolTerms.sleeveTerm(a), _hexBytes(J, _at(".sleeves", i, ".encoded")), "sleeveTerm");
        }
    }

    function test_hives() public view {
        uint256 n = _len(J, ".hives");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            string memory account = _str(J, _at(".hives", i, ".account"));
            assertEq(TidepoolTerms.hiveTerm(account), _hexBytes(J, _at(".hives", i, ".encoded")), "hiveTerm");
            assertEq(TidepoolTerms.hiveWitness(account), _hexBytes(J, _at(".hives", i, ".witness")), "hiveWitness");
            assertEq(
                TidepoolTerms.witnessId(TidepoolTerms.hiveWitness(account)), _bytes32NoPrefix(J, _at(".hives", i, ".witnessId"))
            );
        }
    }

    function test_scoped() public view {
        uint256 n = _len(J, ".scoped");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            string memory kind = _str(J, _at(".scoped", i, ".kind"));
            bytes memory label;
            if (keccak256(bytes(kind)) == keccak256("member")) {
                label = TidepoolTerms.memberLabel(_addr(J, _at(".scoped", i, ".arg")));
            } else if (keccak256(bytes(kind)) == keccak256("sleeve")) {
                label = TidepoolTerms.sleeveLabel(_addr(J, _at(".scoped", i, ".arg")));
            } else {
                label = TidepoolTerms.idLabel(kind, _bytes32(J, _at(".scoped", i, ".arg")));
            }
            assertEq(string(label), _str(J, _at(".scoped", i, ".label")), "label");
            assertEq(
                TidepoolTerms.scoped(label, _uint(J, _at(".scoped", i, ".n"))),
                _hexBytes(J, _at(".scoped", i, ".encoded")),
                "scoped"
            );
        }
    }

    function test_ids() public view {
        uint256 n = _len(J, ".ids");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            assertEq(
                TidepoolTerms.idTerm(_bytes32(J, _at(".ids", i, ".id"))), _hexBytes(J, _at(".ids", i, ".encoded")), "idTerm"
            );
        }
    }

    function test_poolCycleSites() public view {
        uint256 n = _len(J, ".poolCycleSites");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            bytes memory got = TidepoolTerms.poolCycleSite(
                _bytes32(J, _at(".poolCycleSites", i, ".poolId")),
                uint64(_uint(J, _at(".poolCycleSites", i, ".cycle"))),
                _str(J, _at(".poolCycleSites", i, ".caip2"))
            );
            assertEq(got, _hexBytes(J, _at(".poolCycleSites", i, ".encoded")), "poolCycleSite");
        }
    }

    function test_amounts() public view {
        uint256 n = _len(J, ".amounts");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            assertEq(
                TidepoolTerms.amountTerm(_uint(J, _at(".amounts", i, ".value"))),
                _hexBytes(J, _at(".amounts", i, ".encoded")),
                "amountTerm"
            );
        }
    }

    function test_signedAmounts() public view {
        uint256 n = _len(J, ".signedAmounts");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            assertEq(
                TidepoolTerms.signedAmountTerm(_int(J, _at(".signedAmounts", i, ".value"))),
                _hexBytes(J, _at(".signedAmounts", i, ".encoded")),
                "signedAmountTerm"
            );
        }
    }

    function test_sites() public view {
        uint256 n = _len(J, ".sites");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            string memory caip2 = _str(J, _at(".sites", i, ".caip2"));
            assertEq(TidepoolTerms.siteTerm(caip2), _hexBytes(J, _at(".sites", i, ".encoded")), "siteTerm");
            assertEq(TidepoolTerms.siteId(caip2), _bytes32(J, _at(".sites", i, ".id")), "siteId");
        }
    }

    function test_ledgers() public view {
        uint256 n = _len(J, ".ledgers");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            bytes memory w = TidepoolTerms.ledgerWitness(_str(J, _at(".ledgers", i, ".caip2")), _addr(J, _at(".ledgers", i, ".address")));
            assertEq(w, _hexBytes(J, _at(".ledgers", i, ".witness")), "ledgerWitness");
            assertEq(TidepoolTerms.witnessId(w), _bytes32NoPrefix(J, _at(".ledgers", i, ".witnessId")));
        }
    }

    function test_cycles() public view {
        uint256 n = _len(J, ".cycles");
        assertGt(n, 0);
        for (uint256 i; i < n; ++i) {
            assertEq(
                TidepoolTerms.cycleTerm(uint64(_uint(J, _at(".cycles", i, ".value")))),
                _hexBytes(J, _at(".cycles", i, ".encoded")),
                "cycleTerm"
            );
        }
    }

    /// @dev The lifecycle cells of A.0c, composed from the builders and the predicate vocabulary.
    function test_cells() public view {
        uint256 n = _len(J, ".cells");
        assertEq(n, 6);
        for (uint256 i; i < n; ++i) {
            string memory name = _str(J, _at(".cells", i, ".name"));
            bytes memory s;
            bytes memory p;
            bytes memory o;
            if (_is(name, "admittedBy")) {
                s = TidepoolTerms.memberTerm(_addr(J, _at(".cells", i, ".member")));
                p = TidepoolPredicates.term(TidepoolPredicates.ADMITTED_BY);
                o = TidepoolTerms.idTerm(_bytes32(J, _at(".cells", i, ".digest")));
            } else if (_is(name, "retiredAt")) {
                address m = _addr(J, _at(".cells", i, ".member"));
                s = TidepoolTerms.scoped(TidepoolTerms.memberLabel(m), _uint(J, _at(".cells", i, ".epoch")));
                p = TidepoolPredicates.term(TidepoolPredicates.RETIRED_AT);
                o = TidepoolTerms.cycleTerm(uint64(_uint(J, _at(".cells", i, ".cycle"))));
            } else if (_is(name, "cycleTotal")) {
                s = TidepoolTerms.poolCycleSite(
                    _bytes32(J, _at(".cells", i, ".poolId")),
                    uint64(_uint(J, _at(".cells", i, ".cycle"))),
                    _str(J, _at(".cells", i, ".caip2"))
                );
                p = TidepoolPredicates.term(TidepoolPredicates.CYCLE_TOTAL);
                o = TidepoolTerms.amountTerm(_uint(J, _at(".cells", i, ".amount")));
            } else if (_is(name, "releasedTo")) {
                s = TidepoolTerms.idTerm(_bytes32(J, _at(".cells", i, ".draw")));
                p = TidepoolPredicates.term(TidepoolPredicates.RELEASED_TO);
                o = TidepoolTerms.memberTerm(_addr(J, _at(".cells", i, ".member")));
            } else if (_is(name, "yieldRouted")) {
                s = TidepoolTerms.sleeveTerm(_addr(J, _at(".cells", i, ".sleeve")));
                p = TidepoolPredicates.term(TidepoolPredicates.YIELD_ROUTED);
                o = TidepoolTerms.cycleTerm(uint64(_uint(J, _at(".cells", i, ".cycle"))));
            } else if (_is(name, "fxResidue")) {
                // the scoped base is the site's CAIP-2 *text*, not its CBOR term
                s = TidepoolTerms.scoped(bytes(_str(J, _at(".cells", i, ".site"))), _uint(J, _at(".cells", i, ".n")));
                p = TidepoolPredicates.term(TidepoolPredicates.FX_RESIDUE);
                o = TidepoolTerms.signedAmountTerm(_int(J, _at(".cells", i, ".residue")));
            } else {
                revert("unknown cell row");
            }
            assertEq(s, _hexBytes(J, _at(".cells", i, ".subject")), name);
            assertEq(p, _hexBytes(J, _at(".cells", i, ".predicate")), name);
            assertEq(o, _hexBytes(J, _at(".cells", i, ".object")), name);
            assertEq(SignCell.cellId(s, p, o), _bytes32NoPrefix(J, _at(".cells", i, ".cellId")), name);
        }
    }

    function test_signedDecimalExtremes() public pure {
        assertEq(TidepoolTerms.signedDecimal(type(int256).min), "-57896044618658097711785492504343953926634992332820282019728792003956564819968");
        assertEq(TidepoolTerms.signedDecimal(type(int256).max), "57896044618658097711785492504343953926634992332820282019728792003956564819967");
        assertEq(TidepoolTerms.decimal(type(uint256).max), "115792089237316195423570985008687907853269984665640564039457584007913129639935");
    }

    function testFuzz_hexAddressLowercase(address a) public pure {
        bytes memory h = bytes(TidepoolTerms.hexAddress(a));
        assertEq(h.length, 42);
        for (uint256 i = 2; i < 42; ++i) {
            bytes1 c = h[i];
            assertTrue((c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66));
        }
        assertEq(vm.parseAddress(string(h)), a);
    }

    function _is(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
