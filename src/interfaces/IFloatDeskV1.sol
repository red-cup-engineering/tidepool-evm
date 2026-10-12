// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.
import { RelayEnvelopeLib } from "../RelayEnvelopeLib.sol";

interface IFloatDeskV1 {
    event Drawn(bytes32 indexed drawId, address indexed member, uint256 amount, uint256 price, uint64 dueDate, bytes32 releaseSite, bytes32 intentDigest);
    event SettledLocal(bytes32 indexed drawId, address indexed member, uint256 amount, uint256 price, bool late);
    event MarkedOverdue(bytes32 indexed drawId, address indexed member, address by);
    event VoidedUnreleased(bytes32 indexed drawId);
    event ForeignReleaseWitnessed(bytes32 indexed drawId, bytes32 srcSite, bytes32 trxId, uint64 blockNum);
    event ForeignSettleWitnessed(bytes32 indexed drawId, bytes32 srcSite, bytes32 trxId, uint64 blockNum);
    event FxResidueAccrued(bytes32 indexed site, int256 residue, int256 accumulated);
    event FxResidueTold(bytes32 indexed site, uint32 n, int256 accumulated);
    event PersonDrawsPaused(bool paused, uint256 writeoff, uint256 budget);
    error SequencerDown(); error FeeAvoidedUnknown(); error TermOutOfRange(uint64 term, uint32 min, uint32 max); error ExceedsLine(uint256 amount, uint256 limit, uint256 openExposure);
    error AgentCapExceeded(address member, uint256 amount, uint256 cap); error PoolCapExceeded(uint256 lent, uint256 cap); error WriteoffBudgetExhausted(uint256 writeoff, uint256 budget);
    error CrossesBarrier(uint64 atDay, uint256 barrier, uint256 projected); error InvalidAuthorization(string reason); error HiveFloatShort(uint256 hiveFloat, uint256 needed);
    error ReleaseNotWitnessed(bytes32 drawId); error AssetMismatch(bytes32 releaseSite); error NotMemberBeforeDue(bytes32 drawId); error NotDue(bytes32 drawId, uint64 dueDate); error RelayWindowOpen(bytes32 drawId, uint64 until);
    error ReleaseWindowOpen(bytes32 drawId, uint64 until); error Held(bytes32 cell);
    function draw(uint256 amount, uint256 feeAvoided, uint64 dueDate, bytes32 releaseSite, bytes calldata repaymentAuthorization) external returns (bytes32 drawId);
    function settle(bytes32 drawId) external;                                  // member before due; anyone after; local releases only
    function markOverdue(bytes32 drawId) external;
    function voidUnreleased(bytes32 drawId) external;                           // foreign release not witnessed within releaseWindowSeconds
    function witnessForeignRelease(bytes32 drawId, RelayEnvelopeLib.Envelope calldata e, bytes calldata relayerSig, uint256 pegE6) external;  // siteWitness-admitted relayer; provisional
    function witnessForeignSettle(bytes32 drawId, RelayEnvelopeLib.Envelope calldata e, bytes calldata relayerSig, uint256 pegE6) external;   // provisional; never pulls assets
    function priceOf(address member, uint256 feeAvoided, uint256 amount, uint64 termSeconds) external view returns (uint256);
    function limitOf(address member) external view returns (uint256 limit, uint256 openExposure);
    function drawIdFor(address member, uint64 nonce) external view returns (bytes32);
    function personDrawsPaused() external view returns (bool);
}
