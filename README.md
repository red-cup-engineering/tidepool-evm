# @red-cup-engineering/tidepool-evm

<!-- 561-group-standards:badges:start -->
[![Red Cup Engineering](https://img.shields.io/badge/561%20Group-Red%20Cup%20Engineering-c0392b)](https://github.com/red-cup-engineering)
[![License: MIT](https://img.shields.io/badge/license-MIT-c0392b)](LICENSE)
[![Indigenous data: CARE](https://img.shields.io/badge/Indigenous%20data-CARE-4b6f44)](https://github.com/red-cup-engineering/.github/blob/main/GOVERNANCE.md)
[![Tips welcome](https://img.shields.io/badge/tips-welcome-d4a017)](https://github.com/561-group/.github/blob/main/TIPS.md)
<!-- 561-group-standards:badges:end -->

The Foundry package for Tidepool's L3 contracts: the pool kernel (`TidepoolCharterV1`, `SleeveFactoryV1`/`MemberSleeveV1`, `MembershipRegistryV1`, `TidepoolTreasuryV1`, `BarrierSeriesV1`, `TallyLedgerV1`, `FloatDeskV1`, `WithdrawalAllocatorV1`, `SiteWitnessV1`, `PoolFactoryV1`) and the instruments (`TallyVoteV1`, `JouleIndexV1`, `CellRegistryV1`, `ClearinghouseV1`, `ReseedMutualV1`, `SettlementBountyV1`, `WorklistV1`, `AlgedonicV1`, `TurnAuctionV1`, `DecorrelationV1`, `EnergyCommonsV1`, `YieldInletV1`, `FederationRegistryV1`, `FederationMutualV1`, `LadderPolicyV1`).

Every contract takes a `CellLedger` from `@red-cup-engineering/signstuff-evm` and a `TidepoolCharterV1` by immutable address; every fact it records is a cell told through `TidepoolMembraneV1`. Nothing here defines a charge algebra, a membrane policy, or a settlement reading: those are `signstuff-evm`'s. Nothing here is upgradeable, ownable, or pausable except new float deployment through a withdrawal-consensus outcome.

Interfaces are frozen in the master specification's Appendix A; Lean obligations in Appendix B. Pure functions (`split`, `median`, `deriveLine`, `barrierAt`, `quiesce`, `apportion`, `pooledVariance`, `shouldShare`, ...) are realizers judged byte-for-byte against the golden vectors under `test/vectors/lean/` (copies of `obsmetrologia-conformance/vectors/{pool,four}/`).

No ABI in this package may contain a selector whose name contains `liquidat`, `seize`, or `slash`; `test/Invariants.t.sol` asserts it.
