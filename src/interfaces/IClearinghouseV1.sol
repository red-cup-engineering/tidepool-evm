// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface IClearinghouseV1 {
    struct Edge { bytes32 id; address debtor; address creditor; uint256 amount; uint256 remaining; uint64 dueBy; bool admitted; }
    struct Cycle { bytes32[] edges; uint256 amount; }
    event EdgeOpened(bytes32 indexed id, address indexed debtor, address indexed creditor, uint256 amount, uint64 dueBy);
    event EdgeAdmitted(bytes32 indexed id);
    event CycleCleared(bytes32 indexed clearingId, bytes32[] edges, uint256 amount);
    error NotMember(address caller); error NotCreditor(bytes32 id); error EdgeNotAdmitted(bytes32 id); error NotClosedCycle(uint256 index); error ExceedsRemaining(bytes32 id, uint256 amount, uint256 remaining);
    function open(address creditor, uint256 amount, uint64 dueBy) external returns (bytes32 id);   // debtor
    function admit(bytes32 id) external;                                                           // creditor
    function clear(Cycle[] calldata cycles) external returns (bytes32 clearingId);                 // permissionless, atomic
    function edgeOf(bytes32 id) external view returns (Edge memory);
    function netPosition(address party) external view returns (int256);
    // NO function in this contract transfers assets. test/Outflows.t.sol asserts it.
}
