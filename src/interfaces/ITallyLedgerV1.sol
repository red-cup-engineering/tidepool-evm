// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface ITallyLedgerV1 {
    enum Status { None, Open, Matched, Overdue, LateMatched, Void }
    struct Draw { bytes32 id; address member; uint256 amount; uint256 price; uint64 drawnAt; uint64 dueDate; uint64 settledAt; Status status; bytes32 releaseSite; bool provisional; bool counted; bool late; }
    struct Line { uint256 limit; uint256 line; uint32 countedPairs; uint256 median; uint8 factor; uint256 openExposure; uint32 openDraws; bool staleOpen; bool voucheeOverdue; }
    event Released(bytes32 indexed drawId, address indexed member, uint256 amount, bytes32 releaseSite, bool provisional);
    event Settled(bytes32 indexed drawId, address indexed member, uint256 amount, uint256 price, bool late, bool counted);
    event Overdue(bytes32 indexed drawId, address indexed member);
    event Voided(bytes32 indexed drawId, address indexed member);
    event PairCounted(address indexed member, uint256 clippedSize, uint32 countedPairs, uint256 median);
    event SponsorSeeded(address indexed sponsor, address indexed member, uint256 pledge);
    event PledgeMatured(address indexed sponsor, address indexed member);
    error NotDesk(address caller); error NotRegistry(address caller); error UnknownDraw(bytes32 drawId); error BadTransition(bytes32 drawId, Status from, Status to);
    function release(bytes32 drawId, address member, uint256 amount, uint256 price, uint64 dueDate, bytes32 releaseSite, bool provisional) external; // onlyDesk
    function settle(bytes32 drawId, bool counts) external;      // onlyDesk; Open->Matched, Overdue->LateMatched
    function markOverdue(bytes32 drawId) external;              // onlyDesk
    function void(bytes32 drawId) external;                     // onlyDesk
    function seedSponsor(address sponsor, address member, uint256 pledge) external; // onlyRegistry; sponsor == deployer for patrons
    function deriveLine(address member) external view returns (Line memory);
    function deriveLineAt(address member, uint64 cycle) external view returns (Line memory); // checkpointed
    function drawOf(bytes32 drawId) external view returns (Draw memory);
    function drawsOf(address member, uint256 offset, uint256 limit) external view returns (bytes32[] memory);
    function median(uint256[] calldata ring) external pure returns (uint256);          // realizer: floor-average middles
    function clip(uint256 size, uint256 currentMedian, uint256 minDraw) external pure returns (uint256);
}
