#!/usr/bin/env node
// scripts/refresh-evidence-table.mjs
//
// Refresh the GitHub Actions Evidence Refresh table in docs/release-readiness.md.
//
// Usage:
//   node scripts/refresh-evidence-table.mjs [--dry-run]
//   GITHUB_TOKEN=ghp_... node scripts/refresh-evidence-table.mjs
//   node scripts/refresh-evidence-table.mjs --gh
//
// Without GITHUB_TOKEN, the script runs in dry-run mode and prints what it
// would query. With a token, it queries the GitHub API for the latest successful
// ci.yml run and generates a markdown table row. With --gh, it uses the gh CLI
// instead of the REST API.
//
// Output:
//   JSON object with run_id, head_sha, date, successful_jobs, artifacts, and
//   the markdown table row.
//
// Formal report assembly lives in tools/moui/refresh_evidence_table. This shell
// only handles GitHub HTTP / gh CLI fetch orchestration.

import { spawn, spawnSync } from "node:child_process";
import { writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const DEFAULT_OWNER = "wzzc-dev";
const DEFAULT_REPO = "MoUI";

function parseArgs(args) {
  const dryRun = args.includes("--dry-run");
  const useGh = args.includes("--gh");
  const tokenIndex = args.indexOf("--token");
  const token = tokenIndex >= 0 ? args[tokenIndex + 1] : process.env.GITHUB_TOKEN;
  return { dryRun, useGh, token };
}

async function githubApi(url, token) {
  const headers = { Accept: "application/vnd.github+json" };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  const res = await fetch(url, { headers });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GitHub API ${url} failed: ${res.status} ${text}`);
  }
  return res.json();
}

async function ghCli(args) {
  const { stdout } = await new Promise((resolve, reject) => {
    const child = spawn("gh", args, {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("close", (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`gh ${args.join(" ")} failed: ${stderr || code}`));
    });
  });
  return JSON.parse(stdout);
}

async function getLatestCiRunViaGh() {
  const result = await ghCli([
    "run",
    "list",
    "--repo",
    "wzzc-dev/MoUI",
    "--workflow=ci.yml",
    "--status=success",
    "--limit=1",
    "--json",
    "databaseId,headSha,createdAt,url",
  ]);
  const run = Array.isArray(result) ? result[0] : result;
  if (!run || !run.databaseId) {
    throw new Error("No successful ci.yml runs found via gh CLI");
  }
  return run;
}

async function getRunJobsAndArtifactsViaGh(runId) {
  const [jobs, artifacts] = await Promise.all([
    ghCli([
      "api",
      `repos/wzzc-dev/MoUI/actions/runs/${runId}/jobs?per_page=100`,
    ]),
    ghCli([
      "api",
      `repos/wzzc-dev/MoUI/actions/runs/${runId}/artifacts?per_page=100`,
    ]),
  ]);
  const successfulJobs = (jobs.jobs || [])
    .filter((j) => j.conclusion === "success")
    .map((j) => j.name);
  const artifactsList = (artifacts.artifacts || []).map((a) => a.name);
  return { successfulJobs, artifacts: artifactsList };
}

async function getLatestCiRun(owner, repo, token) {
  const url =
    `https://api.github.com/repos/${owner}/${repo}/actions/workflows/ci.yml/runs` +
    `?per_page=10&status=completed&conclusion=success`;
  const data = await githubApi(url, token);
  if (!data.workflow_runs || data.workflow_runs.length === 0) {
    throw new Error("No successful ci.yml runs found");
  }
  return data.workflow_runs[0];
}

async function getRunJobsAndArtifacts(owner, repo, runId, token) {
  const [jobsData, artifactsData] = await Promise.all([
    githubApi(
      `https://api.github.com/repos/${owner}/${repo}/actions/runs/${runId}/jobs?per_page=100`,
      token,
    ),
    githubApi(
      `https://api.github.com/repos/${owner}/${repo}/actions/runs/${runId}/artifacts?per_page=100`,
      token,
    ),
  ]);
  const successfulJobs = (jobsData.jobs || [])
    .filter((j) => j.conclusion === "success")
    .map((j) => j.name);
  const artifacts = (artifactsData.artifacts || []).map((a) => a.name);
  return { successfulJobs, artifacts };
}

function runAssembler(toolArgs) {
  // runMoonbitTool exits on failure; use spawnSync for status capture if needed.
  const result = spawnSync(
    "moon",
    ["run", "tools/moui/refresh_evidence_table", "--target", "native", "--", ...toolArgs],
    {
      cwd: process.cwd(),
      env: {
        ...process.env,
        MOUI_SKIA_DISABLE_PREBUILD_SKIA:
          process.env.MOUI_SKIA_DISABLE_PREBUILD_SKIA || "1",
      },
      encoding: "utf8",
    },
  );
  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status !== 0) process.exit(result.status ?? 1);
}

async function main() {
  const args = process.argv.slice(2);
  const { dryRun, useGh, token } = parseArgs(args);
  const owner = DEFAULT_OWNER;
  const repo = DEFAULT_REPO;

  if (dryRun || (!token && !useGh)) {
    runAssembler([dryRun ? "--dry-run" : "--no-token"]);
    return;
  }

  let run;
  let details;
  let mode = "live";
  if (useGh) {
    mode = "gh-cli";
    const ghRun = await getLatestCiRunViaGh();
    run = {
      id: String(ghRun.databaseId),
      head_sha: ghRun.headSha,
      created_at: ghRun.createdAt,
      html_url: ghRun.url,
    };
    details = await getRunJobsAndArtifactsViaGh(run.id);
  } else {
    const apiRun = await getLatestCiRun(owner, repo, token);
    run = {
      id: String(apiRun.id),
      head_sha: apiRun.head_sha,
      created_at: apiRun.created_at,
      html_url: apiRun.html_url,
    };
    details = await getRunJobsAndArtifacts(owner, repo, apiRun.id, token);
  }

  const payload = {
    mode,
    run_id: run.id,
    head_sha: run.head_sha,
    date: run.created_at,
    html_url: run.html_url,
    successful_jobs: details.successfulJobs,
    artifacts: details.artifacts,
  };
  const tempRoot = mkdtempSync(join(tmpdir(), "moui-evidence-"));
  const payloadPath = join(tempRoot, "payload.json");
  try {
    writeFileSync(payloadPath, JSON.stringify(payload));
    runAssembler(["--mode", mode, "--payload-file", payloadPath]);
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
