// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface IReseedMutualV1 {
    enum ClaimState { Open, Granted, Refused, Expired }
    struct Claim { bytes32 id; address member; address sleeve; uint256 barrierAssets; uint256 balance; uint256 requested; uint64 cycle; bytes32 question; ClaimState state; uint256 granted; }
    event Claimed(bytes32 indexed id, address indexed member, uint256 barrierAssets, uint256 balance, uint256 requested, bytes32 question);
    event Granted(bytes32 indexed id, uint256 granted, uint256 cap, uint256 prorata);
    event Refused(bytes32 indexed id, string reason);
    error NoBreach(uint256 balance, uint256 barrier); error NoObligationDue(address member); error ClaimOpen(address member); error QuestionNotCarried(bytes32 q); error SequencerDown();
    function claim() external returns (bytes32 id);                   // opens an allocator question of Kind.Reseed
    function grant(bytes32 id) external;                               // permissionless after quiesce; requires Consensus with heard >= heardQuorum and no objection, or Escalated resolved for; pro-rata within the cycle
    function capFor(address member, uint64 cycle) external view returns (uint256);  // Safety Net throttle with N_eff
    function coverageRatio(uint64 horizonSeconds) external view returns (uint256 reserve, uint256 barrierPeak);
    function claimOf(bytes32 id) external view returns (Claim memory);
}
