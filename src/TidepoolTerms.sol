// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Cbor } from "@red-cup-engineering/signstuff-evm/Cbor.sol";
import { SignCell } from "@red-cup-engineering/signstuff-evm/SignCell.sol";

/// @title TidepoolTerms
/// @notice Appendix A.0b of the Tidepool specification (revision 3): the term and witness encodings every
///         Tidepool cell uses. Each builder returns one canonical-CBOR item (what `CellLedger.Terms` and
///         `tellRelayed`'s `witnessCbor` take). The JS twin is `scripts/lib/tidepool-terms.mjs`; every row of
///         `test/vectors/js/tidepool-terms.json` must be reproduced byte for byte by the builder of the same name.
/// @dev Text only, no OpenZeppelin `Strings` (its `Bytes` dependency is cancun-only and this library should
///      stay usable wherever signstuff-evm is). Hex is always lowercase, so one address has one spelling.
library TidepoolTerms {
    bytes16 private constant HEX = "0123456789abcdef";

    // - spellings -

    /// @dev "0x" + 40 lowercase hex digits.
    function hexAddress(address a) internal pure returns (string memory) {
        return _hex(abi.encodePacked(a));
    }

    /// @dev "0x" + 64 lowercase hex digits.
    function hexBytes32(bytes32 b) internal pure returns (string memory) {
        return _hex(abi.encodePacked(b));
    }

    function decimal(uint256 n) internal pure returns (string memory) {
        if (n == 0) return "0";
        uint256 digits;
        for (uint256 t = n; t != 0; t /= 10) ++digits;
        bytes memory out = new bytes(digits);
        while (n != 0) {
            out[--digits] = bytes1(uint8(48 + (n % 10)));
            n /= 10;
        }
        return string(out);
    }

    /// @dev "-1234" for negatives, plain decimal otherwise; covers `type(int256).min`.
    function signedDecimal(int256 n) internal pure returns (string memory) {
        if (n >= 0) return decimal(uint256(n));
        return string.concat("-", decimal(uint256(-(n + 1)) + 1));
    }

    // - labels (the text before the CBOR wrapper; `scoped` takes one) -

    /// @dev "member:0x<lowercase address>".
    function memberLabel(address member) internal pure returns (bytes memory) {
        return bytes(string.concat("member:", hexAddress(member)));
    }

    /// @dev "sleeve:0x<lowercase address>".
    function sleeveLabel(address sleeve) internal pure returns (bytes memory) {
        return bytes(string.concat("sleeve:", hexAddress(sleeve)));
    }

    /// @dev "<kind>:0x<bytes32>", the label of a draw, obligation, edge, claim, question or clearing id
    ///      when it is the base of a scoped subject (`"q"` -> "q:0x...", `"draw"` -> "draw:0x...").
    function idLabel(string memory kind, bytes32 id) internal pure returns (bytes memory) {
        return bytes(string.concat(kind, ":", hexBytes32(id)));
    }

    // - subjects and objects -

    /// @notice EVM member (chain-agnostic): text "member:0x<lowercase address>".
    function memberTerm(address member) internal pure returns (bytes memory) {
        return Cbor.text(memberLabel(member));
    }

    /// @notice Hive account: text "hive:<account>".
    function hiveTerm(string memory account) internal pure returns (bytes memory) {
        return Cbor.text(string.concat("hive:", account));
    }

    /// @notice Sleeve: text "sleeve:0x<lowercase address>".
    function sleeveTerm(address sleeve) internal pure returns (bytes memory) {
        return Cbor.text(sleeveLabel(sleeve));
    }

    /// @notice Scoped subject `x#n`: text `label + "#" + decimal(n)`, `label` being UTF-8 bytes
    ///         (`memberLabel(a)`, `idLabel("q", id)`, ...). Epoch/version scoping makes a non-monotone
    ///         lifecycle a sequence of cells told once each (spec 2.5 rule 2).
    function scoped(bytes memory label, uint256 n) internal pure returns (bytes memory) {
        return Cbor.text(abi.encodePacked(label, "#", decimal(n)));
    }

    /// @notice A bytes32 identifier (draw, obligation, edge, claim, question, digest) as a CBOR byte string.
    function idTerm(bytes32 id) internal pure returns (bytes memory) {
        return SignCell.bytesTerm(abi.encodePacked(id));
    }

    /// @notice The pool-and-cycle subject, with the site appended unless `caip2` is empty. Spelled
    ///         pool:0x(poolId) AT (decimal cycle) AT (caip2), AT being the at-sign; see A.0b.
    function poolCycleSite(bytes32 poolId, uint64 cycle, string memory caip2) internal pure returns (bytes memory) {
        string memory base = string.concat("pool:", hexBytes32(poolId), "@", decimal(cycle));
        if (bytes(caip2).length == 0) return Cbor.text(base);
        return Cbor.text(string.concat(base, "@", caip2));
    }

    /// @notice Amount in base units: text decimal, never `uintTerm` (that is `uint64`).
    function amountTerm(uint256 amount) internal pure returns (bytes memory) {
        return Cbor.text(decimal(amount));
    }

    /// @notice Signed residue: text signed decimal ("-1234").
    function signedAmountTerm(int256 amount) internal pure returns (bytes memory) {
        return Cbor.text(signedDecimal(amount));
    }

    /// @notice Site: text of its CAIP-2 name ("eip155:84532", "hive:beeab0de...").
    function siteTerm(string memory caip2) internal pure returns (bytes memory) {
        return Cbor.text(caip2);
    }

    /// @notice The 32-byte site id: the identity of the site term (`sha256(siteTerm(caip2))`), used for
    ///         `Site.id`, `Head.site`, `Envelope.srcSite` and the charter's `siteId`.
    function siteId(string memory caip2) internal pure returns (bytes32) {
        return SignCell.termId(siteTerm(caip2));
    }

    /// @notice Cycle, stage: `uintTerm` (a `uint64`).
    function cycleTerm(uint64 cycle) internal pure returns (bytes memory) {
        return SignCell.uintTerm(cycle);
    }

    /// @notice A kind, outcome or formula id spelled as its enum/constant name: text.
    function nameTerm(string memory name) internal pure returns (bytes memory) {
        return Cbor.text(name);
    }

    // - witnesses (CBOR text, what `tellRelayed` takes) -

    /// @notice "member:0x<lowercase address>": one member is one witness on every site.
    function memberWitness(address member) internal pure returns (bytes memory) {
        return memberTerm(member);
    }

    /// @notice "hive:<account>".
    function hiveWitness(string memory account) internal pure returns (bytes memory) {
        return hiveTerm(account);
    }

    /// @notice "ledger:<caip2>:0x<lowercase address>", a foreign ledger contract.
    function ledgerWitness(string memory caip2, address ledger) internal pure returns (bytes memory) {
        return Cbor.text(string.concat("ledger:", caip2, ":", hexAddress(ledger)));
    }

    /// @notice The identity a witness carries in the ledger (`sha256` of its CBOR).
    function witnessId(bytes memory witnessCbor) internal pure returns (bytes32) {
        return SignCell.witnessId(witnessCbor);
    }

    function _hex(bytes memory raw) private pure returns (string memory) {
        bytes memory out = new bytes(2 + raw.length * 2);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < raw.length; ++i) {
            out[2 + 2 * i] = HEX[uint8(raw[i]) >> 4];
            out[3 + 2 * i] = HEX[uint8(raw[i]) & 0xf];
        }
        return string(out);
    }
}
