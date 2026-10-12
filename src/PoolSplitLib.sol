// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title PoolSplitLib
/// @notice Realizer of Lean `Obsmetrologia.Economics.PoolSplit` (spec A.5; capability `tp-cycle-split-20-30-50`):
///         integer apportionment of a total over an arbitrary weight list, judged by `vectors/pool/*.json`.
///         - `shares(T, ws)[k] = floor(T * ws[k] / W)` with `W = sum(ws)`, by full-precision `mulDiv` (no 512-bit
///           overflow for any `T` up to `2^256-1`). Zero total weight: every share is 0 (Lean zero-weight semantics).
///         - `dust(T, ws) = T - sum(shares)`. Always `< ws.length` when `W > 0` (floor loses under one unit per
///           bucket), and exactly `T` when `W == 0`.
///         - `split(T, ws)` = `shares` with the dust added to bucket 0, so `sum(split) == T` for every non-empty
///           list (`split_sum`); with zero total weight the whole of `T` lands in bucket 0.
///         - `settleCycle(principal, yieldAmt, ws)` = `(principal, split(yieldAmt, ws))`: principal is never touched
///           (`cycle_conserves`).
///         - `transfer(i, j, x, l)` moves `x` from slot `i` to slot `j` (`transfer_conserves`); stated with its
///           hypotheses `i, j < l.length` and `x <= l[i]`, which revert rather than truncate. The input is not mutated.
///         Every function is `internal pure` and allocates its result; none touches storage.
library PoolSplitLib {
    /// @dev Sums are checked arithmetic: a weight sum above `2^256-1` reverts (Panic 0x11), it never wraps.
    error EmptyWeights();
    error IndexOutOfRange(uint256 index, uint256 length);
    error TransferExceedsBalance(uint256 amount, uint256 balance);

    function _sum(uint256[] memory ws) private pure returns (uint256 w) {
        for (uint256 k; k < ws.length; ++k) w += ws[k];
    }

    /// @notice Floor shares of `T` by weights `ws`. Zero total weight yields all zeros.
    function shares(uint256 T, uint256[] memory ws) internal pure returns (uint256[] memory out) {
        out = new uint256[](ws.length);
        uint256 w = _sum(ws);
        if (w == 0) return out;
        for (uint256 k; k < ws.length; ++k) out[k] = Math.mulDiv(T, ws[k], w);
    }

    /// @notice What the floors leave over: `T - sum(shares)`.
    function dust(uint256 T, uint256[] memory ws) internal pure returns (uint256 d) {
        uint256[] memory s = shares(T, ws);
        uint256 total;
        for (uint256 k; k < s.length; ++k) total += s[k];
        d = T - total; // total <= T because sum(floor(T*w_k/W)) <= T * W / W
    }

    /// @notice Conserving split: `sum(result) == T`. Dust goes to bucket 0. Empty `ws` has no bucket 0 and reverts.
    function split(uint256 T, uint256[] memory ws) internal pure returns (uint256[] memory out) {
        if (ws.length == 0) revert EmptyWeights();
        out = shares(T, ws);
        uint256 total;
        for (uint256 k; k < out.length; ++k) total += out[k];
        out[0] += T - total;
    }

    /// @notice One cycle: principal passes through unchanged, the yield is split.
    function settleCycle(uint256 principal, uint256 yieldAmt, uint256[] memory ws)
        internal
        pure
        returns (uint256, uint256[] memory)
    {
        return (principal, split(yieldAmt, ws));
    }

    /// @notice Move `x` from slot `i` to slot `j` of `l`. `i == j` is the identity (still range- and balance-checked).
    function transfer(uint256 i, uint256 j, uint256 x, uint256[] memory l)
        internal
        pure
        returns (uint256[] memory out)
    {
        uint256 n = l.length;
        if (i >= n) revert IndexOutOfRange(i, n);
        if (j >= n) revert IndexOutOfRange(j, n);
        if (x > l[i]) revert TransferExceedsBalance(x, l[i]);
        out = new uint256[](n);
        for (uint256 k; k < n; ++k) out[k] = l[k];
        if (i == j) return out;
        out[i] = l[i] - x;
        out[j] = l[j] + x;
    }
}
