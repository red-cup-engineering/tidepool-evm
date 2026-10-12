// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ITidepoolCharterV1 } from "./interfaces/ITidepoolCharterV1.sol";

/// @title TidepoolCharterV1
/// @notice The pool's constitution (spec A.2; capability `tp-site-parameters`): every economic and timing parameter,
///         and the addresses of the twelve contracts the deploy script wires, fixed at construction. There is no
///         setter, no owner, no proxy, no payable path: changing a parameter means deploying another pool.
///         `charterHash` is `keccak256(abi.encode(params, deployment))`, computed once in the constructor so that
///         anyone can compare it with the hash a manifest or an off-chain reader recomputes from `params()` and
///         `deployment()`.
///         Constructor checks (A.2): weight sum nonzero; every bps field <= 10000; `keeperBountyBps <= 500`;
///         `personPriceCapBpsPerYear <= 1200`; `settlementWindow >= maxTermSeconds + relayGraceSeconds`;
///         `minCycleInflow * keeperBountyBps / 1e4 >= gasEstimateAssets`; `vault == 0 || vault.asset() == asset`.
contract TidepoolCharterV1 is ITidepoolCharterV1 {
    uint16 internal constant MAX_BPS = 10_000;
    uint16 internal constant MAX_KEEPER_BOUNTY_BPS = 500;
    uint16 internal constant MAX_PERSON_PRICE_CAP_BPS = 1_200;

    error ZeroWeightSum();
    /// @param field the Params field name
    error BpsAboveMax(bytes32 field, uint256 value, uint256 max);
    error SettlementWindowTooShort(uint256 settlementWindow, uint256 required);
    error BountyBelowGasEstimate(uint256 bounty, uint256 gasEstimateAssets);
    error VaultAssetMismatch(address vault, address vaultAsset, address asset);

    Params private _params;
    Deployment private _deployment;
    bytes32 private immutable _charterHash;

    constructor(Params memory p, Deployment memory d) {
        uint256 weightSum = uint256(p.splitWeights[0]) + p.splitWeights[1] + p.splitWeights[2];
        if (weightSum == 0) revert ZeroWeightSum();

        _bps("memberExposureCapBps", p.memberExposureCapBps, MAX_BPS);
        _bps("floatUtilizationCapBps", p.floatUtilizationCapBps, MAX_BPS);
        _bps("writeoffBudgetBps", p.writeoffBudgetBps, MAX_BPS);
        _bps("priceFractionBps", p.priceFractionBps, MAX_BPS);
        _bps("personPriceCapBpsPerYear", p.personPriceCapBpsPerYear, MAX_PERSON_PRICE_CAP_BPS);
        _bps("vouchCapBps", p.vouchCapBps, MAX_BPS);
        _bps("obligationBondBps", p.obligationBondBps, MAX_BPS);
        _bps("memberBarrierCapBps", p.memberBarrierCapBps, MAX_BPS);
        _bps("barrierCeilingBps", p.barrierCeilingBps, MAX_BPS);
        _bps("keeperBountyBps", p.keeperBountyBps, MAX_KEEPER_BOUNTY_BPS);
        _bps("agentWeightCapBps", p.agentWeightCapBps, MAX_BPS);
        _bps("reseedCapBps", p.reseedCapBps, MAX_BPS);
        _bps("rhoFloorBps", p.rhoFloorBps, MAX_BPS);
        _bps("pegToleranceBps", p.pegToleranceBps, MAX_BPS);
        _bps("demurrageBpsPerCycle", p.demurrageBpsPerCycle, MAX_BPS);

        uint256 required = uint256(p.maxTermSeconds) + p.relayGraceSeconds;
        if (p.settlementWindow < required) revert SettlementWindowTooShort(p.settlementWindow, required);

        uint256 bounty = Math.mulDiv(p.minCycleInflow, p.keeperBountyBps, MAX_BPS);
        if (bounty < p.gasEstimateAssets) revert BountyBelowGasEstimate(bounty, p.gasEstimateAssets);

        if (p.vault != address(0)) {
            address va = IERC4626(p.vault).asset();
            if (va != p.asset) revert VaultAssetMismatch(p.vault, va, p.asset);
        }

        _params = p;
        _deployment = d;
        _charterHash = keccak256(abi.encode(p, d));
    }

    function _bps(bytes32 field, uint256 value, uint256 max) private pure {
        if (value > max) revert BpsAboveMax(field, value, max);
    }

    function params() external view returns (Params memory) {
        return _params;
    }

    function deployment() external view returns (Deployment memory) {
        return _deployment;
    }

    function charterHash() external view returns (bytes32) {
        return _charterHash;
    }
}
