#!/usr/bin/env node
// Copy the Lean-emitted Obsmetrologia conformance vectors this package judges into test/vectors/lean/, byte for
// byte. `--check` copies nothing and exits 1 on any missing, extra or differing file.
//
//   node scripts/sync-lean-vectors.mjs           # copy
//   node scripts/sync-lean-vectors.mjs --check   # verify
//
// Source: lean-system-services-section/lib/obsmetrologia-conformance/vectors (override with LEAN_VECTORS_DIR).
// Groups: four, record, valued (the FOUR carriers signstuff-evm judges), pool (PoolSplitLib, TP-EVM-003). The groups
// tally, barrier, withdrawal, meetpay, sleeve and desk are added by the tasks that realize them (TP-ENG-004's
// vectors-check covers all ten).
import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const pkg = resolve(here, "..");
const GROUPS = ["four", "record", "valued", "pool"];
const SRC = process.env.LEAN_VECTORS_DIR
  ? resolve(process.env.LEAN_VECTORS_DIR)
  : resolve(
      pkg,
      "../../../../../computer-engineering-services-section/services/computer-systems-engineering-services-section/services/" +
        "computer-proofing-system-services-section/services/lean-system-services-section/lib/obsmetrologia-conformance/vectors",
    );
const DEST = join(pkg, "test/vectors/lean");
const check = process.argv.includes("--check");
const jsons = (dir) => (existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith(".json")).sort() : []);
const problems = [];
let n = 0;

for (const group of GROUPS) {
  const from = join(SRC, group);
  const to = join(DEST, group);
  const srcFiles = jsons(from);
  if (srcFiles.length === 0) problems.push(`no source vectors in ${from}`);
  if (!check) mkdirSync(to, { recursive: true });
  for (const f of srcFiles) {
    const bytes = readFileSync(join(from, f));
    const dest = join(to, f);
    if (check) {
      if (!existsSync(dest)) problems.push(`missing ${group}/${f}`);
      else if (!readFileSync(dest).equals(bytes)) problems.push(`differs ${group}/${f}`);
    } else {
      writeFileSync(dest, bytes);
    }
    n++;
  }
  if (check) for (const f of jsons(to)) if (!srcFiles.includes(f)) problems.push(`extra ${group}/${f}`);
}
if (problems.length) { console.error(problems.join("\n")); process.exit(1); }
console.log(`${check ? "verified" : "copied"} ${n} Lean vector files (${GROUPS.join(", ")})`);
