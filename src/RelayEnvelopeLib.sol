// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @title RelayEnvelopeLib
/// @notice Appendix A.7 and spec 2.9: the envelope every relayed telling from a foreign site carries, and the
///         v0.1 one-relayer check. The calling contract checks `poolId == charter.poolId`, nonce freshness
///         (`Replayed`) and head monotonicity; this library checks what only the envelope and the call
///         context decide: the destination (chain and contract) and the relayer's signature.
/// @dev The signature is EIP-712 typed data over the envelope: domain {name "TidepoolRelayEnvelope",
///      version "1", chainId = dstChainId, verifyingContract = dstContract}, so a signature cannot be
///      replayed on another chain or against another contract even before the destination check. `verify`
///      accepts an EOA relayer (`ecrecover`, low-s only) or a contract relayer (ERC-1271), through
///      OpenZeppelin's `SignatureChecker`. In v0.2 this becomes k-of-n (signstuff-evm P2.4 after the split).
///      `digest` is `pure` here (the spec lists `view`): it reads only the envelope.
library RelayEnvelopeLib {
    struct Envelope {
        uint256 dstChainId;
        address dstContract;
        bytes32 poolId;
        bytes32 srcSite;
        uint64 blockNum;
        bytes32 blockId;
        bytes32 trxId;
        uint32 opIndex;
        bytes32 payloadNi;
        uint64 nonce;
    }

    error WrongDestination();
    error WrongPool();
    error Replayed(uint64 nonce);
    error BadRelayerSignature();

    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant NAME_HASH = keccak256("TidepoolRelayEnvelope");
    bytes32 internal constant VERSION_HASH = keccak256("1");
    bytes32 internal constant ENVELOPE_TYPEHASH = keccak256(
        "Envelope(uint256 dstChainId,address dstContract,bytes32 poolId,bytes32 srcSite,uint64 blockNum,bytes32 blockId,bytes32 trxId,uint32 opIndex,bytes32 payloadNi,uint64 nonce)"
    );

    function domainSeparator(Envelope memory e) internal pure returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, e.dstChainId, e.dstContract));
    }

    function structHash(Envelope memory e) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ENVELOPE_TYPEHASH,
                e.dstChainId,
                e.dstContract,
                e.poolId,
                e.srcSite,
                e.blockNum,
                e.blockId,
                e.trxId,
                e.opIndex,
                e.payloadNi,
                e.nonce
            )
        );
    }

    /// @notice The EIP-712 digest the relayer signs. JS twin: `envelopeDigest` in `tidepool-terms.mjs`.
    function digest(Envelope memory e) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(e), structHash(e)));
    }

    /// @notice Revert unless the envelope is addressed to this chain and this contract and `relayer` signed it.
    function verify(Envelope memory e, bytes memory sig, address relayer) internal view {
        if (e.dstChainId != block.chainid || e.dstContract != address(this)) revert WrongDestination();
        if (!SignatureChecker.isValidSignatureNow(relayer, digest(e), sig)) revert BadRelayerSignature();
    }
}
