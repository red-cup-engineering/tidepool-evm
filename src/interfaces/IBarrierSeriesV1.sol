// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.
import { IMemberSleeveV1 } from "./IMemberSleeveV1.sol";

interface IBarrierSeriesV1 {
    struct Obligation { address member; bytes32 kind; uint64 dueDate; uint256 amount; uint256 bond; bool settled; bool contested; uint64 expiresAt; uint64 declaredAt; }
    struct Bucket { uint64 day; uint256 amount; }
    event ObligationDeclared(bytes32 indexed id, address indexed member, uint64 dueDate, uint256 amount, uint256 bond);
    event ObligationSettled(bytes32 indexed id, uint256 bondReturned);
    event ObligationExpired(bytes32 indexed id, uint256 bondForfeited);
    event ObligationContested(bytes32 indexed id, address indexed by, uint256 bond);
    event ContestClosed(bytes32 indexed id, bool upheld, bytes32 settlementCell);
    event SleeveBarrierRecorded(address indexed owner, uint32 n, uint256 assetsDeclared);
    error NotMember(address caller); error TooManyActive(address member, uint8 max); error RaiseTooLarge(bytes32 id); error BucketsExhausted(); error NotExpired(bytes32 id); error NotDeclarer(address caller);
    function declare(bytes32 kind, uint64 dueDate, uint256 amount, bytes32 digest) external returns (bytes32 id); // pulls bond
    function settle(bytes32 id) external;
    function expire(bytes32 id) external;                                           // permissionless after dueDate + settlementWindow
    function contest(bytes32 id, bytes32 evidenceDigest) external;                   // any member; pulls bond
    function closeContest(bytes32 id, bool upheld, bytes32 settlementCell) external; // daimon office (v0.2) or allocator outcome
    function recordSleeveBarrier(address owner, IMemberSleeveV1.BarrierJoules calldata b) external; // only the owner's sleeve
    function recordSleeveStage(address owner, uint8 stage) external;
    function barrierAt(uint64 t) external view returns (uint256 assets);            // capped at ceiling
    function contributionOf(address member) external view returns (uint256);
    function buckets(uint64 fromDay, uint64 toDay) external view returns (Bucket[] memory);
    function wouldCross(uint256 projectedFloat, uint64 from, uint64 to) external view returns (bool crosses, uint64 atDay, uint256 barrier);
    function baseFloor() external view returns (uint256);
}
