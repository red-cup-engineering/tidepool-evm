// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface ITidepoolTreasuryV1 {
    struct Cycle { uint64 id; uint64 openedAt; uint64 closedAt; uint256 inflow; uint256 bounty; uint256[3] buckets; uint256 pulled; bool pulledOnce; }
    event YieldReceived(address indexed sleeve, address indexed owner, uint64 indexed cycle, uint256 assets, bytes32 yieldEvidence);
    event CycleClosed(uint64 indexed cycle, uint256 inflow, uint256 bounty, uint256 reserve, uint256 float, uint256 distributable, address keeper);
    event CycleRolled(uint64 indexed cycle, uint256 inflow, uint256 minimum, uint64 newClosesAt);
    event DistributablePulled(uint64 indexed cycle, uint256 pulled, uint256 held);
    event Accrued(uint64 indexed cycle, address indexed to, uint256 amount);
    event Claimed(address indexed to, uint256 amount);
    event FloatLent(bytes32 indexed drawId, address indexed member, uint256 amount);
    event FloatRepaid(bytes32 indexed drawId, uint256 amount, uint256 fee);
    event Reseeded(address indexed sleeve, uint256 assets);
    event SurplusSwept(uint256 assets);
    event HeldReleased(uint64 indexed cycle, uint256 toDistributable, uint256 toReserve);
    error CycleOpen(uint64 cycle, uint64 closesAt); error NotDesk(address caller); error NotAllocator(address caller); error NotMutual(address caller); error NotSleeve(address caller);
    error AlreadyPulled(uint64 cycle); error ExceedsPulled(uint256 sum, uint256 pulled); error SequencerDown(); error NothingToClaim(address to);
    function receiveYield(uint256 assets, bytes32 yieldEvidence) external;       // factory sleeves only (ownerOf != 0); v0.3 inlet
    function closeCycle() external returns (Cycle memory);
    function pullDistributable(uint64 cycle) external returns (uint256 pulled);   // onlyAllocator, once
    function payDistributable(uint64 cycle, address[] calldata to, uint256[] calldata amounts) external; // onlyAllocator; accrues
    function claim(address to) external returns (uint256 amount);                 // permissionless; transfers claimable[to]
    function claimable(address to) external view returns (uint256);
    function lendFloat(bytes32 drawId, address to, uint256 assets) external;      // onlyDesk
    function repayFloat(bytes32 drawId, uint256 assets, uint256 fee) external;    // onlyDesk; fee -> float provision
    function reseed(address sleeve, uint256 assets) external;                     // onlyMutual
    function releaseHeld(uint64 cycle, uint256 toDistributable, uint256 toReserve) external; // onlySiteWitness (meet settlement)
    function sweepSurplus() external;                                             // balanceOf - totalAssets -> reserve
    function currentCycle() external view returns (Cycle memory);
    function cycleOf(uint64 id) external view returns (Cycle memory);
    function reserve() external view returns (uint256); function float() external view returns (uint256); function lent() external view returns (uint256);
    function floatAvailable() external view returns (uint256); function held() external view returns (uint256); function totalAssets() external view returns (uint256);
    function floatInflowInWindow() external view returns (uint256); function writeoffInWindow() external view returns (uint256);
}
