// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.
import { RelayEnvelopeLib } from "../RelayEnvelopeLib.sol";

interface ISiteWitnessV1 {
    enum SiteKind { Eip155, Hive, HiveEngine, Magi, Solana }
    struct Site { bytes32 id; SiteKind kind; string caip2; address asset; uint8 assetDecimals; address treasury; bytes32 witnessId; bool hub; }
    struct Head { bytes32 site; uint64 cycle; bytes32 sectionDigest; uint64 height; bytes32 blockId; uint256 total; uint256 hiveFloatE3; uint64 toldAt; }
    struct Challenge { address challenger; uint256 claimedTotal; uint256 bond; bytes32 evidenceDigest; bool resolved; bool upheld; }
    event SiteRegistered(bytes32 indexed id, SiteKind kind, string caip2, bool hub);
    event EdgeRegistered(bytes32 indexed a, bytes32 indexed b);
    event CellIndexed(uint64 indexed cycle, bytes32 indexed cell, uint32 count);
    event SectionCommitted(uint64 indexed cycle, bytes32 digest, uint32 cells);
    event HeadTold(bytes32 indexed site, uint64 indexed cycle, bytes32 sectionDigest, uint64 height, bytes32 blockId, uint256 total);
    event TotalChallenged(uint64 indexed cycle, address indexed challenger, uint256 claimedTotal, uint256 localTotal, bytes32 cell);
    event MeetSettled(uint64 indexed cycle, uint256 paid, uint256 heldMass, bool challengeUpheld);
    error NotBoundTeller(address caller); error CycleCellCapReached(uint64 cycle, uint16 max); error NotCanonical(uint256 index); error CountMismatch(uint32 supplied, uint32 expected); error NotInCycle(bytes32 cell);
    error NoEdge(bytes32 site); error NotMonotone(bytes32 site, uint64 cycle, uint64 height); error GraceOpen(uint64 cycle, uint64 until); error GraceClosed(uint64 cycle); error SecondHub(); error Sealed();
    function registerSite(Site calldata s) external;              // deployer before seal; v0.2 via allocator SiteEdge outcome
    function registerEdge(bytes32 a, bytes32 b) external;         // deployer before seal; must keep a forest
    function indexCell(bytes32 cell) external;                    // bound pool contracts
    function commitSection(uint64 cycle, bytes32[] calldata sortedCells) external returns (bytes32 digest);
    function tellHead(Head calldata h, RelayEnvelopeLib.Envelope calldata e, bytes calldata relayerSig) external;
    function challengeTotal(uint64 cycle, uint256 claimedTotal, bytes32 evidenceDigest) external;  // member; within meetGrace; pulls bond; tells against on the cycleTotal cell
    function settleMeet(uint64 cycle, bool challengeUpheld, bytes32 outcomeOrSettlementCell) external; // allocator outcome (SettleMeet) or daimon (v0.2); releases held and bond
    function meetOf(bytes32 site, uint64 cycle) external view returns (uint256 paid, uint256 heldMass, bytes32 cell, bool open);
    function heldCount() external view returns (uint256);
    function localSection(uint64 cycle) external view returns (bytes32 digest, uint32 cells, bool committed);
    function headOf(bytes32 site, uint64 cycle) external view returns (Head memory);
    function sites() external view returns (Site[] memory);
    function isForest() external view returns (bool);
    function cycleCells(uint64 cycle, uint256 offset, uint256 limit) external view returns (bytes32[] memory);
}
