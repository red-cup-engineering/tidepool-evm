/**
 * tidepool-evm - JS twin of RelayEnvelopeLib.sol (spec 2.9, Appendix A.7).
 *
 * The relayer signs EIP-712 typed data: domain {name "TidepoolRelayEnvelope", version "1", chainId =
 * dstChainId, verifyingContract = dstContract}, primary type `Envelope`. `envelopeDigest` is the 32-byte
 * digest the contract recomputes; `signEnvelope` signs it raw (no EIP-191 prefix) with a caller-supplied
 * viem account. No key is read here.
 */
import { hashTypedData } from "viem";

export const ENVELOPE_TYPES = {
  Envelope: [
    { name: "dstChainId", type: "uint256" },
    { name: "dstContract", type: "address" },
    { name: "poolId", type: "bytes32" },
    { name: "srcSite", type: "bytes32" },
    { name: "blockNum", type: "uint64" },
    { name: "blockId", type: "bytes32" },
    { name: "trxId", type: "bytes32" },
    { name: "opIndex", type: "uint32" },
    { name: "payloadNi", type: "bytes32" },
    { name: "nonce", type: "uint64" },
  ],
};

/** Normalize an envelope to viem's message types (bigint for uint256/uint64, number for uint32). */
export const normalizeEnvelope = (e) => ({
  dstChainId: BigInt(e.dstChainId),
  dstContract: e.dstContract.toLowerCase(),
  poolId: e.poolId,
  srcSite: e.srcSite,
  blockNum: BigInt(e.blockNum),
  blockId: e.blockId,
  trxId: e.trxId,
  opIndex: Number(e.opIndex),
  payloadNi: e.payloadNi,
  nonce: BigInt(e.nonce),
});

export const envelopeDomain = (e) => ({
  name: "TidepoolRelayEnvelope",
  version: "1",
  chainId: BigInt(e.dstChainId),
  verifyingContract: e.dstContract.toLowerCase(),
});

export const envelopeDigest = (e) =>
  hashTypedData({ domain: envelopeDomain(e), types: ENVELOPE_TYPES, primaryType: "Envelope", message: normalizeEnvelope(e) });

/** @param account a viem local account (`privateKeyToAccount`); returns the 65-byte r||s||v signature. */
export const signEnvelope = (account, e) => account.sign({ hash: envelopeDigest(e) });

/** The envelope as JSON-safe strings (what the vector files and the SDK carry). */
export const envelopeJson = (e) => {
  const n = normalizeEnvelope(e);
  return {
    dstChainId: n.dstChainId.toString(), dstContract: n.dstContract, poolId: n.poolId, srcSite: n.srcSite,
    blockNum: n.blockNum.toString(), blockId: n.blockId, trxId: n.trxId, opIndex: n.opIndex,
    payloadNi: n.payloadNi, nonce: n.nonce.toString(),
  };
};
