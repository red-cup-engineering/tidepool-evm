# tidepool-evm roadmap (revision 3, after the adversarial review)

Spec: master specification 2026-10-08 revision 3, §2.5–2.9 (storage holds state; cells are the monotone record; relayed-by-contract witnesses; the cycle cell index; per-site pay-the-meet; the relay envelope), Appendix A (interfaces, copied verbatim into `src/interfaces/`), Appendix B (Lean). Conventions: Solidity 0.8.28, `via_ir`, `evm_version` per signstuff-evm P0.3 (shanghai today), OpenZeppelin 5.6.1 with `ReentrancyGuard` on every state-changing external function, checks-effects-interactions everywhere, `forge-std` as ETH pins it; `src/<Name>.sol` one contract per file; `test/<Name>.t.sol`; `test/vectors/lean/<group>/<op>.json` byte-identical copies of `obsmetrologia-conformance/vectors/<group>/`; `test/vectors/js/*.json` emitted by this package's JS twin. Where a Lean suite is not yet emitted the acceptance uses the named property tests and a skipped vector test naming the suite.

**Hard constraint: `signstuff-evm` is frozen** (repository split in progress). No v0.1 task edits it. Everything below builds against its 2026-10-08 `src/` (`Four`, `Cbor`, `SignCell`, `Evidence`, `WitnessSet`, `CellLedger`, `IMembrane`, `AllowlistMembrane`, `Settlement`, `GraphCohomology`). Changes we want there are listed at the end under "Requests to signstuff-evm (after the split)".

**Note rule:** every task's acceptance includes a note at `tidepool-engineering-services-section/content/text/documents/articles/notes/YYYY/MM/DD/YYYY-MM-DD-note-on-<task-id>-<slug>.md` recording what was learned, decided, built, and left open. A task without its note is unfinished. Every port task cites the capability-ledger ids it carries (`tp-*`).

**Sites in v0.1.** Base Sepolia hub, Gnosis Chiado spoke, Hive as cells, paper intents and heads. One house relayer; all foreign-site tellings are provisional. No cross-site money. CreateX CREATE3 with permissioned salts; `PoolFactoryV1` is v0.3 (the deploy script is the factory). Member-witnessed cells are told by pool contracts with `tellRelayed` after an access check; there are no member roles on the membrane and sleeves never tell.

## Phase 1: kernel (v0.1)

### TP-EVM-001 `v0.1` Interfaces, predicates, terms, fixtures, stubs
- Goal: `src/interfaces/*.sol` for every Appendix A interface verbatim (including `ITallyLedgerV1`, `IMembershipRegistryV1`, `ISiteWitnessV1`, `IWithdrawalAllocatorV1` so later tasks depend only on this one); `src/TidepoolPredicates.sol` (A.0 plus `id(string)`); `src/TidepoolTerms.sol` (A.0b builders: `memberTerm(address)`, `hiveTerm(string)`, `sleeveTerm`, `scoped(bytes, uint)`, `poolCycleSite(bytes32, uint64, string)`, `amountTerm(uint256)`, `siteTerm(string)`, `memberWitness(address)`, `hiveWitness(string)`, `ledgerWitness(string caip2, address)`); `src/RelayEnvelopeLib.sol` (A.7; one-relayer `verify` by `ecrecover`/ERC-1271); `scripts/lib/tidepool-terms.mjs` (the JS twin built on `signstuff-evm/scripts/lib/cell-address.mjs`) emitting `test/vectors/js/tidepool-terms.json`, `tidepool-vocab.json`, `hive-release-payload.json` (one Hive release and one repayment envelope with their cell ids) and `relay-envelope.json`; `test/Vectors.sol` loader; `test/mocks/{MockERC4626Lossy.sol (donate, burnAssets, setMaxWithdraw), MockUSDC3009.sol, MockUptimeFeed.sol (down, recovered-at, revert)}`.
- Acceptance: `forge build` clean; every Solidity term and witness builder equals the JS twin's bytes for every row of `tidepool-terms.json`; `tidepool-hive` and `tidepool-sdk` consume the same files; the copied Lean vectors parse. Cites `tp-route-directed-yield-contract` (interfaces).
- Depends: TP-ENG-001, signstuff-evm P1 (frozen), L0 vectors.
- Status: done 2026-10-08 (note `2026-10-08-note-on-tp-evm-001-interfaces-predicates-terms-fixtures-stubs.md`; spec's `sealed()` is a reserved word, the interface says `isSealed()`).

### TP-EVM-002 `v0.1` TidepoolMembraneV1
- Goal: A.1: `bind` `onlyDeployer` before `seal`; `admits(teller, predicate, side, relayed)` = bound grant with the side bit and `relayedAllowed ≥ relayed`; no member roles; sleeves never admitted (their cells are told by the treasury and barrier); `grantOf(teller, predicate)` argument order as `AllowlistMembrane`.
- Files: `src/TidepoolMembraneV1.sol`, `test/TidepoolMembraneV1.t.sol`.
- Acceptance: a `CellLedger(membrane, ChainScoped)` accepts `tell` from a bound contract and `tellRelayed` only where `relayedAllowed`; any EOA, including a member, is refused `NotAdmitted` on every Tidepool predicate (fuzz over predicates and sides); after `seal` every `bind` reverts `Sealed`. State in the note why `ChainScoped` (a pool contract's own witness is per site; member witnesses are chain-agnostic text).
- Depends: TP-EVM-001.
- Status: done 2026-10-08 (note `2026-10-08-note-on-tp-evm-002-tidepool-membrane.md`; the revert is `AlreadySealed`, the interface's name).

### TP-EVM-003 `v0.1` TidepoolCharterV1 and PoolSplitLib
- Goal: A.2 with the constructor checks listed there; `charterHash`; `src/PoolSplitLib.sol` (A.5: `shares`, `dust`, `split`, `settleCycle`, `transfer` over arbitrary weight lists with Lean's zero-weight semantics, full-precision `mulDiv`). Cites `tp-site-parameters`, `tp-cycle-split-20-30-50`.
- Files: `src/TidepoolCharterV1.sol`, `src/PoolSplitLib.sol`, `test/TidepoolCharterV1.t.sol`, `test/PoolSplitVectors.t.sol`.
- Acceptance: every case in `lean/pool/{shares,dust,split,settleCycle,transfer}.json` passes against `PoolSplitLib` (including `2^256−1` totals and zero-weight rows); each constructor check has a revert test; the ABI has no setter.
- Depends: TP-EVM-001.

### TP-EVM-004a `v0.1` MemberSleeveV1
- Goal: A.3 sleeve: loss-aware HWM (`hwmAfterLoss` on every owner action), `deposit(assets, minShares)` by balance delta, `redeemPrincipal`/`redeemAll`/`redeemSurplus` bounded by `redeemablePrincipal`/`surplus`/`maxWithdraw`, `routeYield` from deltas before any external call, Mode B gate, `receiveReseed`, `declareBarrier`/`declareStage` forwarding to `BarrierSeriesV1.recordSleeveBarrier/Stage` (stubbed interface from 001); `nonReentrant` throughout. Cites `tp-route-directed-yield-contract`, `tp-site-position-calldata`.
- Files: `src/MemberSleeveV1.sol`, `test/MemberSleeveV1.t.sol`.
- Acceptance: fuzz with `MockERC4626Lossy` (donate, burnAssets, maxWithdraw limits): every owner exit succeeds for any amount ≤ the stated bound in every reachable state; after `routeYield`, `totalValue + oneShareAssets ≥ HWM`; HWM never exceeds `totalValue` after a loss action; no transfer to any address but owner/`to`/treasury; Mode B reverts when disabled; reentrancy test with a malicious vault. Vector test `lean/sleeve` pending TP-LEAN-005.
- Depends: TP-EVM-001.

### TP-EVM-004b `v0.1` SleeveFactoryV1 and sleeve-telling path
- Goal: `SleeveFactoryV1` (OZ `Clones`, salt `keccak256(owner)`, `ownerOf`), and the treasury/barrier side of sleeve cells: `TidepoolTreasuryV1.receiveYield` checks `ownerOf(msg.sender) != 0` and tells `yieldRouted` with `memberWitness(owner)` via `tellRelayed`; `BarrierSeriesV1.recordSleeveBarrier(owner, b)` checks `sleeveOf(owner) == msg.sender` and tells `barrierDeclared` (`sleeve#n`) the same way (the treasury and barrier bodies are TP-EVM-006a/007; this task writes the two functions and their tests against stubs).
- Files: `src/SleeveFactoryV1.sol`, `test/SleeveFactoryV1.t.sol`, `test/SleeveCells.t.sol`.
- Acceptance: a sleeve deployed after `seal` routes yield and declares a barrier and the ledger records the owner's witness (`toldBy(cell, memberWitnessId(owner))`); a non-factory contract calling `receiveYield` is refused `NotSleeve`; `predictSleeve` equals the deployed address.
- Depends: TP-EVM-002, TP-EVM-004a.

### TP-EVM-005 `v0.1` MembershipRegistryV1
- Goal: A.4: `admitByDeployer` (deployer, before seal; seeds `patronSeedLine` through `tallies.seedSponsor(deployer, member, seed)` for the first roster; `Σ ≤ maxSeedAssets`); `admitByVouch` (sponsor is `msg.sender`; `Kind.Person` only in v0.1; `pledge ≤ available = limit − Σ live pledges`; `maxLiveVouchees`, `vouchCapBps`); `retire` (member or allocator outcome); `linkHive`; `setPayout`; `eligibleCells(cycle)` with `probationCycles`; cells per A.0c with `sponsoredBy` sponsor-witnessed; `screeningDigest` recorded. Cites `tp-membership-v2`, `tp-admission-sponsor-vouch`, `tp-exit-retire-member`.
- Files: `src/MembershipRegistryV1.sol`, `test/MembershipRegistryV1.t.sol` (against the 001 `ITallyLedgerV1` stub implemented as a mock).
- Acceptance: a first patron can sponsor in the block after deployment (the seed is live); `admitByVouch(Kind.Cell)` reverts `KindNotAdmissibleByVouch`; retire/re-admit keeps the first `admittedBy` cell True and tells `retiredAt` with `member#epoch`; vouch caps enforced (fuzz).
- Depends: TP-EVM-002, TP-EVM-003.

### TP-EVM-006a `v0.1` TidepoolTreasuryV1: inflow, close, split, bounty, uptime
- Goal: A.5 minus distribution: internal counters, `receiveYield` (sleeve check, cycle inflow, `yieldRouted`), `closeCycle` (uptime check per A2.1 with `MockUptimeFeed`, roll, write-then-split via `PoolSplitLib` with charter weights, `cycleTotal`/`bucket` cells, `allocator.openCycleQuestion(cycle, amount)` on the 001 stub, bounty last and capped), `sweepSurplus`, `lendFloat`/`repayFloat` (fees to float provision), views. Cites `tp-receipt-bound-split`, `tp-pool-ledger-postings`.
- Files: `src/TidepoolTreasuryV1.sol`, `test/TidepoolTreasuryV1.t.sol`.
- Acceptance: `closeCycle` by a random address succeeds after the window and pays `min(inflow×bps, cap)` after state is written (a reentrant asset mock cannot collect twice); roll below minimum; uptime down → `SequencerDown`; feed revert → fail-open only after `maxFeedFailureSeconds`; fuzz invariant `balanceOf ≥ reserve + float + held + distributablePending + claimableSum` with a donation handler; fees never enter the bounty base.
- Depends: TP-EVM-003, TP-EVM-004b.

### TP-EVM-006b `v0.1` TidepoolTreasuryV1: pull, accrue, claim, reseed, held
- Goal: `pullDistributable(cycle)` once, `onlyAllocator`, capped by `siteWitness.meetOf` (001 stub); `payDistributable` accrual bounded by pulled; `claim` (permissionless, uptime fail-open); `reseed` `onlyMutual` decreasing reserve and calling `sleeve.receiveReseed`; `releaseHeld` `onlySiteWitness`.
- Files: `src/TidepoolTreasuryV1.sol` (extend), `test/TreasuryDistribution.t.sol`.
- Acceptance: a second `pull` reverts `AlreadyPulled`; `payDistributable` above pulled reverts; a blacklisting mock recipient blocks only its own `claim`; reseed decreases reserve and raises the sleeve HWM; conservation invariant extended.
- Depends: TP-EVM-006a.

### TP-EVM-007 `v0.1` BarrierSeriesV1
- Goal: A.6: bonded `declare` (pulls `obligationBondBps × amount`), two active per member, counted contribution `min(Σ declared, sleeve.totalValue(), memberBarrierCapBps × floatAvailable)`, UTC day buckets (64 days; `BucketsExhausted` otherwise), ceiling `barrierCeilingBps × floatAvailable`, raise-cap 2× after `leadSeconds`, `settle`/`expire`/`contest`/`closeContest`, `recordSleeveBarrier/Stage`, `wouldCross` over day buckets. Cites `tp-barrier-series`.
- Files: `src/BarrierSeriesV1.sol`, `test/BarrierSeriesV1.t.sol`.
- Acceptance: `pool-service`'s `derivePoolBarrierSeries` fixtures reproduce as day buckets (ISO day → unix day conversion stated); an adversary with N vouched members cannot raise `barrierAt` above `baseFloor + Σ bonded, capped contributions` and never above the ceiling (fuzz); 33 tiny declarations cannot exhaust buckets (they share days); bonds conserve. Vector test `lean/barrier` pending TP-LEAN-002.
- Depends: TP-EVM-002, TP-EVM-005.

### TP-EVM-008 `v0.1` TallyLedgerV1
- Goal: A.7 ledger: storage statuses and transitions (`Open→Matched`, `Open→Overdue→LateMatched`, `Open→Void`), per-member `openExposure`, ring of clipped sizes, `countedPairsInWindow` incremental with per-cycle checkpoints, one counted pair per UTC day, `median` floor-average, `clip` to 2× median, `factor` (stale open or vouchee overdue), `seedSponsor` with pledge maturity (`vouchMaturityPairs`), `deriveLine`/`deriveLineAt`/`drawsOf` paginated; provisional draws never counted. Cites `tp-credit-line`, `tp-overdue-four-verdict`.
- Files: `src/TallyLedgerV1.sol`, `test/TallyLedgerV1.t.sol`.
- Acceptance: every `deriveMemberCreditLine` case from `pool-service/test` reproduces at integer scale with the floor-average median (the even-length cases are restated and the difference noted); `line_growth_bounded`: starting from `patronSeedLine`, nine counted pairs per day cannot more than double the median per nine pairs (property test); `deriveLineAt` is O(1) over checkpoints; nothing deletes a draw. Vector test `lean/tally` pending TP-LEAN-001.
- Depends: TP-EVM-002, TP-EVM-005.

### TP-EVM-009a `v0.1` FloatDeskV1: draw and the repayment instrument
- Goal: A.7 desk `draw` with the refusal order of §3 A3, the horizon `[now, dueDate + settlementWindow]`, exposure and pool caps, writeoff pause, person price 0 (`personPriceCapBpsPerYear = 0`; the optional priced path with the extension counter and seconds-based `mulDiv` rounded down), business price with floor, `repaymentMode` `Eip3009` (decode and verify `from/to/value/nonce == drawId/validAfter/validBefore`, signature under the token's `DOMAIN_SEPARATOR`, ERC-1271 for accounts) and `Allowance` (allowance check); `drawIdFor`; `HiveFloatShort` for foreign releases reading the latest Hive head; the Hive intent path tells `releasedTo` provisional and moves nothing. Cites `tp-timing-float-draw`.
- Files: `src/FloatDeskV1.sol`, `test/FloatDeskDraw.t.sol`.
- Acceptance: `frontPoolDraw` cases from `pool-service/test` reproduce (refusal reasons; admitted terms) with the new exposure rule stated where it changes a result; a garbage or cancelled authorization is refused at draw; `k` concurrent draws of size `limit` fail after the first (`ExceedsLine` with `openExposure`); a draw with `dueDate = now + 1 min` is refused `TermOutOfRange`; a later obligation inside the horizon is caught; price invariant: effective annualized person price ≤ cap for all fuzzed `(amount, termSeconds)`.
- Depends: TP-EVM-006a, TP-EVM-007, TP-EVM-008.

### TP-EVM-009b `v0.1` FloatDeskV1: settle, overdue, void, foreign witnesses
- Goal: `settle` (member before due, anyone after; `ReleaseNotWitnessed`; `AssetMismatch`; pulls; `repayFloat`; `drawSettledBy` member-witnessed; `LateMatched` path), `markOverdue` (uptime, `relayGraceSeconds`, three effects), `voidUnreleased`, `witnessForeignRelease`/`witnessForeignSettle` with `RelayEnvelopeLib.verify` and the consumed-nonce set, `fxResidue` accumulation per site, the `PersonDrawsPaused` rule.
- Files: `src/FloatDeskV1.sol` (extend), `test/FloatDeskSettle.t.sol`, `test/CrossSiteRecord.t.sol`.
- Acceptance: a bot cannot `settle` before `dueDate`; after `markOverdue` the status is `Overdue`, `factor == 0`, no cell is Both, and a later `settle` yields `LateMatched` with the line recovering at the next derive; a foreign release draw cannot be settled on the EVM site (`ReleaseNotWitnessed`/`AssetMismatch`) and voids after `releaseWindowSeconds`; a replayed envelope reverts `Replayed`; an envelope for another chain reverts `WrongDestination`; the residue accumulates below tolerance and tells a cell above it; selector scan clean.
- Depends: TP-EVM-009a.

### TP-EVM-010a `v0.1` WithdrawalAllocatorV1: questions and participation
- Goal: A.8 storage model: `openCycleQuestion` (treasury), `openQuestion` (owning contracts; never `Cycle`), `assent`/`object`/`withdraw`/`rejoin` as `msg.sender == member` flag transitions with counters and member-witnessed `q#n` cells via `tellRelayed`, `objectionFreezeSeconds`, O(1) `unheardCount`, `participationOf`, `outcomeOf`. Cites `tp-withdrawal-consensus`.
- Files: `src/WithdrawalAllocatorV1.sol`, `test/AllocatorParticipation.t.sol`.
- Acceptance: five members assenting are five witnesses on five cells (`toldBy` each); a member cannot change another member's participation (fuzz over callers); withdraw then rejoin leaves two cells and one flag; `object` in the freeze window reverts; `openQuestion(Kind.Cycle, …)` reverts.
- Depends: TP-EVM-005, TP-EVM-006a.

### TP-EVM-010b `v0.1` WithdrawalAllocatorV1: quiesce and execute
- Goal: `quiesce` per §3 A4 (lone objection keeps the standing formula; objections ≥ quorum → `Escalated` → `F0` in v0.1; nobody heard → `Adjourned` → `F0`); `execute` (`Kind.Cycle` only; `executed` set first; `pullDistributable` once; `recipientsFor(F0, cycle)` = `registry.eligibleCells(cycle)` capped at `maxAllocationLen`; `PoolSplitLib.split` with equal weights; `payDistributable` accrual); `standingFormula` update only on `Consensus`.
- Files: `src/WithdrawalAllocatorV1.sol` (extend), `test/AllocatorQuiesce.t.sol`.
- Acceptance: scenarios: all silent → `Adjourned`, `F0`; assent only → `Consensus`; one objection with quorum 3 → `Consensus` with the standing formula and the objection recorded; three objections → `Escalated`, `F0`; a second `execute` reverts `AlreadyExecuted`; a stale question cannot pull a later cycle's funds; recipients receive `claimable` and `claim` pays. Vector test `lean/withdrawal` pending TP-LEAN-003.
- Depends: TP-EVM-010a, TP-EVM-006b.

### TP-EVM-011a `v0.1` SiteWitnessV1: registry, cell index, section, heads
- Goal: A.9: `registerSite`/`registerEdge` (deployer, sealed; one hub; forest check via `GraphCohomology.betti`), `indexCell` (bound tellers; `maxCellsPerCycle`), `commitSection(cycle, sortedCells)` (count, `inCycle`, ascending, `ledger.section`, `Settlement.sectionDigest`, `sectionDigest` cell), `tellHead` with envelope verification, `NoEdge`, monotone `(cycle, height)`, `blockId`, `total`, `hiveFloatE3`; `headOf`, `localSection`, `cycleCells`.
- Files: `src/SiteWitnessV1.sol`, `test/SiteWitnessIndex.t.sol`.
- Acceptance: a two-site fixture: every pool contract's tell is indexed; `commitSection` with the reconciler's sorted list equals the Foundry-computed digest and refuses a wrong count, a non-ascending list, or a foreign cell; `tellHead` from an unregistered edge reverts `NoEdge`; a stale head reverts `NotMonotone`; a replayed envelope reverts.
- Depends: TP-EVM-002, TP-EVM-006a.

### TP-EVM-011b `v0.1` SiteWitnessV1: per-site meet and the challenger
- Goal: `challengeTotal` (member; within `meetGraceSeconds`; bond; tells `against` on the site's `cycleTotal` cell via `tellRelayed` with the member witness; the cell reads Both), `meetOf(site, cycle)` from storage (`paid = min`, `heldMass`, `open`), `settleMeet` through an allocator `SettleMeet` question outcome (bond and held routed per §2.8), `treasury.releaseHeld`.
- Files: `src/SiteWitnessV1.sol` (extend), `test/SiteWitnessMeet.t.sol`.
- Acceptance: a challenge within grace makes the cell Both, `heldCount + 1`, `meetOf.paid == min`, and the treasury's `pullDistributable` is capped at `paid`; after grace with no challenge `paid == local total`; two sites with different honest totals hold nothing (per-site rule); `settleMeet` releases held to the right bucket and returns or forfeits the bond. Vector test `lean/meetpay` pending TP-LEAN-004.
- Depends: TP-EVM-011a, TP-EVM-010a.

### TP-EVM-012 `v0.1` ReseedMutualV1 (minimal)
- Goal: A.11: `claim` (breach from `sleeve.totalValue() < barrier.assetsDeclared`, an obligation due within `leadSeconds`; opens a `Reseed` question), `grant` after `quiesce` only on a carried outcome with `heard ≥ heardQuorum`, `capFor` with the Safety Net throttle and `N_eff`, pro-rata within a cycle under `reseedCapBps × reserve`, `treasury.reseed` → `sleeve.receiveReseed`.
- Files: `src/ReseedMutualV1.sol`, `test/ReseedMutualV1.t.sol`.
- Acceptance: a claim nobody hears is `Refused("unheard")` and moves nothing; a claim with three assents grants `min(cap, gap)`; two claims above the cycle cap pro-rate; `capFor` with `ρ̂ = 0.5` is below the independent value (the review's numbers reproduced); reserve never below the mutual's own barrier (fuzz). Cites the Breadchain Safety Net throttle (research block A).
- Depends: TP-EVM-010b, TP-EVM-006b, TP-EVM-007.

### TP-EVM-013 `v0.1` ClearinghouseV1 (core)
- Goal: A.12: `open` (debtor; `owedTo` debtor-witnessed), `admit` (creditor; `admittedOwed`), `clear` (closed cycles, admitted edges, `amount ≤ min remaining`, atomic, `cleared` cell), `netPosition`; no transfer function.
- Files: `src/ClearinghouseV1.sol`, `test/ClearinghouseV1.t.sol`.
- Acceptance: a three-party cycle nets in one transaction; `netPosition` conserved per party; an unadmitted edge cannot be cleared; `test/Outflows.t.sol` lists no clearinghouse function. Vector test `lean/netting` pending TP-LEAN-008.
- Depends: TP-EVM-005, TP-EVM-002.

### TP-EVM-014 `v0.1` Deploy script and end-to-end test
- Goal: `script/DeployPool.s.sol` per A.10 (CreateX `deployCreate3` with permissioned salts; predicted `Deployment` into every constructor; grants per A.0; sites and edges; first roster and seeds; `seal`; manifest with `charterHash`); `test/EndToEnd.t.sol` running the whole v0.1 demo path on anvil in one test (deposit, route, close by a stranger, question, draw, refuse, overdue, late settle, reseed via question, clearing, challenge and meet).
- Files: as listed; `script/params/{base-sepolia,gnosis-chiado}.json`; `scripts/predict-addresses.mjs` (CreateX salt and address math, cross-checked against `cross-chain-services-section/src/deterministic.mjs`).
- Acceptance: predicted addresses equal deployed addresses on a fork; an attacker using the same salt from another EOA gets a different address; after `seal` the deployer has no privileged entry point (ABI scan of `onlyDeployer` functions all revert `Sealed`); the end-to-end test passes.
- Depends: TP-EVM-003 through TP-EVM-013.

### TP-EVM-015 `v0.1` Invariant suite and outflow allowlist
- Goal: `test/Invariants.t.sol` with a handler over sleeves, desk, treasury, allocator, mutual: (1) every sleeve exit succeeds within its stated bound in every reachable state; (2) `test/Outflows.t.sol`: the set of external functions that reduce any pool contract's asset balance equals A.0d exactly, with recipient checks; (3) no state in which a cell is Both makes `tell*`, `read*`, `section`, `commitSection`, `closeCycle`, `claim` or any sleeve exit revert (ambition-02's fuzz: random tellings by random addresses never block `closeCycle`); (4) treasury `balanceOf ≥` counters; (5) ledger `wits` never decreases; (6) `markOverdue` writes only the status, the stale flag and one cell; (7) selector scan (`liquidat|seize|slash|sweep` except `sweepSurplus`).
- Acceptance: `forge test --match-contract Invariants --jobs 2` passes with `runs = 256, depth = 32`.
- Depends: TP-EVM-014.

### TP-EVM-016 `v0.1` Testnet deploys and manifests
- Goal: run `DeployPool.s.sol` on Base Sepolia and Gnosis Chiado (asset: the registry's test USDC on Base Sepolia; `MockUSDC3009` on Chiado with `repaymentMode = Allowance` so the Gnosis path is exercised; vault `MockERC4626Lossy`), write `deployments/<chainId>.json` (addresses, `charterHash`, blockNumber, sites with the Hive record), verify source on the explorers.
- Acceptance: equal addresses on both chains; `cast call <charter> "charterHash()"` matches the manifest; keys via `key-management-services-section`; one chain at a time.
- Depends: TP-EVM-015.

## Phase 2 (v0.2)

TP-EVM-017 `TallyVoteV1` (A5 weights, `Apportion` vectors; allocator `Escalated` → ballot); TP-EVM-018 `JouleIndexV1` and the kWh barrier; TP-EVM-019 `CellRegistryV1` with `OutcomeReceiptRegistryV1` joins and `EnterpriseRoster` admission (`tp-member-enterprise-roster`, `tp-first-roster-seed`, `tp-admission-enterprise-roster`); TP-EVM-020 `SettlementBountyV1` and the daimon office (`tp-contests`); TP-EVM-021 `WorklistV1` (AllocationSolver vectors); TP-EVM-022 `AlgedonicV1`; TP-EVM-023 agent members and caps; TP-EVM-024 k-of-n relayed tellings (`RelayEnvelopeLib` multi-signature; signstuff-evm P2.4 after the split) and Hive repayment leg maturing lines; TP-EVM-025 `addEdge`/`tellH1`/`registerSite` through `SiteEdge` outcomes; Arbitrum and OP Sepolia sites with Hyperlane heads (cross-chain Phase 3.2/3.3); TP-EVM-026 demurrage; TP-EVM-027 `TurntideIslanderRole` admission; TP-EVM-028 Hats roles with the allocator as top hat; TP-EVM-029 `repaymentMode = SleeveDebit`.

## Phase 3 (v0.3)

TP-EVM-030 `TurnAuctionV1`; TP-EVM-031 `DecorrelationV1`; TP-EVM-032 `EnergyCommonsV1`; TP-EVM-033 `YieldInletV1`, donating vault, Uniswap v4 hook; TP-EVM-034 `FederationRegistryV1`/`FederationMutualV1`; TP-EVM-035 `LadderPolicyV1` and the bounded float operator; TP-EVM-036 CCTP v2 float movement Base↔Arbitrum; TP-EVM-037 `PoolFactoryV1` (the deploy script as a contract, same salts); TP-EVM-038 `BurnHedgeV1` (`tp-consumption-hedge`).

## Requests to signstuff-evm (after the split)

Recorded here, never assumed by a v0.1 task; each names the tidepool-local workaround in force.

1. **Subject-aware membrane.** `IMembrane.admitsCell(teller, predicate, side, relayed, bytes32 subjectTermId)` with `CellLedger` passing `sha256(t.subject)` (and storing it so `tellKnown` can pass it). Workaround: no member roles; pool contracts are the only tellers and check the subject themselves (§2.6).
2. **Teller-set membranes for factories.** A grant kind that admits any teller `f(teller) == true` for an immutable predicate set (so a sleeve factory's clones could tell). Workaround: sleeve cells are told by the treasury and barrier after `ownerOf` checks.
3. **Cell index.** `CellLedger` keeping an append-only list of opened cell ids per epoch, or an event-indexed `openedAt`. Workaround: `SiteWitnessV1.indexCell` called by every pool teller.
4. **Section digest over a committed list.** `Settlement.sectionDigestFromIndex(epoch)` once (3) exists. Workaround: `commitSection(sortedCells)`.
5. **k-of-n relayed attestation membrane (P2.4).** Workaround: `RelayEnvelopeLib` in this package with one relayer; the k-of-n check moves to signstuff-evm's `HiveAttestationMembrane` when it lands.
6. **Object storage for register cells.** An optional small-value register (`uint256`) per cell for quantities two witnesses compare. Workaround: amounts in `SiteWitnessV1` storage; the cell carries the amount as a text object.
7. **Hive witness builder.** `SignCell.hiveWitness(string account)` and a JS twin. Workaround: `TidepoolTerms.hiveWitness`.
8. **Record `meetK`/`joinT`/`meetT`/`topMass` realizers** (DESIGN §13.1 lists them unrealized): needed by the worklist's `topMass` in v0.2; the pool suite judges `PoolSplitLib` here meanwhile.
9. **EVM version (P0.3).** Close P0.3 on `cancun`: `ethereum-engineering`'s `EnterpriseAccount` imports OpenZeppelin 5.6.1 `SignatureChecker`/`Bytes`, which use `mcopy`, so no package that composes the shared contracts can compile under `shanghai`. Workaround: `tidepool-evm/foundry.toml` sets `evm_version = "cancun"` (TP-ENG-001); signstuff-evm itself is untouched.
10. **Shared Foundry vector loader.** Export `test/helpers/Vectors.sol` (JSON row probing, hex parsing, Lean-layout structs) as a library path consumers can remap, so packages stop writing their own. Workaround: `tidepool-evm/test/Vectors.sol` carries the small subset it needs.

## Capability-ledger citations

As in the task texts above; the completeness check is `TP-ENG-002`'s coverage script. `tp-pool-cli`, `tp-store-receipts`, `tp-never-mint`, `tp-claim-first-cycle-rewards`, `tp-first-cash-plan`, `tp-wallet-registry-pool`, `tp-name-collision`, `tp-lock-refresh-workflows` are retire-with-reason per the ledger and are not ported.
