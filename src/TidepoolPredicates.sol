// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SignCell } from "@red-cup-engineering/signstuff-evm/SignCell.sol";

/// @title TidepoolPredicates
/// @notice Appendix A.0 of the Tidepool specification (revision 3): the predicate vocabulary. Every
///         predicate is `SignCell.textTerm(<name>)`, its identity is `id(name) = sha256(textTerm(name))`
///         (the value `IMembrane.admits` and `CellLedger` take as `predicate`), and no two cell classes
///         share a name. The JS twin is `scripts/lib/tidepool-terms.mjs` (`PREDICATES`), checked row by
///         row against `test/vectors/js/tidepool-vocab.json`.
library TidepoolPredicates {
    // every predicate is SignCell.textTerm(<name>); id(name) = sha256(textTerm(name)); no two classes share a name
    string constant ADMITTED_BY       = "tidepool:admittedBy";       // ⟨member, _, witnessDigest⟩     registry (pool-witnessed)
    string constant MEMBER_KIND       = "tidepool:memberKind";       // ⟨member, _, kind⟩              registry
    string constant AGENT_DISCLOSURE  = "tidepool:agentDisclosure";  // ⟨member, _, "disclosed"⟩       registry
    string constant RETIRED_AT        = "tidepool:retiredAt";        // ⟨member#epoch, _, cycle⟩       registry
    string constant SPONSORED_BY      = "tidepool:sponsoredBy";      // ⟨member, _, sponsor⟩           registry (sponsor-witnessed)
    string constant YIELD_ROUTED      = "tidepool:yieldRouted";      // ⟨sleeve, _, cycle⟩             treasury (owner-witnessed)
    string constant BARRIER_DECLARED  = "tidepool:barrierDeclared";  // ⟨sleeve#n, _, digest⟩          barrier (owner-witnessed)
    string constant STAGE_DECLARED    = "tidepool:stageDeclared";    // ⟨sleeve#n, _, stage⟩           barrier (owner-witnessed)
    string constant OBLIGATION_DUE    = "tidepool:obligationDue";    // ⟨obligation, _, date⟩          barrier (member-witnessed)
    string constant OBLIGATION_SETTLED= "tidepool:obligationSettled";// ⟨obligation, _, cycle⟩         barrier
    string constant CONTESTED_BY      = "tidepool:contestedBy";      // ⟨obligation, _, member⟩        barrier (member-witnessed)
    string constant RELEASED_TO       = "tidepool:releasedTo";       // ⟨draw, _, member⟩              desk (pool-witnessed; provisional hive:<acct> for foreign)
    string constant DRAW_SETTLED_BY   = "tidepool:drawSettledBy";    // ⟨draw, _, member⟩              desk (member-witnessed; provisional for foreign)
    string constant OVERDUE_AT        = "tidepool:overdueAt";        // ⟨draw, _, cycle⟩               desk
    string constant LATE_SETTLED_AT   = "tidepool:lateSettledAt";    // ⟨draw, _, cycle⟩               desk
    string constant VOIDED_AT         = "tidepool:voidedAt";         // ⟨draw, _, cycle⟩               desk
    string constant FX_RESIDUE        = "tidepool:fxResidue";        // ⟨site#n, _, residueText⟩       desk
    string constant CYCLE_TOTAL       = "tidepool:cycleTotal";       // ⟨pool@cycle@site, _, amount⟩   treasury for; challenger against
    string constant BUCKET            = "tidepool:bucket";           // ⟨pool@cycle@site#k, _, amount⟩ treasury
    string constant SECTION_DIGEST    = "tidepool:sectionDigest";    // ⟨pool@cycle@site, _, digest⟩   siteWitness
    string constant HEAD_OF           = "tidepool:headOf";           // ⟨site@cycle, _, digest⟩        siteWitness (relayed; ledger:<caip2>:<addr> witness)
    string constant H1_RANK           = "tidepool:h1Rank";           // v0.2
    string constant QUESTION_OPENED   = "tidepool:questionOpened";   // ⟨q, _, kind⟩                   allocator
    string constant ASSENTED_TO       = "tidepool:assentedTo";       // ⟨member, _, q#n⟩               allocator (member-witnessed)
    string constant OBJECTED_TO       = "tidepool:objectedTo";       // ⟨member, _, q#n⟩
    string constant WITHDREW_FROM     = "tidepool:withdrewFrom";     // ⟨member, _, q#n⟩
    string constant REJOINED          = "tidepool:rejoined";         // ⟨member, _, q#n⟩
    string constant QUIESCED          = "tidepool:quiesced";         // ⟨q, _, outcome⟩                allocator
    string constant EXECUTED          = "tidepool:executed";         // ⟨q, _, formulaId⟩              allocator
    string constant OWED_TO           = "tidepool:owedTo";           // ⟨edge, _, creditor⟩            clearinghouse (debtor-witnessed)
    string constant ADMITTED_OWED     = "tidepool:admittedOwed";     // ⟨edge, _, debtor⟩              clearinghouse (creditor-witnessed)
    string constant CLEARED           = "tidepool:cleared";          // ⟨clearing, _, digest⟩          clearinghouse
    string constant CLAIMED_RESEED    = "tidepool:claimedReseed";    // ⟨claim, _, member⟩             mutual (member-witnessed)
    string constant RESEEDED          = "tidepool:reseeded";         // ⟨claim, _, amount⟩             mutual
    string constant SETTLED_BY        = "tidepool:settledBy";        // ⟨contestedCell, _, reportDigest⟩ daimon office (v0.2)

    /// @notice The canonical-CBOR text term of a predicate name.
    function term(string memory name) internal pure returns (bytes memory) {
        return SignCell.textTerm(name);
    }

    /// @notice A predicate's identity: sha256 of its text term (JS `termIdHex(name)`).
    function id(string memory name) internal pure returns (bytes32) {
        return SignCell.termId(SignCell.textTerm(name));
    }
}
