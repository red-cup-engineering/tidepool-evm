// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SignCell } from "@red-cup-engineering/signstuff-evm/SignCell.sol";
import { TidepoolPredicates } from "../src/TidepoolPredicates.sol";
import { Vectors } from "./Vectors.sol";

/// @notice A.0: the Solidity vocabulary equals the JS twin's, name, term bytes and id, for every predicate,
///         and no two classes share a name.
contract TidepoolPredicatesTest is Vectors {
    function _constants() internal pure returns (string[35] memory c) {
        c[0] = TidepoolPredicates.ADMITTED_BY;
        c[1] = TidepoolPredicates.MEMBER_KIND;
        c[2] = TidepoolPredicates.AGENT_DISCLOSURE;
        c[3] = TidepoolPredicates.RETIRED_AT;
        c[4] = TidepoolPredicates.SPONSORED_BY;
        c[5] = TidepoolPredicates.YIELD_ROUTED;
        c[6] = TidepoolPredicates.BARRIER_DECLARED;
        c[7] = TidepoolPredicates.STAGE_DECLARED;
        c[8] = TidepoolPredicates.OBLIGATION_DUE;
        c[9] = TidepoolPredicates.OBLIGATION_SETTLED;
        c[10] = TidepoolPredicates.CONTESTED_BY;
        c[11] = TidepoolPredicates.RELEASED_TO;
        c[12] = TidepoolPredicates.DRAW_SETTLED_BY;
        c[13] = TidepoolPredicates.OVERDUE_AT;
        c[14] = TidepoolPredicates.LATE_SETTLED_AT;
        c[15] = TidepoolPredicates.VOIDED_AT;
        c[16] = TidepoolPredicates.FX_RESIDUE;
        c[17] = TidepoolPredicates.CYCLE_TOTAL;
        c[18] = TidepoolPredicates.BUCKET;
        c[19] = TidepoolPredicates.SECTION_DIGEST;
        c[20] = TidepoolPredicates.HEAD_OF;
        c[21] = TidepoolPredicates.H1_RANK;
        c[22] = TidepoolPredicates.QUESTION_OPENED;
        c[23] = TidepoolPredicates.ASSENTED_TO;
        c[24] = TidepoolPredicates.OBJECTED_TO;
        c[25] = TidepoolPredicates.WITHDREW_FROM;
        c[26] = TidepoolPredicates.REJOINED;
        c[27] = TidepoolPredicates.QUIESCED;
        c[28] = TidepoolPredicates.EXECUTED;
        c[29] = TidepoolPredicates.OWED_TO;
        c[30] = TidepoolPredicates.ADMITTED_OWED;
        c[31] = TidepoolPredicates.CLEARED;
        c[32] = TidepoolPredicates.CLAIMED_RESEED;
        c[33] = TidepoolPredicates.RESEEDED;
        c[34] = TidepoolPredicates.SETTLED_BY;
    }

    function test_vocabularyMatchesTwin() public view {
        string memory J = _js("tidepool-vocab.json");
        string[35] memory c = _constants();
        assertEq(_len(J, ".predicates"), c.length, "count");
        for (uint256 i; i < c.length; ++i) {
            assertEq(c[i], _str(J, _at(".predicates", i, ".name")), "name");
            assertEq(TidepoolPredicates.term(c[i]), _hexBytes(J, _at(".predicates", i, ".term")), "term");
            assertEq(TidepoolPredicates.id(c[i]), _bytes32(J, _at(".predicates", i, ".id")), "id");
            assertEq(TidepoolPredicates.id(c[i]), sha256(SignCell.textTerm(c[i])), "id is sha256 of the text term");
        }
    }

    function test_noTwoClassesShareAName() public pure {
        string[35] memory c = _constants();
        for (uint256 i; i < c.length; ++i) {
            for (uint256 j = i + 1; j < c.length; ++j) {
                assertTrue(keccak256(bytes(c[i])) != keccak256(bytes(c[j])), c[i]);
            }
        }
    }

    function test_namesCarryTheTidepoolPrefix() public pure {
        string[35] memory c = _constants();
        for (uint256 i; i < c.length; ++i) {
            bytes memory n = bytes(c[i]);
            assertTrue(n.length > 9 && n[0] == "t" && n[8] == ":", c[i]);
        }
    }
}
