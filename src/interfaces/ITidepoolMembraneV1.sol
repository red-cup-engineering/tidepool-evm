// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.
import { IMembrane } from "@red-cup-engineering/signstuff-evm/interfaces/IMembrane.sol";

interface ITidepoolMembraneV1 is IMembrane {
    struct Grant { uint8 sides; bool relayedAllowed; } // sides bit0 for, bit1 against
    event GrantBound(bytes32 indexed predicate, address indexed teller, uint8 sides, bool relayedAllowed);
    event Sealed();
    error NotDeployer(address caller);
    error AlreadySealed();
    function deployer() external view returns (address);         // immutable; the deploy script's EOA, authority ends at seal()
    function sleeveFactory() external view returns (address);    // immutable (predicted)
    function bind(bytes32 predicate, address teller, uint8 sides, bool relayedAllowed) external; // onlyDeployer, before seal
    function seal() external;                                    // onlyDeployer; irreversible
    function isSealed() external view returns (bool);   // spec spells this `sealed()`, a reserved word in Solidity; renamed (TP-EVM-001 note)
    function grantOf(address teller, bytes32 predicate) external view returns (Grant memory); // argument order as AllowlistMembrane
    /// admits(teller, predicate, side, relayed): bound grant with the side bit and relayedAllowed >= relayed. No member roles.
    /// Sleeves are never tellers: sleeve cells are told by the treasury/barrier after SleeveFactoryV1.ownerOf checks.
}
