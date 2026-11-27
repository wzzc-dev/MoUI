#!/usr/bin/env node

// Plain Node diagnosis for the generated native dev hot-reload tree.
//
// Runs without MoonBit: it inspects `moui_devhost/dev_hot/` and reports
// whether Moon would resolve its packages into the parent `moui_devhost`
// module. `scripts/check.mjs` and `scripts/moui-dev.mjs` call the same
// detector in-process before invoking Moon; this CLI is the standalone entry
// point for a developer or a recovery script.

import {
  DEV_HOT_DEFAULT_OUT,
  diagnoseDevHotArtifacts,
  formatDevHotDiagnosis,
} from "./lib/dev-hot-artifacts.mjs";

const usage = () => {
  console.error(
    "Usage: node scripts/moui-dev-hot-check.mjs [--root PATH] [--out PATH] [--json] [--help]",
  );
};

let repoRootArg = ".";
let outArg = DEV_HOT_DEFAULT_OUT;
let json = false;

const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--root") {
    repoRootArg = args[index + 1] ?? "";
    index += 1;
  } else if (arg === "--out") {
    outArg = args[index + 1] ?? "";
    index += 1;
  } else if (arg === "--json") {
    json = true;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

if (repoRootArg === "" || outArg === "") {
  usage();
  process.exit(2);
}

const diagnosis = diagnoseDevHotArtifacts({ repoRoot: repoRootArg, out: outArg });
if (json) {
  console.log(JSON.stringify(diagnosis, null, 2));
} else {
  console.log(formatDevHotDiagnosis(diagnosis));
}
process.exit(diagnosis.status === "stale" ? 1 : 0);
