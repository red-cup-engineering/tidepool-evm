// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Vectors } from "./Vectors.sol";
import { PoolSplitLib } from "../src/PoolSplitLib.sol";

/// @dev External wrapper so `vm.expectRevert` can see the library's internal reverts.
contract PoolSplitHarness {
    function shares(uint256 T, uint256[] memory ws) external pure returns (uint256[] memory) {
        return PoolSplitLib.shares(T, ws);
    }

    function dust(uint256 T, uint256[] memory ws) external pure returns (uint256) {
        return PoolSplitLib.dust(T, ws);
    }

    function split(uint256 T, uint256[] memory ws) external pure returns (uint256[] memory) {
        return PoolSplitLib.split(T, ws);
    }

    function settleCycle(uint256 p, uint256 y, uint256[] memory ws) external pure returns (uint256, uint256[] memory) {
        return PoolSplitLib.settleCycle(p, y, ws);
    }

    function transfer(uint256 i, uint256 j, uint256 x, uint256[] memory l) external pure returns (uint256[] memory) {
        return PoolSplitLib.transfer(i, j, x, l);
    }
}

/// @notice TP-EVM-003 acceptance: every case of lean/pool/{shares,dust,split,settleCycle,transfer}.json passes against
///         `PoolSplitLib` (the `2^256-1` totals and the zero-weight rows included), plus the Lean theorems stated as
///         properties (`split_sum`, `dust_lt_length`, `share_floor_spec`, `share_mono`, `split_le`,
///         `transfer_conserves`, `cycle_conserves`) over fuzzed arbitrary weight lists.
contract PoolSplitVectorsTest is Vectors {
    PoolSplitHarness internal h = new PoolSplitHarness();

    function _uints(string memory J, string memory key) internal pure returns (uint256[] memory out) {
        string[] memory xs = vm.parseJsonStringArray(J, key);
        out = new uint256[](xs.length);
        for (uint256 k; k < xs.length; ++k) out[k] = vm.parseUint(xs[k]);
    }

    function _eq(uint256[] memory a, uint256[] memory b, string memory what) internal pure {
        assertEq(a.length, b.length, string.concat(what, " length"));
        for (uint256 k; k < a.length; ++k) assertEq(a[k], b[k], string.concat(what, " slot ", vm.toString(k)));
    }

    function _sum(uint256[] memory xs) internal pure returns (uint256 s) {
        for (uint256 k; k < xs.length; ++k) s += xs[k];
    }

    // - Lean vectors -

    function test_leanShares() public view {
        string memory J = _lean("pool", "shares");
        uint256 n = _len(J, ".cases");
        assertGt(n, 100);
        for (uint256 i; i < n; ++i) {
            _eq(
                PoolSplitLib.shares(_uint(J, _at(".cases", i, ".args[0]")), _uints(J, _at(".cases", i, ".args[1]"))),
                _uints(J, _at(".cases", i, ".result")),
                string.concat("shares case ", vm.toString(i))
            );
        }
    }

    function test_leanDust() public view {
        string memory J = _lean("pool", "dust");
        uint256 n = _len(J, ".cases");
        assertGt(n, 100);
        for (uint256 i; i < n; ++i) {
            assertEq(
                PoolSplitLib.dust(_uint(J, _at(".cases", i, ".args[0]")), _uints(J, _at(".cases", i, ".args[1]"))),
                _uint(J, _at(".cases", i, ".result")),
                string.concat("dust case ", vm.toString(i))
            );
        }
    }

    function test_leanSplit() public view {
        string memory J = _lean("pool", "split");
        uint256 n = _len(J, ".cases");
        assertGt(n, 100);
        for (uint256 i; i < n; ++i) {
            _eq(
                PoolSplitLib.split(_uint(J, _at(".cases", i, ".args[0]")), _uints(J, _at(".cases", i, ".args[1]"))),
                _uints(J, _at(".cases", i, ".result")),
                string.concat("split case ", vm.toString(i))
            );
        }
    }

    function test_leanSettleCycle() public view {
        string memory J = _lean("pool", "settleCycle");
        uint256 n = _len(J, ".cases");
        assertGt(n, 10);
        for (uint256 i; i < n; ++i) {
            (uint256 p, uint256[] memory out) = PoolSplitLib.settleCycle(
                _uint(J, _at(".cases", i, ".args[0]")),
                _uint(J, _at(".cases", i, ".args[1]")),
                _uints(J, _at(".cases", i, ".args[2]"))
            );
            assertEq(p, _uint(J, _at(".cases", i, ".result[0]")), "principal");
            _eq(out, _uints(J, _at(".cases", i, ".result[1]")), string.concat("settleCycle case ", vm.toString(i)));
        }
    }

    function test_leanTransfer() public view {
        string memory J = _lean("pool", "transfer");
        uint256 n = _len(J, ".cases");
        assertGt(n, 50);
        for (uint256 i; i < n; ++i) {
            _eq(
                PoolSplitLib.transfer(
                    vm.parseJsonUint(J, _at(".cases", i, ".args[0]")),
                    vm.parseJsonUint(J, _at(".cases", i, ".args[1]")),
                    _uint(J, _at(".cases", i, ".args[2]")),
                    _uints(J, _at(".cases", i, ".args[3]"))
                ),
                _uints(J, _at(".cases", i, ".result")),
                string.concat("transfer case ", vm.toString(i))
            );
        }
    }

    function test_leanVectorsCoverTheExtremes() public view {
        // The acceptance names `2^256-1` totals and zero-weight rows: assert the corpus actually has both.
        string memory J = _lean("pool", "split");
        uint256 n = _len(J, ".cases");
        bool sawMax;
        bool sawZeroWeights;
        for (uint256 i; i < n; ++i) {
            if (_uint(J, _at(".cases", i, ".args[0]")) == type(uint256).max) sawMax = true;
            if (_sum(_uints(J, _at(".cases", i, ".args[1]"))) == 0) sawZeroWeights = true;
        }
        assertTrue(sawMax && sawZeroWeights);
    }

    // - the charter's own split: 20/30/50 -

    function test_charterWeightsSplit() public pure {
        uint256[] memory ws = new uint256[](3);
        ws[0] = 2000;
        ws[1] = 3000;
        ws[2] = 5000;
        uint256[] memory out = PoolSplitLib.split(1_000_001, ws);
        assertEq(out[0], 200_001); // 200_000 + the one unit of dust
        assertEq(out[1], 300_000);
        assertEq(out[2], 500_000);
    }

    // - reverts -

    function test_splitEmptyWeightsReverts() public {
        vm.expectRevert(PoolSplitLib.EmptyWeights.selector);
        h.split(5, new uint256[](0));
    }

    function test_sharesAndDustOfEmptyWeights() public view {
        assertEq(PoolSplitLib.shares(5, new uint256[](0)).length, 0);
        assertEq(PoolSplitLib.dust(5, new uint256[](0)), 5);
    }

    function test_weightSumOverflowReverts() public {
        uint256[] memory ws = new uint256[](2);
        ws[0] = type(uint256).max;
        ws[1] = 1;
        vm.expectRevert(); // Panic(0x11)
        h.shares(10, ws);
    }

    function test_transferRevertsOutOfRangeAndOverdraw() public {
        uint256[] memory l = new uint256[](2);
        l[0] = 3;
        l[1] = 4;
        vm.expectRevert(abi.encodeWithSelector(PoolSplitLib.IndexOutOfRange.selector, 2, 2));
        h.transfer(2, 0, 1, l);
        vm.expectRevert(abi.encodeWithSelector(PoolSplitLib.IndexOutOfRange.selector, 5, 2));
        h.transfer(0, 5, 1, l);
        vm.expectRevert(abi.encodeWithSelector(PoolSplitLib.TransferExceedsBalance.selector, 4, 3));
        h.transfer(0, 1, 4, l);
        vm.expectRevert(abi.encodeWithSelector(PoolSplitLib.TransferExceedsBalance.selector, 4, 3));
        h.transfer(0, 0, 4, l);
    }

    function test_transferRevertsOnRecipientOverflow() public {
        uint256[] memory l = new uint256[](2);
        l[0] = 2;
        l[1] = type(uint256).max;
        vm.expectRevert(); // Panic(0x11)
        h.transfer(0, 1, 1, l);
    }

    function test_transferDoesNotMutateItsInput() public pure {
        uint256[] memory l = new uint256[](2);
        l[0] = 9;
        l[1] = 1;
        uint256[] memory out = PoolSplitLib.transfer(0, 1, 4, l);
        assertEq(l[0], 9);
        assertEq(l[1], 1);
        assertEq(out[0], 5);
        assertEq(out[1], 5);
    }

    // - Lean theorems as properties over arbitrary weight lists -

    function _weights(uint256[8] memory raw, uint8 len, uint8 mask) internal pure returns (uint256[] memory ws) {
        uint256 n = bound(len, 1, 8);
        ws = new uint256[](n);
        for (uint256 k; k < n; ++k) {
            // mask zeroes some weights; the rest stay below 2^250 so the sum cannot overflow
            ws[k] = (mask >> k) & 1 == 1 ? 0 : raw[k] >> 6;
        }
    }

    /// @dev split_sum + cycle_conserves + dust_lt_length + share_floor_spec + split_le.
    function testFuzz_splitConservesAndBoundsDust(uint256 T, uint256[8] memory raw, uint8 len, uint8 mask) public pure {
        uint256[] memory ws = _weights(raw, len, mask);
        uint256 w = _sum(ws);
        uint256[] memory s = PoolSplitLib.shares(T, ws);
        uint256[] memory out = PoolSplitLib.split(T, ws);
        uint256 d = PoolSplitLib.dust(T, ws);
        assertEq(_sum(out), T, "split_sum");
        assertEq(_sum(s) + d, T, "shares + dust = T");
        if (w == 0) {
            assertEq(d, T, "zero weights: all dust");
            assertEq(out[0], T, "zero weights: all to bucket 0");
        } else {
            assertLt(d, ws.length, "dust_lt_length");
            for (uint256 k; k < ws.length; ++k) {
                assertLe(s[k], T, "share <= T");
                if (ws[k] == 0) assertEq(s[k], 0, "zero weight, zero share");
                assertLe(out[k], T, "split_le");
            }
        }
    }

    /// @dev share_floor_spec in a range where the product fits: s*W <= T*w < (s+1)*W.
    function testFuzz_shareFloorSpec(uint128 T, uint64[4] memory raw) public pure {
        uint256[] memory ws = new uint256[](4);
        for (uint256 k; k < 4; ++k) ws[k] = raw[k];
        uint256 w = _sum(ws);
        vm.assume(w > 0);
        uint256[] memory s = PoolSplitLib.shares(T, ws);
        for (uint256 k; k < 4; ++k) {
            assertLe(s[k] * w, uint256(T) * ws[k], "floor lower");
            assertLt(uint256(T) * ws[k], (s[k] + 1) * w, "floor upper");
        }
    }

    /// @dev share_mono: a larger total never gives a smaller share, for fixed weights.
    function testFuzz_sharesMonotoneInTotal(uint256 T1, uint256 T2, uint256[8] memory raw, uint8 len, uint8 mask)
        public
        pure
    {
        uint256[] memory ws = _weights(raw, len, mask);
        (uint256 lo, uint256 hi) = T1 <= T2 ? (T1, T2) : (T2, T1);
        uint256[] memory a = PoolSplitLib.shares(lo, ws);
        uint256[] memory b = PoolSplitLib.shares(hi, ws);
        for (uint256 k; k < ws.length; ++k) assertLe(a[k], b[k], "share_mono");
    }

    function testFuzz_settleCycleKeepsPrincipal(uint256 principal, uint256 y, uint256[8] memory raw, uint8 len, uint8 mask)
        public
        pure
    {
        uint256[] memory ws = _weights(raw, len, mask);
        (uint256 p, uint256[] memory out) = PoolSplitLib.settleCycle(principal, y, ws);
        assertEq(p, principal, "principal untouched");
        assertEq(_sum(out), y, "yield conserved");
    }

    function testFuzz_transferConserves(uint256[6] memory raw, uint8 len, uint8 i0, uint8 j0, uint256 x0) public pure {
        uint256 n = bound(len, 1, 6);
        uint256[] memory l = new uint256[](n);
        for (uint256 k; k < n; ++k) l[k] = raw[k] >> 4;
        uint256 i = bound(i0, 0, n - 1);
        uint256 j = bound(j0, 0, n - 1);
        uint256 x = bound(x0, 0, l[i]);
        uint256[] memory out = PoolSplitLib.transfer(i, j, x, l);
        assertEq(_sum(out), _sum(l), "transfer_conserves");
        for (uint256 k; k < n; ++k) {
            if (k != i && k != j) assertEq(out[k], l[k], "other slots untouched");
        }
        if (i != j) {
            assertEq(out[i], l[i] - x);
            assertEq(out[j], l[j] + x);
        }
    }
}
