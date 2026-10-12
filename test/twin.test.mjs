import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PREDICATES, cellId, encodeTerm, hexAddress, memberLabel, memberTerm, poolCycleSite, scoped, predicateId } from "../scripts/lib/tidepool-terms.mjs";

const pkg = join(dirname(fileURLToPath(import.meta.url)), "..");
const vec = (name) => JSON.parse(readFileSync(join(pkg, "test/vectors/js", name), "utf8"));

test("the committed vector files are what the emitter emits", () => {
  const r = spawnSync(process.execPath, [join(pkg, "scripts/emit-tidepool-vectors.mjs"), "--check"], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
});

test("the copied Lean vectors are byte-identical to the conformance package", () => {
  const r = spawnSync(process.execPath, [join(pkg, "scripts/sync-lean-vectors.mjs"), "--check"], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
});

test("A.0b examples", () => {
  assert.equal(memberLabel("0xABCDEF0000000000000000000000000000000001"), "member:0xabcdef0000000000000000000000000000000001");
  assert.equal(scoped(memberLabel("0x" + "11".repeat(20)), 3), `member:0x${"11".repeat(20)}#3`);
  assert.equal(poolCycleSite("0x" + "22".repeat(32), 7, "eip155:84532"), `pool:0x${"22".repeat(32)}@7@eip155:84532`);
  assert.equal(poolCycleSite("0x" + "22".repeat(32), 7), `pool:0x${"22".repeat(32)}@7`);
  assert.throws(() => hexAddress("0x1234"));
});

test("the vocabulary has 35 predicates under one namespace and no shared name", () => {
  assert.equal(PREDICATES.length, 35);
  assert.equal(new Set(PREDICATES.map(([, n]) => n)).size, PREDICATES.length);
  for (const [, n] of PREDICATES) assert.match(n, /^tidepool:[a-zA-Z0-9]+$/);
});

test("vocab and cell rows re-derive from the builders", () => {
  for (const p of vec("tidepool-vocab.json").predicates) assert.equal(p.id, "0x" + predicateId(p.name));
  for (const m of vec("tidepool-terms.json").members) assert.equal(m.encoded, encodeTerm(memberTerm(m.address)));
  for (const c of vec("tidepool-terms.json").cells) assert.match(c.cellId, /^[0-9a-f]{64}$/);
  assert.equal(typeof cellId("a", "tidepool:admittedBy", "b"), "string");
});
