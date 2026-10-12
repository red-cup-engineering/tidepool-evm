// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Four } from "@red-cup-engineering/signstuff-evm/Four.sol";
import { SignCell } from "@red-cup-engineering/signstuff-evm/SignCell.sol";
import { Settlement } from "@red-cup-engineering/signstuff-evm/Settlement.sol";
import { TidepoolTerms } from "../src/TidepoolTerms.sol";
import { TidepoolPredicates } from "../src/TidepoolPredicates.sol";
import { Vectors } from "./Vectors.sol";

/// @notice The Hive release and repayment fixture (spec 2.6, Appendix D): the cell ids, the Hive witnesses and the
///         two-cell section digest that tidepool-hive and tidepool-sdk also assert, reproduced from Solidity.
contract HivePayloadTest is Vectors {
    string internal J;

    function setUp() public {
        J = _js("hive-release-payload.json");
    }

    function _leg(string memory key, string memory predicate, string memory witnessAccount) internal view returns (bytes32 cell) {
        address member = _addr(J, ".memberAddress");
        bytes memory s = TidepoolTerms.idTerm(_bytes32(J, ".drawId"));
        bytes memory p = TidepoolPredicates.term(predicate);
        bytes memory o = TidepoolTerms.memberTerm(member);
        assertEq(s, _hexBytes(J, string.concat(key, ".subject")), "subject");
        assertEq(p, _hexBytes(J, string.concat(key, ".predicateTerm")), "predicate");
        assertEq(o, _hexBytes(J, string.concat(key, ".object")), "object");
        cell = SignCell.cellId(s, p, o);
        assertEq(cell, _bytes32NoPrefix(J, string.concat(key, ".cellId")), "cell id");
        bytes memory w = TidepoolTerms.hiveWitness(witnessAccount);
        assertEq(w, _hexBytes(J, string.concat(key, ".witnessCbor")), "witness");
        assertEq(TidepoolTerms.witnessId(w), _bytes32NoPrefix(J, string.concat(key, ".witnessId")), "witness id");
        // the envelope carries the cell id as payloadNi, and the Hive site id as srcSite
        assertEq(bytes32(cell), _bytes32(J, string.concat(key, ".envelope.payloadNi")), "payloadNi");
        assertEq(TidepoolTerms.siteId(_str(J, ".srcSite")), _bytes32(J, string.concat(key, ".envelope.srcSite")), "srcSite");
    }

    function test_releaseAndRepaymentCellIds() public view {
        bytes32 a = _leg(".release", TidepoolPredicates.RELEASED_TO, _str(J, ".poolAccount"));
        bytes32 b = _leg(".repayment", TidepoolPredicates.DRAW_SETTLED_BY, _str(J, ".memberHiveAccount"));
        assertTrue(a != b);
    }

    function test_twoCellSectionDigest() public view {
        bytes32 a = _leg(".release", TidepoolPredicates.RELEASED_TO, _str(J, ".poolAccount"));
        bytes32 b = _leg(".repayment", TidepoolPredicates.DRAW_SETTLED_BY, _str(J, ".memberHiveAccount"));
        bytes32[] memory cells = new bytes32[](2);
        Four.Point[] memory values = new Four.Point[](2);
        (cells[0], cells[1]) = a < b ? (a, b) : (b, a);
        values[0] = Four.Point.True;
        values[1] = Four.Point.True;
        assertEq(cells[0], _bytes32NoPrefix(J, ".section.cells[0]"));
        assertEq(cells[1], _bytes32NoPrefix(J, ".section.cells[1]"));
        assertEq(Settlement.sectionDigest(cells, values), _bytes32NoPrefix(J, ".section.digest"), "section digest");
    }

    function test_payloadFitsHiveLimit() public view {
        assertLe(bytes(_str(J, ".release.op.json")).length, 8192);
        assertLe(bytes(_str(J, ".repayment.op.json")).length, 8192);
    }
}
