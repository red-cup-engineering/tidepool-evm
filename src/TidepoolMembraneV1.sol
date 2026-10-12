// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ITidepoolMembraneV1 } from "./interfaces/ITidepoolMembraneV1.sol";
import { IMembrane } from "@red-cup-engineering/signstuff-evm/interfaces/IMembrane.sol";

/// @title TidepoolMembraneV1
/// @notice Appendix A.1 of the Tidepool specification (revision 3). The membrane every Tidepool
///         `CellLedger` is built with. A closed table of (teller, predicate) -> {sides, relayedAllowed}
///         written once by the deploy script's EOA and then sealed for good.
/// @dev No wildcard predicate, no wildcard teller, no owner, no member roles: a member is never a teller,
///      pool contracts are (spec 2.6), and a sleeve is never a teller either (its cells are told by the
///      treasury and barrier after `SleeveFactoryV1.ownerOf` checks), so `sleeveFactory` is recorded only
///      so the deploy script's wiring can be audited from the membrane. Because `bind` is `onlyDeployer`
///      and ends at `seal()`, the table after seal is immutable: widening a pool's authority is a new
///      deployment, never a governance act. Capability-ledger ids carried: `tp-route-directed-yield-contract`
///      (the interface set), the membrane half of the on-chain vocabulary.
contract TidepoolMembraneV1 is ITidepoolMembraneV1 {
    error BadSides(uint8 sides);
    error ZeroTeller();

    address public immutable deployer;
    address public immutable sleeveFactory;

    bool private _sealed;
    mapping(address teller => mapping(bytes32 predicate => Grant)) private _grants;

    constructor(address deployer_, address sleeveFactory_) {
        deployer = deployer_;
        sleeveFactory = sleeveFactory_;
    }

    modifier onlyDeployer() {
        if (msg.sender != deployer) revert NotDeployer(msg.sender);
        _;
    }

    /// @inheritdoc ITidepoolMembraneV1
    function bind(bytes32 predicate, address teller, uint8 sides, bool relayedAllowed)
        external
        onlyDeployer
    {
        if (_sealed) revert AlreadySealed();
        if (teller == address(0)) revert ZeroTeller();
        if (sides == 0 || sides > 3) revert BadSides(sides);
        _grants[teller][predicate] = Grant(sides, relayedAllowed);
        emit GrantBound(predicate, teller, sides, relayedAllowed);
    }

    /// @inheritdoc ITidepoolMembraneV1
    function seal() external onlyDeployer {
        if (_sealed) revert AlreadySealed();
        _sealed = true;
        emit Sealed();
    }

    /// @inheritdoc ITidepoolMembraneV1
    function isSealed() external view returns (bool) {
        return _sealed;
    }

    /// @inheritdoc ITidepoolMembraneV1
    function grantOf(address teller, bytes32 predicate) external view returns (Grant memory) {
        return _grants[teller][predicate];
    }

    /// @inheritdoc IMembrane
    /// @dev `side` is 0 (for) or 1 (against); any other value is refused. A relayed telling needs
    ///      `relayedAllowed`; a non-relayed telling is admitted by any bound grant with the side bit.
    function admits(address teller, bytes32 predicate, uint8 side, bool relayed)
        external
        view
        returns (bool)
    {
        if (side > 1) return false;
        Grant storage g = _grants[teller][predicate];
        if (g.sides & (uint8(1) << side) == 0) return false;
        return !relayed || g.relayedAllowed;
    }
}
