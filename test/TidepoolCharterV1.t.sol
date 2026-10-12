// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { TidepoolCharterV1 } from "../src/TidepoolCharterV1.sol";
import { ITidepoolCharterV1 } from "../src/interfaces/ITidepoolCharterV1.sol";
import { MockERC4626Lossy } from "./mocks/MockERC4626Lossy.sol";
import { MockUSDC3009 } from "./mocks/MockUSDC3009.sol";

/// @notice TP-EVM-003 acceptance for `TidepoolCharterV1`: each constructor check has a revert test, the v0.1 values
///         round-trip through `params()`/`deployment()`, `charterHash` is `keccak256(abi.encode(params, deployment))`,
///         and the compiled ABI has no setter (every function is view/pure; no fallback, receive or payable entry).
contract TidepoolCharterV1Test is Test {
    MockUSDC3009 internal usdc;
    MockERC4626Lossy internal vault;

    function setUp() public {
        usdc = new MockUSDC3009();
        vault = new MockERC4626Lossy(usdc, "Lossy Vault", "lUSDC");
    }

    /// @dev The v0.1 values in the brackets of spec A.2.
    function _params() internal view returns (ITidepoolCharterV1.Params memory p) {
        p.asset = address(usdc);
        p.vault = address(vault);
        p.repaymentMode = 0;
        p.cycleLength = 30 days;
        p.splitWeights = [uint16(2000), 3000, 5000];
        p.settlementWindow = 14 days;
        p.creditWindow = 90 days;
        p.leadSeconds = 14 days;
        p.withdrawalWindow = 7 days;
        p.objectionFreezeSeconds = 1 days;
        p.relayGraceSeconds = 2 hours;
        p.releaseWindowSeconds = 3 days;
        p.meetGraceSeconds = 2 days;
        p.uptimeGraceSeconds = 1 hours;
        p.maxFeedFailureSeconds = 1 days;
        p.sequencerUptimeFeed = address(0);
        p.heardQuorum = 3;
        p.voteQuorum = 3;
        p.minDrawAssets = 25e6;
        p.minPriceAssets = 1e6;
        p.minTermSeconds = 3 days;
        p.maxTermSeconds = 30 days;
        p.memberExposureCapBps = 500;
        p.floatUtilizationCapBps = 7000;
        p.writeoffBudgetBps = 1500;
        p.priceFractionBps = 10_000;
        p.personPriceCapBpsPerYear = 0;
        p.maxPersonExtensionsPerYear = 25;
        p.patronSeedLine = 200e6;
        p.maxSeedAssets = 1000e6;
        p.vouchCapBps = 5000;
        p.maxLiveVouchees = 3;
        p.vouchMaturityPairs = 2;
        p.probationCycles = 1;
        p.obligationBondBps = 200;
        p.maxActiveObligationsPerMember = 2;
        p.memberBarrierCapBps = 500;
        p.barrierCeilingBps = 7000;
        p.minCycleInflow = 10e6;
        p.keeperBountyBps = 100;
        p.keeperBountyCap = 5e6;
        p.gasEstimateAssets = 0.1e6;
        p.challengeBondAssets = 10e6;
        p.agentDrawCapPerCycle = 0;
        p.agentWeightCapBps = 0;
        p.reseedCapBps = 1000;
        p.rhoFloorBps = 2500;
        p.hiveReserveE3 = 0;
        p.pegToleranceBps = 100;
        p.demurrageBpsPerCycle = 0;
        p.maxAllocationLen = 64;
        p.maxCellsPerCycle = 256;
        p.modeBEnabled = false;
        p.siteId = keccak256("eip155:84532");
        p.poolId = keccak256("tidepool/test");
        p.formulaIds = new bytes32[](1);
        p.formulaIds[0] = keccak256("F0");
    }

    function _deployment() internal pure returns (ITidepoolCharterV1.Deployment memory d) {
        d = ITidepoolCharterV1.Deployment(
            address(0x1001), address(0x1002), address(0x1003), address(0x1004), address(0x1005), address(0x1006),
            address(0x1007), address(0x1008), address(0x1009), address(0x100a), address(0x100b), address(0x100c)
        );
    }

    function _deploy(ITidepoolCharterV1.Params memory p) internal returns (TidepoolCharterV1) {
        return new TidepoolCharterV1(p, _deployment());
    }

    // - round-trip and hash -

    function test_v01ValuesRoundTrip() public {
        ITidepoolCharterV1.Params memory p = _params();
        TidepoolCharterV1 c = _deploy(p);
        assertEq(abi.encode(c.params()), abi.encode(p), "params round-trip");
        assertEq(abi.encode(c.deployment()), abi.encode(_deployment()), "deployment round-trip");
        ITidepoolCharterV1.Params memory q = c.params();
        assertEq(q.splitWeights[0], 2000);
        assertEq(q.splitWeights[1], 3000);
        assertEq(q.splitWeights[2], 5000);
        assertEq(q.formulaIds.length, 1);
        assertEq(q.formulaIds[0], keccak256("F0"));
        assertEq(q.asset, address(usdc));
        assertEq(c.deployment().clearinghouse, address(0x100c));
    }

    function test_charterHashIsKeccakOfParamsAndDeployment() public {
        TidepoolCharterV1 c = _deploy(_params());
        assertEq(c.charterHash(), keccak256(abi.encode(c.params(), c.deployment())));
        assertEq(c.charterHash(), keccak256(abi.encode(_params(), _deployment())));
    }

    function test_charterHashSeparatesParamsAndDeployment() public {
        ITidepoolCharterV1.Params memory p = _params();
        bytes32 base = _deploy(p).charterHash();
        p.cycleLength = 31 days;
        assertTrue(_deploy(p).charterHash() != base, "param change moves the hash");
        ITidepoolCharterV1.Deployment memory d = _deployment();
        d.treasury = address(0xbeef);
        assertTrue(new TidepoolCharterV1(_params(), d).charterHash() != base, "deployment change moves the hash");
    }

    function test_vaultZeroIsAllowed() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.vault = address(0);
        assertEq(_deploy(p).params().vault, address(0));
    }

    function test_boundaryValuesAreAccepted() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.keeperBountyBps = 500;
        p.personPriceCapBpsPerYear = 1200;
        p.memberExposureCapBps = 10_000;
        p.settlementWindow = p.maxTermSeconds + p.relayGraceSeconds; // equality passes
        p.minCycleInflow = 10e6;
        p.gasEstimateAssets = 10e6 * 500 / 10_000; // equality passes
        p.splitWeights = [uint16(0), 0, 1]; // any nonzero sum
        _deploy(p);
    }

    // - one revert test per constructor check -

    function test_revertsOnZeroWeightSum() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.splitWeights = [uint16(0), 0, 0];
        vm.expectRevert(TidepoolCharterV1.ZeroWeightSum.selector);
        _deploy(p);
    }

    function _expectBps(bytes32 field, uint256 value, uint256 max) internal {
        vm.expectRevert(abi.encodeWithSelector(TidepoolCharterV1.BpsAboveMax.selector, field, value, max));
    }

    function test_revertsOnEveryBpsFieldAboveTenThousand() public {
        ITidepoolCharterV1.Params memory p;
        p = _params();
        p.memberExposureCapBps = 10_001;
        _expectBps("memberExposureCapBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.floatUtilizationCapBps = 10_001;
        _expectBps("floatUtilizationCapBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.writeoffBudgetBps = 10_001;
        _expectBps("writeoffBudgetBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.priceFractionBps = 10_001;
        _expectBps("priceFractionBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.vouchCapBps = 10_001;
        _expectBps("vouchCapBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.obligationBondBps = 10_001;
        _expectBps("obligationBondBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.memberBarrierCapBps = 10_001;
        _expectBps("memberBarrierCapBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.barrierCeilingBps = 10_001;
        _expectBps("barrierCeilingBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.agentWeightCapBps = 10_001;
        _expectBps("agentWeightCapBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.reseedCapBps = 10_001;
        _expectBps("reseedCapBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.rhoFloorBps = 10_001;
        _expectBps("rhoFloorBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.pegToleranceBps = 10_001;
        _expectBps("pegToleranceBps", 10_001, 10_000);
        _deploy(p);
        p = _params();
        p.demurrageBpsPerCycle = 10_001;
        _expectBps("demurrageBpsPerCycle", 10_001, 10_000);
        _deploy(p);
    }

    function test_revertsOnKeeperBountyAboveFiveHundred() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.keeperBountyBps = 501;
        _expectBps("keeperBountyBps", 501, 500);
        _deploy(p);
    }

    function test_revertsOnPersonPriceCapAboveTwelveHundred() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.personPriceCapBpsPerYear = 1201;
        _expectBps("personPriceCapBpsPerYear", 1201, 1200);
        _deploy(p);
    }

    function test_revertsOnSettlementWindowBelowMaxTermPlusGrace() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.settlementWindow = p.maxTermSeconds + p.relayGraceSeconds - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                TidepoolCharterV1.SettlementWindowTooShort.selector, p.settlementWindow, 30 days + 2 hours
            )
        );
        _deploy(p);
    }

    function test_revertsOnSettlementWindowSumThatWouldOverflowUint32() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.maxTermSeconds = type(uint32).max;
        p.relayGraceSeconds = 1; // sum is 2^32, which a uint32 sum would wrap to 0
        p.settlementWindow = type(uint32).max;
        vm.expectRevert(
            abi.encodeWithSelector(
                TidepoolCharterV1.SettlementWindowTooShort.selector, uint256(type(uint32).max), uint256(type(uint32).max) + 1
            )
        );
        _deploy(p);
    }

    function test_revertsOnBountyBelowGasEstimate() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.minCycleInflow = 10e6;
        p.keeperBountyBps = 100;
        p.gasEstimateAssets = 0.1e6 + 1; // bounty is exactly 0.1e6
        vm.expectRevert(abi.encodeWithSelector(TidepoolCharterV1.BountyBelowGasEstimate.selector, 0.1e6, 0.1e6 + 1));
        _deploy(p);
    }

    function test_bountyCheckDoesNotOverflowOnHugeInflow() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.minCycleInflow = type(uint256).max;
        p.gasEstimateAssets = type(uint256).max / 100; // floor(max*100/1e4) = max/100 >= this
        _deploy(p);
    }

    function test_revertsOnVaultAssetMismatch() public {
        ITidepoolCharterV1.Params memory p = _params();
        MockUSDC3009 other = new MockUSDC3009();
        p.asset = address(other);
        vm.expectRevert(
            abi.encodeWithSelector(TidepoolCharterV1.VaultAssetMismatch.selector, address(vault), address(usdc), address(other))
        );
        _deploy(p);
    }

    function test_revertsWhenVaultIsNotAnErc4626() public {
        ITidepoolCharterV1.Params memory p = _params();
        p.vault = address(0xdead01); // no code: the asset() call reverts
        vm.expectRevert();
        _deploy(p);
    }

    // - fuzz: a deployed charter always satisfies the checks -

    function testFuzz_acceptedCharterSatisfiesEveryCheck(
        uint16 w0,
        uint16 w1,
        uint16 w2,
        uint16 keeperBps,
        uint16 personCap,
        uint32 maxTerm,
        uint32 grace,
        uint32 window,
        uint128 inflow,
        uint128 gas
    ) public {
        ITidepoolCharterV1.Params memory p = _params();
        p.splitWeights = [w0, w1, w2];
        p.keeperBountyBps = keeperBps;
        p.personPriceCapBpsPerYear = personCap;
        p.maxTermSeconds = maxTerm;
        p.relayGraceSeconds = grace;
        p.settlementWindow = window;
        p.minCycleInflow = inflow;
        p.gasEstimateAssets = gas;
        bool ok = (uint256(w0) + w1 + w2 > 0) && keeperBps <= 500 && personCap <= 1200
            && uint256(window) >= uint256(maxTerm) + grace && (uint256(inflow) * keeperBps) / 10_000 >= gas;
        if (ok) {
            TidepoolCharterV1 c = _deploy(p);
            assertEq(c.params().keeperBountyBps, keeperBps);
        } else {
            vm.expectRevert();
            _deploy(p);
        }
    }

    // - the ABI has no setter -

    function test_abiHasNoSetter() public view {
        string memory abiJson = vm.readFile("out/TidepoolCharterV1.sol/TidepoolCharterV1.json");
        string[] memory types = vm.parseJsonStringArray(abiJson, ".abi[*].type");
        assertGt(types.length, 0, "abi parsed");
        uint256 fns;
        for (uint256 i; i < types.length; ++i) {
            bytes32 t = keccak256(bytes(types[i]));
            assertTrue(t != keccak256("fallback") && t != keccak256("receive"), "no fallback or receive");
            if (t == keccak256("function")) {
                ++fns;
                string memory sm = vm.parseJsonString(
                    abiJson, string.concat(".abi[", vm.toString(i), "].stateMutability")
                );
                assertTrue(
                    keccak256(bytes(sm)) == keccak256("view") || keccak256(bytes(sm)) == keccak256("pure"),
                    string.concat("function ", vm.parseJsonString(abiJson, string.concat(".abi[", vm.toString(i), "].name")), " mutates")
                );
            }
        }
        assertEq(fns, 3, "exactly params, deployment, charterHash");
    }

    function test_nothingCanBeSentToTheCharter() public {
        TidepoolCharterV1 c = _deploy(_params());
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(c).call{ value: 1 }("");
        assertFalse(ok, "no receive");
        (ok,) = address(c).call(abi.encodeWithSignature("setParams()"));
        assertFalse(ok, "no setter selector");
    }
}
