#!/usr/bin/env node
/**
 * Emit the Tidepool term, vocabulary, Hive-payload and relay-envelope fixtures into test/vectors/js/.
 *
 *   node scripts/emit-tidepool-vectors.mjs           write test/vectors/js/{tidepool-terms,tidepool-vocab,hive-release-payload,relay-envelope}.json
 *   node scripts/emit-tidepool-vectors.mjs --check   fail if the files on disk differ from a fresh emission
 *
 * Readers: test/TidepoolTerms.t.sol, test/TidepoolPredicates.t.sol, test/RelayEnvelopeLib.t.sol (Foundry),
 * and the fixture tests of tidepool-hive and tidepool-sdk. Everything here is synthetic: addresses, block
 * ids and transaction ids are fixtures, the relayer key is anvil's public default key 0, no network is touched.
 */
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { privateKeyToAccount } from "viem/accounts";
import {
  PREDICATES, P, amountTerm, cellId, cycleTerm, encodeTerm, hexAddress, hexBytes32, hexToBytes, hiveTerm,
  hiveWitness, idLabel, idTerm, ledgerWitness, memberLabel, memberTerm, memberWitness, niOfHex, poolCycleSite,
  predicateId, predicateTerm, scoped, sectionDigestHex, sha256Hex, signedAmountTerm, siteId, siteTerm,
  sleeveLabel, sleeveTerm, termIdHex, witnessId,
} from "./lib/tidepool-terms.mjs";
import { envelopeDigest, envelopeJson, signEnvelope } from "./lib/relay-envelope.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, "..", "test", "vectors", "js");
const check = process.argv.includes("--check");
const header = (schema) => ({ schema: `tidepool-evm/${schema}@1`, source: "js", generator: "scripts/emit-tidepool-vectors.mjs" });
const enc = encodeTerm;
const files = {};

// - fixtures -
const ADDRESSES = [
  "0x0000000000000000000000000000000000000000",
  "0x0000000000000000000000000000000000000001",
  "0xAbCdEf0000000000000000000000000000000001",
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // anvil account 0
  "0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF",
];
const B32 = [
  "0x" + "00".repeat(32),
  "0x" + "ff".repeat(32),
  "0x" + sha256Hex(Buffer.from("tidepool-evm fixture one")),
  "0x" + sha256Hex(Buffer.from("tidepool-evm fixture two")),
];
const POOL_ID = B32[2];
const HIVE_CAIP2 = "hive:beeab0de00000000000000000000000000000000";
const BASE_SEPOLIA = "eip155:84532";
const CHIADO = "eip155:10200";

// - tidepool-terms.json -
files["tidepool-terms.json"] = {
  ...header("tidepool-terms"),
  members: ADDRESSES.map((a) => ({ address: a, label: memberLabel(a), encoded: enc(memberTerm(a)), witnessId: witnessId(memberWitness(a)) })),
  sleeves: ADDRESSES.map((a) => ({ address: a, label: sleeveLabel(a), encoded: enc(sleeveTerm(a)) })),
  hives: ["alice", "tidepool-pool", "a", "x.y-z"].map((account) => ({
    account, encoded: enc(hiveTerm(account)), witness: enc(hiveWitness(account)), witnessId: witnessId(hiveWitness(account)),
  })),
  // `kind` member and sleeve take an address in `arg`; any other kind takes a bytes32 and is spelled `kind:0x...`
  scoped: [
    ["member", ADDRESSES[2], 0], ["member", ADDRESSES[2], 3], ["member", ADDRESSES[3], 4294967295],
    ["sleeve", ADDRESSES[1], 1], ["q", B32[2], 2], ["draw", B32[3], 7], ["q", B32[1], 18446744073709551615n],
  ].map(([kind, arg, n]) => {
    const label = kind === "member" ? memberLabel(arg) : kind === "sleeve" ? sleeveLabel(arg) : idLabel(kind, arg);
    return { kind, arg, n: n.toString(), label, encoded: enc(scoped(label, n)) };
  }),
  ids: B32.map((id) => ({ id, encoded: enc(idTerm(id)) })),
  poolCycleSites: [
    [POOL_ID, 7, BASE_SEPOLIA], [POOL_ID, 0, CHIADO], [POOL_ID, 7, HIVE_CAIP2], [B32[1], 4294967295, BASE_SEPOLIA], [POOL_ID, 12, ""],
  ].map(([poolId, cycle, caip2]) => ({ poolId, cycle: String(cycle), caip2, encoded: enc(poolCycleSite(poolId, cycle, caip2)) })),
  amounts: ["0", "1", "999999", "1000000", "25000000", "18446744073709551615", "18446744073709551616", (1n << 255n).toString(), ((1n << 256n) - 1n).toString()]
    .map((value) => ({ value, encoded: enc(amountTerm(value)) })),
  signedAmounts: ["0", "-1", "1", "-1234", "1234", (-(1n << 255n)).toString(), ((1n << 255n) - 1n).toString()]
    .map((value) => ({ value, encoded: enc(signedAmountTerm(value)) })),
  sites: [BASE_SEPOLIA, CHIADO, HIVE_CAIP2, "eip155:1"].map((caip2) => ({ caip2, encoded: enc(siteTerm(caip2)), id: "0x" + siteId(caip2) })),
  ledgers: [[BASE_SEPOLIA, ADDRESSES[2]], [CHIADO, ADDRESSES[4]], ["eip155:42161", ADDRESSES[1]]].map(([caip2, address]) => ({
    caip2, address, witness: enc(ledgerWitness(caip2, address)), witnessId: witnessId(ledgerWitness(caip2, address)),
  })),
  cycles: [0, 1, 7, 23, 24, 255, 256, 65535, 65536, 4294967295, 4294967296].map((value) => ({ value: String(value), encoded: enc(cycleTerm(value)) })),
  // lifecycle cells (A.0c): the builders composed the way the contracts will; cellId is SignCell's address of the triple
  cells: [
    { name: "admittedBy", member: ADDRESSES[2], digest: B32[3],
      s: memberTerm(ADDRESSES[2]), p: P.ADMITTED_BY, o: idTerm(B32[3]) },
    { name: "retiredAt", member: ADDRESSES[3], epoch: "2", cycle: "9",
      s: scoped(memberLabel(ADDRESSES[3]), 2), p: P.RETIRED_AT, o: cycleTerm(9) },
    { name: "cycleTotal", poolId: POOL_ID, cycle: "7", caip2: BASE_SEPOLIA, amount: "1234567",
      s: poolCycleSite(POOL_ID, 7, BASE_SEPOLIA), p: P.CYCLE_TOTAL, o: amountTerm("1234567") },
    { name: "releasedTo", draw: B32[3], member: ADDRESSES[4],
      s: idTerm(B32[3]), p: P.RELEASED_TO, o: memberTerm(ADDRESSES[4]) },
    { name: "yieldRouted", sleeve: ADDRESSES[1], cycle: "3",
      s: sleeveTerm(ADDRESSES[1]), p: P.YIELD_ROUTED, o: cycleTerm(3) },
    { name: "fxResidue", site: CHIADO, n: "1", residue: "-1234",
      s: scoped(siteTerm(CHIADO), 1), p: P.FX_RESIDUE, o: signedAmountTerm("-1234") },
  ].map(({ s, p, o, ...inputs }) => ({
    ...inputs, subject: enc(s), predicate: enc(predicateTerm(p)), object: enc(o), cellId: cellId(s, p, o),
  })),
};

// - tidepool-vocab.json -
files["tidepool-vocab.json"] = {
  ...header("tidepool-vocab"),
  predicates: PREDICATES.map(([constant, name]) => ({ constant, name, term: enc(predicateTerm(name)), id: "0x" + predicateId(name) })),
};
{
  const seen = new Set();
  for (const [, name] of PREDICATES) { if (seen.has(name)) throw new Error(`predicate name shared by two classes: ${name}`); seen.add(name); }
}

// - hive-release-payload.json: one Hive release and one repayment (spec 2.6, Appendix D) -
const MEMBER = ADDRESSES[3];
const POOL_ACCOUNT = "tidepool-pool";
const HIVE_MEMBER_ACCOUNT = "alice";
const DRAW_ID = B32[3];
const DESK = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // fixture destination contract (the desk)
const TX_IDS = ["0x" + "a1".repeat(20) + "00".repeat(12), "0x" + "b2".repeat(20) + "00".repeat(12)]; // Hive ids are 160-bit: bytes20 right-padded to bytes32
const BLOCK_IDS = ["0x" + "c3".repeat(20) + "00".repeat(12), "0x" + "d4".repeat(20) + "00".repeat(12)];
const b64 = (term) => Buffer.from(hexToBytes(enc(term))).toString("base64");
function hiveLeg({ predicateName, subject, object, witnessAccount, money, blockNum, blockId, trxId, opIndex, nonce }) {
  const cell = cellId(subject, predicateName, object);
  const json = JSON.stringify({ v: 1, p: POOL_ID.slice(2), c: cell, s: "for", w: witnessAccount, t: [b64(subject), b64(predicateTerm(predicateName)), b64(object)] });
  if (Buffer.byteLength(json) > 8192) throw new Error("custom_json payload over 8192 bytes");
  const op = {
    id: "tidepool",
    required_auths: money ? [witnessAccount] : [],
    required_posting_auths: money ? [] : [witnessAccount],
    json,
  };
  const envelope = envelopeJson({
    dstChainId: 84532, dstContract: DESK, poolId: POOL_ID, srcSite: "0x" + siteId(HIVE_CAIP2), blockNum, blockId, trxId, opIndex,
    payloadNi: "0x" + cell, nonce,
  });
  return {
    predicate: predicateName, side: "for", money,
    subject: enc(subject), predicateTerm: enc(predicateTerm(predicateName)), object: enc(object),
    cellId: cell, ni: niOfHex(cell),
    witness: hiveWitness(witnessAccount), witnessCbor: enc(hiveWitness(witnessAccount)), witnessId: witnessId(hiveWitness(witnessAccount)),
    op, envelope,
  };
}
const release = hiveLeg({
  predicateName: P.RELEASED_TO, subject: idTerm(DRAW_ID), object: memberTerm(MEMBER), witnessAccount: POOL_ACCOUNT, money: true,
  blockNum: 94000001, blockId: BLOCK_IDS[0], trxId: TX_IDS[0], opIndex: 0, nonce: 1,
});
const repayment = hiveLeg({
  predicateName: P.DRAW_SETTLED_BY, subject: idTerm(DRAW_ID), object: memberTerm(MEMBER), witnessAccount: HIVE_MEMBER_ACCOUNT, money: true,
  blockNum: 94000912, blockId: BLOCK_IDS[1], trxId: TX_IDS[1], opIndex: 2, nonce: 2,
});
// both cells told "for" by their Hive witnesses: FOUR value 1 (True); the section digest over the two, ascending
const sectionEntries = [release, repayment].map((l) => ({ cell: l.cellId, value: 1 }));
const sorted = [...sectionEntries].sort((l, r) => (l.cell < r.cell ? -1 : 1));
files["hive-release-payload.json"] = {
  ...header("hive-release-payload"),
  note: "Synthetic fixture: no Hive transaction by these ids exists. payloadNi is the 32-byte cell id the op tells (its ni: name is `ni`).",
  poolId: POOL_ID, poolAccount: POOL_ACCOUNT, memberAddress: MEMBER, memberHiveAccount: HIVE_MEMBER_ACCOUNT, drawId: DRAW_ID,
  amountUsdE6: "250000000", hbdAmountE3: "250000", memos: {
    release: `tidepool:${POOL_ID.slice(2, 10)}:draw:${DRAW_ID.slice(2)}`,
    repayment: `tidepool:${POOL_ID.slice(2, 10)}:settle:${DRAW_ID.slice(2)}`,
  },
  srcSite: HIVE_CAIP2, srcSiteId: "0x" + siteId(HIVE_CAIP2),
  release, repayment,
  section: { cells: sorted.map((e) => e.cell), values: sorted.map((e) => e.value), digest: sectionDigestHex(sectionEntries) },
};

// - relay-envelope.json: signed by anvil's public default key 0 -
const ANVIL_KEY_0 = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // public Foundry/anvil test key, never funded on a live network
const relayer = privateKeyToAccount(ANVIL_KEY_0);
const base = release.envelope;
const mk = async (label, e, expect, signWith = e) => ({
  label, envelope: envelopeJson(e), digest: envelopeDigest(e), signature: await signEnvelope(relayer, signWith), expect,
});
const wrongSigner = privateKeyToAccount("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"); // anvil key 1
files["relay-envelope.json"] = {
  ...header("relay-envelope"),
  note: "EIP-712 digest and signatures over the Envelope of RelayEnvelopeLib. The relayer is anvil's public default account 0.",
  relayer: relayer.address, chainId: 84532, dstContract: DESK,
  typeString: "Envelope(uint256 dstChainId,address dstContract,bytes32 poolId,bytes32 srcSite,uint64 blockNum,bytes32 blockId,bytes32 trxId,uint32 opIndex,bytes32 payloadNi,uint64 nonce)",
  cases: await Promise.all([
    mk("valid release envelope", base, "ok"),
    mk("valid repayment envelope", repayment.envelope, "ok"),
    mk("zero and maximal fields", {
      dstChainId: 84532, dstContract: DESK, poolId: B32[0], srcSite: B32[1], blockNum: 18446744073709551615n, blockId: B32[1], trxId: B32[0],
      opIndex: 4294967295, payloadNi: B32[1], nonce: 18446744073709551615n,
    }, "ok"),
    mk("wrong chain", { ...base, dstChainId: 1 }, "WrongDestination"),
    mk("wrong contract", { ...base, dstContract: ADDRESSES[2] }, "WrongDestination"),
    // signed for nonce 1 but presented with nonce 99: the recovered signer is not the relayer
    mk("tampered nonce", { ...base, nonce: 99 }, "BadRelayerSignature", base),
    mk("tampered payload", { ...base, payloadNi: B32[1] }, "BadRelayerSignature", base),
    (async () => ({ label: "signed by a stranger", envelope: envelopeJson(base), digest: envelopeDigest(base), signature: await signEnvelope(wrongSigner, base), expect: "BadRelayerSignature" }))(),
  ]),
};

// - write or check -
let bad = 0;
mkdirSync(outDir, { recursive: true });
for (const [name, value] of Object.entries(files)) {
  const text = JSON.stringify(value, null, 2) + "\n";
  const path = join(outDir, name);
  if (check) {
    if (!existsSync(path) || readFileSync(path, "utf8") !== text) { console.error(`differs: ${name}`); bad++; }
  } else {
    writeFileSync(path, text);
    console.log(`wrote ${name}`);
  }
}
if (check) { if (bad) process.exit(1); console.log("tidepool vectors: up to date"); }
