#!/usr/bin/env node

import { readFileSync } from "node:fs";

const usage = () => {
  console.error(
    "Usage: node scripts/verify-feature-proof-coverage.mjs --report <path>",
  );
  process.exit(2);
};

let reportPath = "";

const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--report") reportPath = args[++index] ?? "";
  else if (arg === "--help" || arg === "-h") usage();
  else usage();
}

if (!reportPath) usage();

let report;
try {
  report = JSON.parse(readFileSync(reportPath, "utf8"));
} catch (e) {
  console.error(`Failed to read report: ${e.message}`);
  process.exit(2);
}

const gaps = [];

for (const feature of report.features) {
  if (feature.level === "L1") {
    if (!feature.proven) {
      gaps.push({
        feature: feature.feature,
        level: "L1",
        proofJob: feature.proofJob,
        status: feature.status,
        reason: `L1 job "${feature.proofJob}" did not pass (status: ${feature.status})`,
      });
    }
  } else if (feature.level === "L2") {
    // Skip L2 features when there's no PR context (Skia smoke only runs on PRs)
    if (feature.categoryStatus === "skipped") {
      continue;
    }
    if (!feature.proven) {
      const failedPlatforms = [];
      for (const [job, status] of Object.entries(feature.status)) {
        if (status !== "success") {
          failedPlatforms.push(`${job}=${status}`);
        }
      }
      gaps.push({
        feature: feature.feature,
        level: "L2",
        proofJobs: feature.proofJobs,
        status: feature.status,
        reason: `L2 jobs failed: ${failedPlatforms.join(", ")}`,
      });
    }
  }
}

if (gaps.length > 0) {
  console.error("Feature proof coverage verification FAILED.");
  console.error("");
  console.error("Unproven features:");
  for (const g of gaps) {
    console.error(`  - [${g.level}] ${g.feature}: ${g.reason}`);
  }
  console.error("");
  console.error(`Total gaps: ${gaps.length}`);
  process.exit(1);
}

console.log("Feature proof coverage verification PASSED.");
const skippedMsg = report.summary.skipped > 0 ? `, Skipped: ${report.summary.skipped}` : "";
console.log(`  Proven: ${report.summary.proven}, Gap: ${report.summary.gap}${skippedMsg}`);
