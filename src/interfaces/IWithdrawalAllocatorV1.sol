// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface IWithdrawalAllocatorV1 {
    enum Kind { Cycle, Reseed, SettleMeet, ClearHeldFact, CharterMigration, SiteEdge, Federation }
    enum Outcome { Pending, Consensus, Escalated, Adjourned }
    enum Participation { Silent, Assented, Objected, Withdrawn }
    struct Question { bytes32 id; Kind kind; uint64 cycle; uint256 amount; uint64 opensAt; uint64 closesAt; bytes32 standingFormula; bytes32 payloadDigest; uint32 heard; uint32 withdrawn; uint32 objections; Outcome outcome; bytes32 resolvedFormula; bool executed; }
    event Opened(bytes32 indexed q, Kind kind, uint64 cycle, uint256 amount, bytes32 standingFormula, uint64 closesAt);
    event Participated(bytes32 indexed q, address indexed member, Participation p, uint32 n, bytes32 altFormula);
    event Quiesced(bytes32 indexed q, Outcome outcome, uint32 heard, uint32 withdrawn, uint32 objections, uint32 unheard, bytes32 resolvedFormula);
    event Executed(bytes32 indexed q, bytes32 formula, uint256 pulled, uint32 recipients);
    error WindowClosed(bytes32 q); error WindowOpen(bytes32 q); error ObjectionFrozen(bytes32 q, uint64 until); error NotMember(address caller); error NotTreasury(address caller); error NotOwnerContract(bytes32 q, address caller);
    error AlreadyQuiesced(bytes32 q); error AlreadyExecuted(bytes32 q); error NotExecutable(bytes32 q, Outcome outcome); error UnknownFormula(bytes32 id); error TooManyRecipients(uint32 n, uint16 max);
    function openCycleQuestion(uint64 cycle, uint256 amount) external returns (bytes32 q);          // onlyTreasury
    function openQuestion(Kind kind, bytes32 payloadDigest) external returns (bytes32 q);          // owning contracts only (mutual, siteWitness, ...); never Kind.Cycle
    function assent(bytes32 q) external; function object(bytes32 q, bytes32 altFormula) external; function withdraw(bytes32 q) external; function rejoin(bytes32 q) external;
    function quiesce(bytes32 q) external returns (Outcome);                                        // permissionless after closesAt
    function execute(bytes32 q) external;                                                          // Kind.Cycle only; once; pulls, computes by formula, accrues
    function outcomeOf(bytes32 q) external view returns (Outcome outcome, uint32 heard, uint32 objections, bool quorumMet);
    function questionOf(bytes32 q) external view returns (Question memory);
    function participationOf(bytes32 q, address member) external view returns (Participation);
    function unheardCount(bytes32 q) external view returns (uint32);
    function standingFormula() external view returns (bytes32);
    function recipientsFor(bytes32 formula, uint64 cycle) external view returns (address[] memory to, uint256[] memory weights);
}
