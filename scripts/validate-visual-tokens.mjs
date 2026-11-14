#!/usr/bin/env node

// Visual token ratchet: raw colors belong in theme/token providers, not in
// control paint paths. The count is frozen per file so new paint code has to
// either use a token or raise the baseline deliberately (same ratchet flow as
// the maintenance baselines).
//
// Usage:
//   node scripts/validate-visual-tokens.mjs
//   node scripts/validate-visual-tokens.mjs --update   # rewrite the baseline
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { repoRoot } from "./lib/window-dependency.mjs";

const baselinePath = resolve(repoRoot, "checks/visual-tokens.json");
const scanRoot = resolve(repoRoot, "moui/views");
const colorPattern =
  /@core\.Color::(?:rgba|rgb|hex|white\(\)|black\(\)|from_hex)/g;

const isExcluded = name =>
  name.endsWith("_test.mbt") ||
  name.endsWith("_wbtest.mbt") ||
  name.endsWith(".generated.mbt") ||
  name.endsWith(".mbti");

const walk = dir => {
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === "_build" || entry.name === ".mooncakes") continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(path));
    } else if (entry.name.endsWith(".mbt") && !isExcluded(entry.name)) {
      files.push(path);
    }
  }
  return files;
};

const countFile = path => {
  const text = readFileSync(path, "utf8");
  const matches = text.match(colorPattern);
  return matches ? matches.length : 0;
};

const scan = () => {
  const files = {};
  let total = 0;
  for (const path of walk(scanRoot)) {
    const count = countFile(path);
    if (count > 0) {
      files[relative(repoRoot, path)] = count;
      total += count;
    }
  }
  return { total, files };
};

const args = process.argv.slice(2);
const update = args.includes("--update");
if (args.includes("--help") || args.includes("-h")) {
  console.log("Usage: node scripts/validate-visual-tokens.mjs [--update]");
  process.exit(0);
}

const current = scan();
if (update) {
  const sorted = {};
  for (const key of Object.keys(current.files).sort()) {
    sorted[key] = current.files[key];
  }
  writeFileSync(
    baselinePath,
    `${JSON.stringify(
      {
        schemaVersion: 1,
        description:
          "Raw @core.Color construction count in moui/views paint sources. Ratchet: only lower or move into a token provider; raising requires an explicit --update and review.",
        total: current.total,
        files: sorted,
      },
      null,
      2,
    )}\n`,
  );
  console.log(
    `visual tokens: baseline updated (${current.total} raw color sites, ${Object.keys(sorted).length} files)`,
  );
  process.exit(0);
}

let baseline;
try {
  baseline = JSON.parse(readFileSync(baselinePath, "utf8"));
} catch (error) {
  console.error(`visual tokens: cannot read ${baselinePath}: ${error.message}`);
  process.exit(2);
}

const problems = [];
for (const [file, count] of Object.entries(current.files)) {
  const allowed = baseline.files?.[file] ?? 0;
  if (count > allowed) {
    problems.push(`${file}: ${count} raw color sites (baseline ${allowed})`);
  }
}
for (const [file, allowed] of Object.entries(baseline.files ?? {})) {
  if (!(file in current.files) && allowed > 0) {
    console.warn(
      `visual tokens: ${file} dropped to 0 (baseline ${allowed}); run --update to lower the ratchet`,
    );
  }
}
if (current.total > (baseline.total ?? 0)) {
  problems.push(
    `total: ${current.total} raw color sites (baseline ${baseline.total})`,
  );
}

if (problems.length > 0) {
  console.error("visual tokens: raw color budget exceeded");
  for (const problem of problems) {
    console.error(`  - ${problem}`);
  }
  console.error(
    "Move the color into the theme/control token provider, or run `node scripts/validate-visual-tokens.mjs --update` with a reviewed reason.",
  );
  process.exit(1);
}

console.log(
  `visual tokens: ${current.total} raw color sites within the ${baseline.total} baseline`,
);
