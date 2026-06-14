#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const platformPlaceholder = "<macos|web|windows|linux>";
const genericPlatformPlaceholder = "<platform>";
const validPlatforms = new Set(["macos", "web", "windows", "linux"]);

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

const resolveRepoPath = path => resolve(repoRoot, path);

const loadCatalog = manifest => {
  const manifestPath = resolveRepoPath(manifest);
  return JSON.parse(readFileSync(manifestPath, "utf8"));
};

const validateCatalog = manifest => {
  const result = spawnSync(
    process.execPath,
    ["scripts/smoke-check.mjs", "--manifest", manifest, "--check"],
    { cwd: repoRoot, encoding: "utf8" },
  );
  if (result.status !== 0) {
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
};

const selectSuites = (catalog, options) => {
  if (options.tier !== null && !catalog.tiers.includes(options.tier)) {
    fail(`unknown tier: ${options.tier}`);
  }
  const requestedSuites = new Set(options.suites);
  const suites = catalog.suites.filter(suite => {
    if (options.tier !== null && suite.tier !== options.tier) return false;
    if (requestedSuites.size > 0 && !requestedSuites.has(suite.id)) return false;
    return true;
  });
  for (const suiteId of requestedSuites) {
    if (!catalog.suites.some(suite => suite.id === suiteId)) {
      fail(`unknown suite: ${suiteId}`);
    }
  }
  if (suites.length === 0) {
    fail("no smoke suites selected");
  }
  return suites;
};

const substituteArg = (arg, options) => {
  if (arg.includes(platformPlaceholder) || arg.includes(genericPlatformPlaceholder)) {
    if (options.platform === null) {
      if (options.mode === "dry-run") return arg;
      fail(`--platform is required for placeholder argument: ${arg}`);
    }
    if (!validPlatforms.has(options.platform)) {
      fail(`unknown platform: ${options.platform}`);
    }
    return arg
      .replaceAll(platformPlaceholder, options.platform)
      .replaceAll(genericPlatformPlaceholder, options.platform);
  }
  return arg;
};

const substituteArgv = (argv, options) => argv.map(arg => substituteArg(arg, options));

const shellQuote = arg => /^[A-Za-z0-9_./:=@+-]+$/.test(arg) ? arg : JSON.stringify(arg);

const commandToString = argv => argv.map(shellQuote).join(" ");

const suitePlan = (suite, options) => ({
  id: suite.id,
  tier: suite.tier,
  kind: suite.kind,
  host: suite.host,
  commands: suite.commands.map(command => ({
    mode: command.mode,
    argv: substituteArgv(command.argv, options),
  })),
  result: suite.result,
  artifacts: (suite.artifacts ?? []).map(artifact => substituteArg(artifact, options)),
});

const printPlan = (suites, options) => {
  const plan = {
    mode: options.mode,
    tier: options.tier,
    suiteCount: suites.length,
    suites: suites.map(suite => suitePlan(suite, options)),
  };
  if (options.json) {
    console.log(JSON.stringify(plan, null, 2));
    return;
  }
  for (const suite of plan.suites) {
    console.log(`${suite.tier}: ${suite.id} [${suite.kind}] host=${suite.host}`);
    for (const command of suite.commands) {
      console.log(`  ${command.mode}: ${commandToString(command.argv)}`);
    }
  }
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
    runCommand(`${suite.id}`, substituteArgv(command.argv, options));
  }
  if (suite.result?.type === "manifest") {
    runCommand(`${suite.id} result validator`, substituteArgv(suite.result.validator, options));
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
  validateCatalog(options.manifest);
  const catalog = loadCatalog(options.manifest);
  const suites = selectSuites(catalog, options);
  if (options.mode === "dry-run") {
    printPlan(suites, options);
    return;
  }
  for (const suite of suites) {
    runSuite(suite, options);
  }
};

main();
