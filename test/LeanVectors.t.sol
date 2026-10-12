// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Vectors } from "./Vectors.sol";

/// @notice The copied Lean conformance vectors parse (TP-EVM-001 acceptance): every file of the four copied groups
///         has the `{suite, declaration, cases:[{op, args, result}]}` shape, a non-empty case list, and a result the
///         JSON cheatcode can decode. The pool group's big integers are decimal strings; every numeric string parses
///         as a uint256 (the `2^256-1` totals included). The per-operation judgments are TP-EVM-003 (pool) and
///         signstuff-evm's own LeanConformance test (four, record, valued).
contract LeanVectorsTest is Vectors {
    function _checkFile(string memory group, string memory op) internal view returns (uint256 n) {
        string memory J = _lean(group, op);
        assertTrue(vm.keyExistsJson(J, ".suite"), "suite");
        assertTrue(vm.keyExistsJson(J, ".declaration"), "declaration");
        n = _len(J, ".cases");
        assertGt(n, 0, string.concat(group, "/", op, " has cases"));
        for (uint256 i; i < n; ++i) {
            assertTrue(vm.keyExistsJson(J, _at(".cases", i, ".op")), "op");
            assertTrue(vm.keyExistsJson(J, _at(".cases", i, ".args")), "args");
            assertTrue(vm.keyExistsJson(J, _at(".cases", i, ".result")), "result");
            assertGt(vm.parseJson(J, _at(".cases", i, ".result")).length, 0, "result decodes");
        }
    }

    function test_fourGroupParses() public view {
        string[18] memory ops = [
            "conflate", "equalityLocus", "joinK", "joinT", "kBot", "kTop", "leK", "leT", "meetK", "meetT", "negConf", "negate",
            "readingFuse", "readingMix", "readingPar", "requiresConsensus", "tBot", "tTop"
        ];
        uint256 total;
        for (uint256 i; i < ops.length; ++i) total += _checkFile("four", ops[i]);
        assertGt(total, 100);
    }

    function test_recordGroupParses() public view {
        string[9] memory ops = ["add", "joinK", "joinT", "leK", "leT", "meetK", "meetT", "reading", "topMass"];
        for (uint256 i; i < ops.length; ++i) _checkFile("record", ops[i]);
    }

    function test_valuedGroupParses() public view {
        string[7] memory ops = ["conflate", "joinK", "joinT", "meetK", "meetT", "negate", "presumeFree"];
        for (uint256 i; i < ops.length; ++i) _checkFile("valued", ops[i]);
    }

    function test_poolGroupParses() public view {
        string[8] memory ops = ["degeneracy", "dust", "settleCycle", "shares", "solveL", "solveR", "split", "transfer"];
        for (uint256 i; i < ops.length; ++i) _checkFile("pool", ops[i]);
    }

    /// @dev shares/split results are lists of decimal strings, dust's a decimal string: all parse as uint256.
    function test_poolNumbersParseAsUint256() public view {
        string[2] memory listOps = ["shares", "split"];
        uint256 rows;
        for (uint256 k; k < listOps.length; ++k) {
            string memory J = _lean("pool", listOps[k]);
            uint256 n = _len(J, ".cases");
            for (uint256 i; i < n; ++i) {
                string[] memory xs = vm.parseJsonStringArray(J, _at(".cases", i, ".result"));
                for (uint256 j; j < xs.length; ++j) {
                    vm.parseUint(xs[j]);
                    ++rows;
                }
                string[] memory ws = vm.parseJsonStringArray(J, _at(".cases", i, ".args[1]"));
                for (uint256 j; j < ws.length; ++j) vm.parseUint(ws[j]);
                vm.parseUint(_str(J, _at(".cases", i, ".args[0]")));
            }
        }
        assertGt(rows, 0);
        string memory D = _lean("pool", "dust");
        uint256 m = _len(D, ".cases");
        for (uint256 i; i < m; ++i) vm.parseUint(_str(D, _at(".cases", i, ".result")));
    }

    function test_poolHasMaximalTotals() public view {
        string memory J = _lean("pool", "split");
        uint256 n = _len(J, ".cases");
        bool sawMax;
        for (uint256 i; i < n; ++i) {
            if (_uint(J, _at(".cases", i, ".args[0]")) == type(uint256).max) sawMax = true;
        }
        assertTrue(sawMax, "a 2^256-1 total is present");
    }
}
