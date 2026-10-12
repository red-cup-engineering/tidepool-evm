/**
 * tidepool-evm - JS twin of TidepoolPredicates.sol and TidepoolTerms.sol (Appendix A.0 and A.0b).
 *
 * A *term* here is the JS value signstuff-evm's `cell-address.mjs` encodes (string -> CBOR text,
 * Uint8Array -> CBOR byte string, number -> CBOR uint); `encodeTerm(term)` is the exact byte string the
 * Solidity builder of the same name returns. Cell ids are SignCell's content address of the triple, so a
 * cell id is identical on Hive, on the EVM and here. `scripts/emit-tidepool-vectors.mjs` writes this
 * module's outputs to `test/vectors/js/`; Foundry (`test/TidepoolTerms.t.sol`), `tidepool-hive` and
 * `tidepool-sdk` all read those files.
 */
import {
  cellIdHex, encodeTerm, hexToBytes, niOfHex, sectionDigestHex, sha256Hex, termIdHex,
} from "@red-cup-engineering/signstuff-evm/cell-address";

export { cellIdHex, encodeTerm, hexToBytes, niOfHex, sectionDigestHex, sha256Hex, termIdHex };

// - A.0: the predicate vocabulary: [Solidity constant, name]; order is the Solidity file's -
export const PREDICATES = [
  ["ADMITTED_BY", "tidepool:admittedBy"],
  ["MEMBER_KIND", "tidepool:memberKind"],
  ["AGENT_DISCLOSURE", "tidepool:agentDisclosure"],
  ["RETIRED_AT", "tidepool:retiredAt"],
  ["SPONSORED_BY", "tidepool:sponsoredBy"],
  ["YIELD_ROUTED", "tidepool:yieldRouted"],
  ["BARRIER_DECLARED", "tidepool:barrierDeclared"],
  ["STAGE_DECLARED", "tidepool:stageDeclared"],
  ["OBLIGATION_DUE", "tidepool:obligationDue"],
  ["OBLIGATION_SETTLED", "tidepool:obligationSettled"],
  ["CONTESTED_BY", "tidepool:contestedBy"],
  ["RELEASED_TO", "tidepool:releasedTo"],
  ["DRAW_SETTLED_BY", "tidepool:drawSettledBy"],
  ["OVERDUE_AT", "tidepool:overdueAt"],
  ["LATE_SETTLED_AT", "tidepool:lateSettledAt"],
  ["VOIDED_AT", "tidepool:voidedAt"],
  ["FX_RESIDUE", "tidepool:fxResidue"],
  ["CYCLE_TOTAL", "tidepool:cycleTotal"],
  ["BUCKET", "tidepool:bucket"],
  ["SECTION_DIGEST", "tidepool:sectionDigest"],
  ["HEAD_OF", "tidepool:headOf"],
  ["H1_RANK", "tidepool:h1Rank"],
  ["QUESTION_OPENED", "tidepool:questionOpened"],
  ["ASSENTED_TO", "tidepool:assentedTo"],
  ["OBJECTED_TO", "tidepool:objectedTo"],
  ["WITHDREW_FROM", "tidepool:withdrewFrom"],
  ["REJOINED", "tidepool:rejoined"],
  ["QUIESCED", "tidepool:quiesced"],
  ["EXECUTED", "tidepool:executed"],
  ["OWED_TO", "tidepool:owedTo"],
  ["ADMITTED_OWED", "tidepool:admittedOwed"],
  ["CLEARED", "tidepool:cleared"],
  ["CLAIMED_RESEED", "tidepool:claimedReseed"],
  ["RESEEDED", "tidepool:reseeded"],
  ["SETTLED_BY", "tidepool:settledBy"],
];

/** name -> predicate name by Solidity constant, e.g. `P.ADMITTED_BY === "tidepool:admittedBy"`. */
export const P = Object.freeze(Object.fromEntries(PREDICATES));

/** A predicate's term is its name as text. `id(name) = sha256(textTerm(name))`, 64 lowercase hex digits. */
export const predicateTerm = (name) => name;
export const predicateId = (name) => termIdHex(name);

// - A.0b: spellings (lowercase hex always) -
const strip0x = (h) => h.replace(/^0x/i, "").toLowerCase();
export const hexAddress = (address) => {
  const h = strip0x(address);
  if (!/^[0-9a-f]{40}$/.test(h)) throw new Error(`not an address: ${address}`);
  return `0x${h}`;
};
export const hexBytes32 = (b32) => {
  const h = strip0x(b32);
  if (!/^[0-9a-f]{64}$/.test(h)) throw new Error(`not a bytes32: ${b32}`);
  return `0x${h}`;
};
export const decimal = (n) => {
  const v = BigInt(n);
  if (v < 0n || v >= 1n << 256n) throw new Error(`not a uint256: ${n}`);
  return v.toString(10);
};
export const signedDecimal = (n) => {
  const v = BigInt(n);
  if (v < -(1n << 255n) || v >= 1n << 255n) throw new Error(`not an int256: ${n}`);
  return v.toString(10);
};

// - labels: the text before the term wrapper (`scoped` takes one) -
export const memberLabel = (address) => `member:${hexAddress(address)}`;
export const sleeveLabel = (address) => `sleeve:${hexAddress(address)}`;
export const idLabel = (kind, id) => `${kind}:${hexBytes32(id)}`;

// - subjects and objects (JS terms; pass to encodeTerm / cellIdHex) -
export const memberTerm = (address) => memberLabel(address);
export const hiveTerm = (account) => `hive:${account}`;
export const sleeveTerm = (address) => sleeveLabel(address);
export const scoped = (label, n) => `${label}#${decimal(n)}`;
/** bytes32 identifier (draw, obligation, edge, claim, question, digest) as a CBOR byte string. */
export const idTerm = (id) => hexToBytes(hexBytes32(id));
export const poolCycleSite = (poolId, cycle, caip2 = "") =>
  `pool:${hexBytes32(poolId)}@${decimal(cycle)}${caip2 === "" ? "" : `@${caip2}`}`;
export const amountTerm = (amount) => decimal(amount);
export const signedAmountTerm = (amount) => signedDecimal(amount);
export const siteTerm = (caip2) => caip2;
/** 32-byte site id: the identity of the site term. */
export const siteId = (caip2) => termIdHex(siteTerm(caip2));
export const cycleTerm = (cycle) => {
  if (!Number.isSafeInteger(cycle) || cycle < 0) throw new Error(`cycle out of the JS safe range: ${cycle}`);
  return cycle;
};
export const nameTerm = (name) => name;

// - witnesses (JS carrier values; Solidity encodes them to CBOR text) -
export const memberWitness = (address) => memberTerm(address);
export const hiveWitness = (account) => hiveTerm(account);
export const ledgerWitness = (caip2, address) => `ledger:${caip2}:${hexAddress(address)}`;
export const witnessId = (witness) => termIdHex(witness);

// - cells -
/** Content address of a Tidepool cell: `predicate` is a name from PREDICATES (or any text term). */
export const cellId = (subject, predicateName, object) => cellIdHex(subject, predicateTerm(predicateName), object);
