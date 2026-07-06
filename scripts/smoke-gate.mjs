#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { repoRoot, runMoonbitTool } from "./lib/moonbit-tool-runner.mjs";

const smokeCatalogTool = "tools/moui/validate_smoke_catalog";

const usage = () => {
  console.log(`Usage: node scripts/smoke-gate.mjs [options]

Runs or previews suites from the checked-in MoUI smoke gate catalog.

Options:
  --manifest PATH      Smoke gate catalog path. Default: smoke/gates.json
  --tier TIER          Select suites from daily, nightly, or release.
  --suite ID           Select a suite id. Repeatable.
  --platform PLATFORM  Replace <macos|web|windows|linux> placeholders.
  --dry-run            Print the selected suite plan. This is the default.
  --run                Execute selected non-manual suites.
  --allow-manual       Allow commands marked manual to execute with --run.
  --json               Print the selected suite plan as JSON.
  -h, --help           Show this help.`);
};

const parseArgs = argv => {
  const options = {
    manifest: "smoke/gates.json",
    tier: null,
    suites: [],
    platform: null,
    mode: "dry-run",
    allowManual: false,
    json: false,
  };
  for (let index = 0; index < argv.length;) {
    const arg = argv[index];
    switch (arg) {
      case "--manifest":
        if (index + 1 >= argv.length) throw new Error("missing value for --manifest");
        options.manifest = argv[index + 1];
        index += 2;
        break;
      case "--tier":
        if (index + 1 >= argv.length) throw new Error("missing value for --tier");
        options.tier = argv[index + 1];
        index += 2;
        break;
      case "--suite":
        if (index + 1 >= argv.length) throw new Error("missing value for --suite");
        options.suites.push(argv[index + 1]);
        index += 2;
        break;
      case "--platform":
        if (index + 1 >= argv.length) throw new Error("missing value for --platform");
        options.platform = argv[index + 1];
        index += 2;
        break;
      case "--dry-run":
        options.mode = "dry-run";
        index += 1;
        break;
      case "--run":
        options.mode = "run";
        index += 1;
        break;
      case "--allow-manual":
        options.allowManual = true;
        index += 1;
        break;
      case "--json":
        options.json = true;
        index += 1;
        break;
      case "-h":
      case "--help":
        options.mode = "help";
        index += 1;
        break;
      default:
        throw new Error(`unknown argument: ${arg}`);
    }
  }
  return options;
};

const fail = (message, code = 2) => {
  console.error(message);
  process.exit(code);
};

const shellQuote = arg => /^[A-Za-z0-9_./:=@+-]+$/.test(arg) ? arg : JSON.stringify(arg);

const commandToString = argv => argv.map(shellQuote).join(" ");

const planArgs = (options, forceJson = false) => {
  const args = [
    "--repo-root",
    repoRoot,
    "--manifest",
    options.manifest,
    "--gate-plan",
    options.mode === "run" ? "--run" : "--dry-run",
  ];
  if (forceJson || options.json) args.push("--json");
  if (options.tier !== null) args.push("--tier", options.tier);
  for (const suite of options.suites) args.push("--suite", suite);
  if (options.platform !== null) args.push("--platform", options.platform);
  return args;
};

const runPlanner = (options, { forceJson = false, capture = false } = {}) => {
  const result = runMoonbitTool(smokeCatalogTool, planArgs(options, forceJson), {
    encoding: "utf8",
    exitOnFailure: false,
    suppressSuccessStdout: capture,
  });
  if (result.status !== 0 || result.error) {
    process.exit(result.status ?? 1);
  }
  return result.stdout ?? "";
};

const loadRunPlan = options => {
  const output = runPlanner(options, { forceJson: true, capture: true });
  return JSON.parse(output);
};

const runCommand = (label, argv) => {
  console.log(`\n==> ${label}`);
  console.log(commandToString(argv));
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: repoRoot,
    env: process.env,
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  if (result.signal !== null) {
    fail(`${label} terminated by signal ${result.signal}`, 1);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
};

const runSuite = (suite, options) => {
  for (const command of suite.commands) {
    if (command.mode === "manual" && !options.allowManual) {
      fail(`${suite.id} contains manual commands; pass --allow-manual to run them`);
    }
    runCommand(`${suite.id}`, command.argv);
  }
  if (suite.result?.type === "manifest") {
    runCommand(`${suite.id} result validator`, suite.result.validator);
  }
};

const main = () => {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    usage();
    process.exit(2);
  }
  if (options.mode === "help") {
    usage();
    return;
  }
  if (options.mode === "dry-run") {
    runPlanner(options);
    return;
  }
  const plan = loadRunPlan(options);
  for (const suite of plan.suites) {
    runSuite(suite, options);
  }
};

main();
