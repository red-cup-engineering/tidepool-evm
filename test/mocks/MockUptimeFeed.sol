// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @notice A Chainlink-style L2 sequencer uptime feed a test can drive. `latestRoundData` answers `0` when the
///         sequencer is up and `1` when it is down; `startedAt` is when the current status began (the recovery
///         time while up). `setDown`, `setUp(recoveredAt)` and `setReverting` give the three behaviors
///         TidepoolTreasuryV1/FloatDeskV1 must handle (spec A2.1): down, recovered-at, and a feed that reverts.
contract MockUptimeFeed {
    int256 private _answer;
    uint256 private _startedAt;
    bool public reverting;

    error FeedUnavailable();

    constructor() {
        _startedAt = 1; // up since forever (startedAt must be non-zero)
    }

    function setDown() external {
        _answer = 1;
        _startedAt = block.timestamp;
    }

    /// @param recoveredAt when the sequencer came back; the treasury waits `uptimeGraceSeconds` after it.
    function setUp(uint256 recoveredAt) external {
        _answer = 0;
        _startedAt = recoveredAt;
    }

    /// @param startedAt zero models a feed that has never reported (fails closed).
    function setStartedAt(uint256 startedAt) external {
        _startedAt = startedAt;
    }

    function setReverting(bool r) external {
        reverting = r;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (reverting) revert FeedUnavailable();
        return (1, _answer, _startedAt, block.timestamp, 1);
    }
}
