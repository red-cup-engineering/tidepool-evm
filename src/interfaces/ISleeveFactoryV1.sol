// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Appendix A of the Tidepool specification, revision 3 (2026-10-08), copied by script from the spec text.

interface ISleeveFactoryV1 {
    event SleeveDeployed(address indexed owner, address indexed sleeve);
    error SleeveExists(address owner);
    function implementation() external view returns (address);
    function sleeveOf(address owner) external view returns (address);
    function ownerOf(address sleeve) external view returns (address); // address(0) if not a factory sleeve
    function predictSleeve(address owner) external view returns (address);
    function deploySleeve(address owner) external returns (address sleeve); // permissionless
}
