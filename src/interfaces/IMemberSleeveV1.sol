// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface IMemberSleeveV1 {
    enum Mode { OwnerOnly, StandingInstruction }
    struct RoutingInstruction { uint16 bps; uint256 capPerCycle; Mode mode; }
    struct BarrierJoules { uint256 amount; uint8 unit; uint256 usdPerKwhE6; uint32 asOf; uint256 assetsDeclared; }
    event Deposited(address indexed owner, uint256 assets, uint256 shares, uint256 principalHighWater);
    event PrincipalRedeemed(address indexed owner, uint256 assets, uint256 shares, uint256 principalHighWater);
    event SurplusRedeemed(address indexed owner, uint256 assets, uint256 shares);
    event LossRealized(address indexed owner, uint256 previousHighWater, uint256 newHighWater);
    event YieldRouted(address indexed owner, address indexed treasury, uint64 indexed cycle, uint256 assets, uint256 shares, bytes32 yieldEvidence);
    event Reseeded(address indexed owner, uint256 assets, uint256 principalHighWater);
    event InstructionSet(address indexed owner, uint16 bps, uint256 capPerCycle, Mode mode);
    event BarrierDeclared(address indexed owner, uint32 n, BarrierJoules barrier);
    event StageDeclared(address indexed owner, uint32 n, uint8 stage);
    error NotOwner(address caller); error NotMutual(address caller); error ModeBDisabled(); error SlippageExceeded(uint256 shares, uint256 minShares);
    error ExceedsRedeemable(uint256 requested, uint256 redeemable); error ExceedsSurplus(uint256 requested, uint256 surplus); error ExceedsCap(uint256 requested, uint256 cap); error InvalidStage(uint8 stage);
    function owner() external view returns (address);
    function principalHighWater() external view returns (uint256);
    function totalValue() external view returns (uint256);
    function redeemablePrincipal() external view returns (uint256);   // min(HWM, totalValue, vault.maxWithdraw(this))
    function surplus() external view returns (uint256);               // totalValue - HWM, floored at 0
    function routableYield() external view returns (uint256);         // same as surplus
    function deposit(uint256 assets, uint256 minShares) external returns (uint256 shares);
    function redeemPrincipal(uint256 assets, address to) external returns (uint256 shares);
    function redeemAll(address to) external returns (uint256 assets);
    function redeemSurplus(uint256 assets, address to) external returns (uint256 shares);
    function routeYield(uint256 maxAssets) external returns (uint256 assets);
    function receiveReseed(uint256 assets) external;                 // onlyMutual via treasury; raises HWM
    function setInstruction(RoutingInstruction calldata i) external;
    function declareBarrier(BarrierJoules calldata b) external;      // forwards to BarrierSeriesV1.recordSleeveBarrier(owner, ...)
    function declareStage(uint8 stage) external;
    function instruction() external view returns (RoutingInstruction memory);
    function barrier() external view returns (BarrierJoules memory);
    function stage() external view returns (uint8);
}
