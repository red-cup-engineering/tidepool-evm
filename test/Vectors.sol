// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";

/// @notice Golden-vector loading for tidepool-evm. Two directories, both read-only (`fs_permissions`):
///           test/vectors/js/    - emitted by `scripts/emit-tidepool-vectors.mjs` (the JS twin): terms, vocabulary,
///                                 the Hive release payload, the relay envelope. Foundry must reproduce every row.
///           test/vectors/lean/  - byte-identical copies of obsmetrologia-conformance/vectors/<group>/<op>.json
///                                 (`{suite, declaration, cases:[{op, args, result}]}`), copied by
///                                 `scripts/sync-lean-vectors.mjs`.
///         Rows are read by index: the cheatcode's wildcard paths do not nest, so row counts are probed.
abstract contract Vectors is Test {
    string internal constant JS_DIR = "test/vectors/js";
    string internal constant LEAN_DIR = "test/vectors/lean";

    function _js(string memory file) internal view returns (string memory) {
        return vm.readFile(string.concat(JS_DIR, "/", file));
    }

    function _lean(string memory group, string memory op) internal view returns (string memory) {
        return vm.readFile(string.concat(LEAN_DIR, "/", group, "/", op, ".json"));
    }

    function _leanExists(string memory group, string memory op) internal view returns (bool) {
        return vm.exists(string.concat(LEAN_DIR, "/", group, "/", op, ".json"));
    }

    /// @dev Number of elements of the array at `key` (".members", ".cases").
    function _len(string memory json, string memory key) internal view returns (uint256 n) {
        while (vm.keyExistsJson(json, string.concat(key, "[", vm.toString(n), "]"))) ++n;
    }

    /// @dev ".members[3].encoded" style path.
    function _at(string memory key, uint256 i, string memory field) internal pure returns (string memory) {
        return string.concat(key, "[", vm.toString(i), "]", field);
    }

    function _str(string memory json, string memory key) internal pure returns (string memory) {
        return vm.parseJsonString(json, key);
    }

    function _hexBytes(string memory json, string memory key) internal pure returns (bytes memory) {
        return vm.parseBytes(string.concat("0x", vm.parseJsonString(json, key)));
    }

    function _bytes32(string memory json, string memory key) internal pure returns (bytes32) {
        return vm.parseJsonBytes32(json, key);
    }

    function _bytes32NoPrefix(string memory json, string memory key) internal pure returns (bytes32) {
        return vm.parseBytes32(string.concat("0x", vm.parseJsonString(json, key)));
    }

    function _addr(string memory json, string memory key) internal pure returns (address) {
        return vm.parseAddress(vm.parseJsonString(json, key));
    }

    /// @dev Decimal strings (the Lean and JS emitters spell big integers as strings).
    function _uint(string memory json, string memory key) internal pure returns (uint256) {
        return vm.parseUint(vm.parseJsonString(json, key));
    }

    function _int(string memory json, string memory key) internal pure returns (int256) {
        return vm.parseInt(vm.parseJsonString(json, key));
    }
}
