// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface ITidepoolTreasuryViewV1 { function totalAssets() external view returns (uint256); function buckets() external view returns (uint256 reserve, uint256 float, uint256 distributable, uint256 held); function cycle() external view returns (uint64 id, uint64 closesAt); function barrierNow() external view returns (uint256 assets); }
