// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface ITidepoolCharterV1 {
    struct Deployment { address ledger; address membrane; address registry; address treasury; address barrier; address tallies; address desk; address allocator; address siteWitness; address sleeveFactory; address mutual; address clearinghouse; }
    struct Params {
        address asset; address vault;                       // vault.asset() == asset checked
        uint8   repaymentMode;                              // 0 Eip3009 [Base], 1 Allowance [Gnosis], 2 SleeveDebit (v0.2)
        uint32  cycleLength;                                // [30 days]
        uint16[3] splitWeights;                             // [2000, 3000, 5000]; sum > 0
        uint32  settlementWindow;                           // [14 days]; >= maxTermSeconds + relayGraceSeconds
        uint32  creditWindow;                               // [90 days]
        uint32  leadSeconds;                                // [14 days]
        uint32  withdrawalWindow;                           // [7 days]
        uint32  objectionFreezeSeconds;                     // [1 day]
        uint32  relayGraceSeconds;                          // [2 hours]
        uint32  releaseWindowSeconds;                       // [3 days]
        uint32  meetGraceSeconds;                           // [2 days]
        uint32  uptimeGraceSeconds;                         // [1 hour]
        uint32  maxFeedFailureSeconds;                      // [1 day]
        address sequencerUptimeFeed;                        // explicit address(0) where none
        uint16  heardQuorum;                                // [3]
        uint16  voteQuorum;                                 // [3]
        uint256 minDrawAssets;                              // [25e6]
        uint256 minPriceAssets;                             // [1e6] (business credit)
        uint32  minTermSeconds; uint32 maxTermSeconds;      // [3 days, 30 days]
        uint16  memberExposureCapBps;                       // [500] of floatAvailable
        uint16  floatUtilizationCapBps;                     // [7000]
        uint16  writeoffBudgetBps;                          // [1500] of float inflow in creditWindow
        uint16  priceFractionBps;                           // [10000] (cells/agents)
        uint16  personPriceCapBpsPerYear;                   // [0]; <= 1200
        uint16  maxPersonExtensionsPerYear;                 // [25]
        uint256 patronSeedLine; uint256 maxSeedAssets;      // [200e6, 1000e6]
        uint16  vouchCapBps; uint8 maxLiveVouchees; uint8 vouchMaturityPairs; uint8 probationCycles; // [5000, 3, 2, 1]
        uint16  obligationBondBps; uint8 maxActiveObligationsPerMember; uint16 memberBarrierCapBps; uint16 barrierCeilingBps; // [200, 2, 500, 7000]
        uint256 minCycleInflow; uint16 keeperBountyBps; uint256 keeperBountyCap; uint256 gasEstimateAssets; // [10e6, 100, 5e6, 0.1e6]
        uint256 challengeBondAssets;                        // [10e6]
        uint256 agentDrawCapPerCycle; uint16 agentWeightCapBps; // v0.2
        uint16  reseedCapBps; uint16 rhoFloorBps;           // [1000, 2500]
        uint256 hiveReserveE3;                              // [0] in v0.1
        uint16  pegToleranceBps;                            // [100]
        uint16  demurrageBpsPerCycle;                       // [0]
        uint16  maxAllocationLen; uint16 maxCellsPerCycle;  // [64, 256]
        bool    modeBEnabled;                               // [false]
        bytes32 siteId; bytes32 poolId; bytes32[] formulaIds; // ["F0"]
    }
    function params() external view returns (Params memory);
    function deployment() external view returns (Deployment memory);
    function charterHash() external view returns (bytes32);  // keccak256(abi.encode(params, deployment))
}
