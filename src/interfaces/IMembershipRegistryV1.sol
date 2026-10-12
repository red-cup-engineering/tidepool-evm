// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface IMembershipRegistryV1 {
    enum Kind { Person, Cell, Agent }
    enum Status { None, Member, Retired }
    enum WitnessKind { SponsorVouch, EnterpriseRoster, TurntideIslanderRole, Deployer }
    struct Member { Kind kind; Status status; uint32 epoch; WitnessKind witnessKind; bytes32 witnessDigest; bytes32 screeningDigest; uint64 admittedAt; uint64 retiredAt; address payout; bytes32 hiveAccountHash; bool agentDisclosed; }
    event Admitted(address indexed member, Kind kind, WitnessKind witnessKind, bytes32 witnessDigest, uint32 epoch);
    event Retired(address indexed member, uint32 epoch, uint64 at);
    event HiveLinked(address indexed member, bytes32 hiveAccountHash);
    event PayoutSet(address indexed member, address payout);
    error AlreadyMember(address member); error NotMember(address member); error NotDeployer(address caller);
    error WitnessRefused(WitnessKind kind, bytes32 digest, string reason); error KindNotAdmissibleByVouch(Kind kind);
    error SponsorLineInsufficient(address sponsor, uint256 pledge, uint256 available); error TooManyVouchees(address sponsor, uint8 live, uint8 max);
    function admitByDeployer(address member, Kind kind, bytes32 screeningDigest, address payout) external; // deploy script only, before seal; seeds patronSeedLine for Persons/Cells on the first roster
    function admitByVouch(address member, bytes32 screeningDigest, uint256 pledge) external;              // msg.sender is the sponsor; Kind.Person only in v0.1
    function retire(address member) external;                                                          // member, or allocator outcome
    function linkHive(bytes32 hiveAccountHash) external;                                                // member links their Hive account (the Hive side links back, Appendix D)
    function setPayout(address payout) external;
    function isMember(address member) external view returns (bool);
    function memberOf(address member) external view returns (Member memory);
    function memberCount() external view returns (uint256);
    function members(uint256 offset, uint256 limit) external view returns (address[] memory);
    function eligibleCells(uint64 cycle) external view returns (address[] memory); // Kind.Cell, Member, admitted >= probationCycles ago; v0.2 adds receipt-in-cadence
}
