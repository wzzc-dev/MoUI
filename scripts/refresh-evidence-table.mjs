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

import { spawn } from "node:child_process";

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
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
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

function generateTableRow(run, details) {
  const jobs = details.successfulJobs.join(", ");
  const artifacts = details.artifacts.join(", ");
  const boundary = `Proves CI run ${run.id} for head SHA \`${run.head_sha}\`.`;
  return {
    workflow: "MoUI CI",
    run: `[${run.id}](${run.html_url})`,
    key_successful_jobs: jobs,
    uploaded_artifact_names: artifacts,
    evidence_boundary: boundary,
    markdown: `| MoUI CI | [${run.id}](${run.html_url}) | ${jobs} | ${artifacts} | ${boundary} |`,
  };
}

async function main() {
  const args = process.argv.slice(2);
  const { dryRun, useGh, token } = parseArgs(args);
  const owner = DEFAULT_OWNER;
  const repo = DEFAULT_REPO;

  if (dryRun || (!token && !useGh)) {
    console.log(
      JSON.stringify(
        {
          mode: dryRun ? "dry-run" : "no-token",
          message:
            "Provide GITHUB_TOKEN, pass --token, or pass --gh to query the GitHub API. " +
            "Without it, this script returns a template row.",
          template: {
            workflow: "MoUI CI",
            run: "[<run-id>](<run-url>)",
            key_successful_jobs: "<job-name-1>, <job-name-2>",
            uploaded_artifact_names: "<artifact-1>, <artifact-2>",
            evidence_boundary:
              "Manual review required. Replace with current-head evidence.",
          },
        },
        null,
        2,
      ),
    );
    return;
  }

  let run, details;
  if (useGh) {
    const ghRun = await getLatestCiRunViaGh();
    run = {
      id: ghRun.databaseId,
      head_sha: ghRun.headSha,
      created_at: ghRun.createdAt,
      html_url: ghRun.url,
    };
    details = await getRunJobsAndArtifactsViaGh(run.id);
  } else {
    run = await getLatestCiRun(owner, repo, token);
    details = await getRunJobsAndArtifacts(owner, repo, run.id, token);
  }
  const row = generateTableRow(run, details);

  console.log(
    JSON.stringify(
      {
        mode: useGh ? "gh-cli" : "live",
        run_id: run.id,
        head_sha: run.head_sha,
        date: run.created_at,
        ...row,
      },
      null,
      2,
    ),
  );
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
