// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { CellLedger } from "@red-cup-engineering/signstuff-evm/CellLedger.sol";
import { SignCell } from "@red-cup-engineering/signstuff-evm/SignCell.sol";
import { TidepoolMembraneV1 } from "../src/TidepoolMembraneV1.sol";
import { ITidepoolMembraneV1 } from "../src/interfaces/ITidepoolMembraneV1.sol";
import { TidepoolPredicates as P } from "../src/TidepoolPredicates.sol";

contract Teller {
    function tell(CellLedger l, CellLedger.Terms calldata t, SignCell.Side s) external {
        l.tell(t, s);
    }

    function tellRelayed(CellLedger l, CellLedger.Terms calldata t, SignCell.Side s, bytes calldata w) external {
        l.tellRelayed(t, s, w);
    }
}

contract TidepoolMembraneV1Test is Test {
    TidepoolMembraneV1 internal m;
    CellLedger internal ledger;
    Teller internal pool;
    address internal deployer = makeAddr("deployer");
    address internal factory = makeAddr("factory");
    address internal member = makeAddr("member");

    bytes32 internal ADMITTED;
    bytes32 internal HEAD;

    function setUp() public {
        m = new TidepoolMembraneV1(deployer, factory);
        ledger = new CellLedger(m, CellLedger.WitnessScope.ChainScoped);
        pool = new Teller();
        ADMITTED = P.id(P.ADMITTED_BY);
        HEAD = P.id(P.HEAD_OF);
    }

    function _terms(string memory predicate) internal pure returns (CellLedger.Terms memory) {
        return CellLedger.Terms({
            subject: SignCell.textTerm("subject"),
            predicate: SignCell.textTerm(predicate),
            object: SignCell.textTerm("object")
        });
    }

    function test_immutables() public view {
        assertEq(m.deployer(), deployer);
        assertEq(m.sleeveFactory(), factory);
        assertFalse(m.isSealed());
    }

    function test_bindOnlyDeployer() public {
        vm.expectRevert(abi.encodeWithSelector(ITidepoolMembraneV1.NotDeployer.selector, member));
        vm.prank(member);
        m.bind(ADMITTED, address(pool), 1, false);
        vm.expectRevert(abi.encodeWithSelector(ITidepoolMembraneV1.NotDeployer.selector, member));
        vm.prank(member);
        m.seal();
    }

    function test_bindValidates() public {
        vm.startPrank(deployer);
        vm.expectRevert(TidepoolMembraneV1.ZeroTeller.selector);
        m.bind(ADMITTED, address(0), 1, false);
        vm.expectRevert(abi.encodeWithSelector(TidepoolMembraneV1.BadSides.selector, 0));
        m.bind(ADMITTED, address(pool), 0, false);
        vm.expectRevert(abi.encodeWithSelector(TidepoolMembraneV1.BadSides.selector, 4));
        m.bind(ADMITTED, address(pool), 4, false);
        vm.stopPrank();
    }

    function test_grantOfAndEvent() public {
        vm.expectEmit(true, true, false, true, address(m));
        emit ITidepoolMembraneV1.GrantBound(ADMITTED, address(pool), 3, true);
        vm.prank(deployer);
        m.bind(ADMITTED, address(pool), 3, true);
        ITidepoolMembraneV1.Grant memory g = m.grantOf(address(pool), ADMITTED);
        assertEq(g.sides, 3);
        assertTrue(g.relayedAllowed);
        // argument order: teller first, then predicate; the reverse reads empty
        assertEq(m.grantOf(address(pool), HEAD).sides, 0);
    }

    function test_admitsSideAndRelayedSemantics() public {
        vm.startPrank(deployer);
        m.bind(ADMITTED, address(pool), 1, false); // for only, not relayed
        m.bind(HEAD, address(pool), 2, true); // against only, relayed
        vm.stopPrank();
        assertTrue(m.admits(address(pool), ADMITTED, 0, false));
        assertFalse(m.admits(address(pool), ADMITTED, 1, false));
        assertFalse(m.admits(address(pool), ADMITTED, 0, true));
        assertFalse(m.admits(address(pool), HEAD, 0, false));
        assertTrue(m.admits(address(pool), HEAD, 1, false));
        assertTrue(m.admits(address(pool), HEAD, 1, true));
        assertFalse(m.admits(address(pool), ADMITTED, 2, false)); // out-of-range side
        assertFalse(m.admits(address(pool), bytes32(0), 0, false)); // no wildcard predicate
        assertFalse(m.admits(address(0), ADMITTED, 0, false)); // no wildcard teller
    }

    function test_sealEndsBind() public {
        vm.startPrank(deployer);
        m.bind(ADMITTED, address(pool), 1, false);
        vm.expectEmit(address(m));
        emit ITidepoolMembraneV1.Sealed();
        m.seal();
        assertTrue(m.isSealed());
        vm.expectRevert(ITidepoolMembraneV1.AlreadySealed.selector);
        m.bind(HEAD, address(pool), 1, false);
        vm.expectRevert(ITidepoolMembraneV1.AlreadySealed.selector);
        m.seal();
        vm.stopPrank();
        // the table is unchanged and still serves
        assertTrue(m.admits(address(pool), ADMITTED, 0, false));
    }

    function test_ledgerAcceptsBoundContractAndRelayOnlyWhereAllowed() public {
        vm.startPrank(deployer);
        m.bind(ADMITTED, address(pool), 1, false);
        m.bind(HEAD, address(pool), 1, true);
        m.seal();
        vm.stopPrank();

        pool.tell(ledger, _terms(P.ADMITTED_BY), SignCell.Side.For);

        bytes memory w = SignCell.textTerm("ledger:eip155:8453:0x0000000000000000000000000000000000000001");
        // relayed not allowed for ADMITTED
        CellLedger.Terms memory a = _terms(P.ADMITTED_BY);
        vm.expectRevert();
        pool.tellRelayed(ledger, a, SignCell.Side.For, w);
        // relayed allowed for HEAD
        pool.tellRelayed(ledger, _terms(P.HEAD_OF), SignCell.Side.For, w);
        // against ADMITTED was never granted
        vm.expectRevert();
        pool.tell(ledger, a, SignCell.Side.Against);
    }

    function test_chainScopedWitnessIsPerSite() public {
        vm.prank(deployer);
        m.bind(ADMITTED, address(pool), 1, false);
        pool.tell(ledger, _terms(P.ADMITTED_BY), SignCell.Side.For);
        // the telling's witness is the pool contract scoped to this chain: eip155:<chainid>:0x...
        bytes32 cell = SignCell.cellId(
            SignCell.textTerm("subject"), SignCell.textTerm(P.ADMITTED_BY), SignCell.textTerm("object")
        );
        bytes32 w = SignCell.witnessId(SignCell.scopedAccountWitness(block.chainid, address(pool)));
        bytes32 agnostic = SignCell.witnessId(SignCell.accountWitness(address(pool)));
        assertTrue(w != agnostic);
        assertEq(ledger.witnessScope() == CellLedger.WitnessScope.ChainScoped, true);
        assertTrue(cell != bytes32(0));
    }

    /// Fuzz: any EOA (member or stranger) is refused on every Tidepool predicate, on both sides, relayed or not.
    function testFuzz_noEoaIsAdmitted(address eoa, uint256 pick, uint8 side, bool relayed) public {
        vm.assume(eoa != address(pool));
        bytes32[35] memory preds = _allPredicateIds();
        bytes32 p = preds[pick % preds.length];
        vm.prank(deployer);
        m.bind(p, address(pool), 3, true);
        vm.prank(deployer);
        m.seal();
        assertFalse(m.admits(eoa, p, side % 2, relayed));
        assertTrue(m.admits(address(pool), p, side % 2, relayed));
        // through a ledger: an EOA calling tell is refused NotAdmitted
        CellLedger.Terms memory t = _terms(P.ADMITTED_BY);
        vm.expectRevert(
            abi.encodeWithSelector(
                CellLedger.NotAdmitted.selector,
                eoa,
                P.id(P.ADMITTED_BY),
                side % 2 == 0 ? SignCell.Side.For : SignCell.Side.Against,
                false
            )
        );
        vm.prank(eoa);
        ledger.tell(t, side % 2 == 0 ? SignCell.Side.For : SignCell.Side.Against);
    }

    function test_memberIsRefusedOnEveryPredicateBothSides() public {
        bytes32[35] memory preds = _allPredicateIds();
        vm.startPrank(deployer);
        for (uint256 i; i < preds.length; ++i) {
            m.bind(preds[i], address(pool), 3, true);
        }
        m.seal();
        vm.stopPrank();
        for (uint256 i; i < preds.length; ++i) {
            for (uint8 s; s < 2; ++s) {
                assertFalse(m.admits(member, preds[i], s, false));
                assertFalse(m.admits(member, preds[i], s, true));
                assertTrue(m.admits(address(pool), preds[i], s, true));
            }
        }
        assertFalse(m.admits(factory, preds[0], 0, false)); // the factory is not a teller either
    }

    function _allPredicateIds() internal pure returns (bytes32[35] memory r) {
        string[35] memory n = [
            P.ADMITTED_BY, P.MEMBER_KIND, P.AGENT_DISCLOSURE, P.RETIRED_AT, P.SPONSORED_BY, P.YIELD_ROUTED,
            P.BARRIER_DECLARED, P.STAGE_DECLARED, P.OBLIGATION_DUE, P.OBLIGATION_SETTLED, P.CONTESTED_BY,
            P.RELEASED_TO, P.DRAW_SETTLED_BY, P.OVERDUE_AT, P.LATE_SETTLED_AT, P.VOIDED_AT, P.FX_RESIDUE,
            P.CYCLE_TOTAL, P.BUCKET, P.SECTION_DIGEST, P.HEAD_OF, P.H1_RANK, P.QUESTION_OPENED, P.ASSENTED_TO,
            P.OBJECTED_TO, P.WITHDREW_FROM, P.REJOINED, P.QUIESCED, P.EXECUTED, P.OWED_TO, P.ADMITTED_OWED,
            P.CLEARED, P.CLAIMED_RESEED, P.RESEEDED, P.SETTLED_BY
        ];
        for (uint256 i; i < 35; ++i) {
            r[i] = P.id(n[i]);
        }
    }
}
