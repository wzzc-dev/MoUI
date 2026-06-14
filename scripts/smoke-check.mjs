#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const usage = () => {
  console.log(`Usage: node scripts/smoke-check.mjs [options]

Validates the checked-in MoUI smoke gate catalog and prints tier plans.

Options:
  --manifest PATH   Smoke gate catalog path. Default: smoke/gates.json
  --check           Validate only. This is the default.
  --list            Print a human-readable suite list.
  --json            Print a normalized JSON plan.
  --tier TIER       Filter suites to daily, nightly, or release.
  -h, --help        Show this help.`);
};

const parseArgs = argv => {
  const options = {
    manifest: "smoke/gates.json",
    mode: "check",
    tier: null,
  };
  for (let index = 0; index < argv.length;) {
    const arg = argv[index];
    switch (arg) {
      case "--manifest":
        if (index + 1 >= argv.length) throw new Error("missing value for --manifest");
        options.manifest = argv[index + 1];
        index += 2;
        break;
      case "--check":
        options.mode = "check";
        index += 1;
        break;
      case "--list":
        options.mode = "list";
        index += 1;
        break;
      case "--json":
        options.mode = "json";
        index += 1;
        break;
      case "--tier":
        if (index + 1 >= argv.length) throw new Error("missing value for --tier");
        options.tier = argv[index + 1];
        index += 2;
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

const asArray = value => Array.isArray(value) ? value : [];
const isObject = value => value !== null && typeof value === "object" && !Array.isArray(value);
const isNonEmptyString = value => typeof value === "string" && value.length > 0;
const resolveRepoPath = path => resolve(repoRoot, path);
const looksLikeRepoPath = value =>
  value.startsWith("scripts/") ||
  value.startsWith("docs/") ||
  value.startsWith("smoke/") ||
  value.startsWith(".github/") ||
  value.startsWith("artifacts/");

const push = (failures, message) => failures.push(message);

const validateCommand = (suite, command, commandIndex, failures) => {
  const label = `${suite.id}.commands[${commandIndex}]`;
  if (!isObject(command)) {
    push(failures, `${label} must be an object`);
    return;
  }
  if (!["run", "manual"].includes(command.mode)) {
    push(failures, `${label}.mode must be run or manual`);
  }
  const argv = asArray(command.argv);
  if (argv.length === 0 || argv.some(arg => !isNonEmptyString(arg))) {
    push(failures, `${label}.argv must be a non-empty string array`);
    return;
  }
  for (const arg of argv) {
    if (
      looksLikeRepoPath(arg) &&
      !arg.startsWith("artifacts/") &&
      !arg.includes("<") &&
      !arg.includes("*") &&
      !existsSync(resolveRepoPath(arg))
    ) {
      push(failures, `${label}.argv references missing repo path: ${arg}`);
    }
  }
};

const validateResult = (suite, result, failures) => {
  if (!isObject(result)) {
    push(failures, `${suite.id}.result must be an object`);
    return;
  }
  if (!["exit-code", "manifest", "log-marker"].includes(result.type)) {
    push(failures, `${suite.id}.result.type must be exit-code, manifest, or log-marker`);
  }
  if (result.type === "manifest") {
    if (!isNonEmptyString(result.path) || !result.path.startsWith("artifacts/")) {
      push(failures, `${suite.id}.result.path must be an artifacts/ manifest path`);
    }
    const validator = asArray(result.validator);
    if (validator.length < 2 || validator.some(arg => !isNonEmptyString(arg))) {
      push(failures, `${suite.id}.result.validator must be a command array`);
    }
    for (const arg of validator) {
      if (looksLikeRepoPath(arg) && !arg.startsWith("artifacts/") && !existsSync(resolveRepoPath(arg))) {
        push(failures, `${suite.id}.result.validator references missing repo path: ${arg}`);
      }
    }
  }
  if (result.type === "log-marker") {
    const markers = asArray(result.markers);
    if (markers.length === 0 || markers.some(marker => !isNonEmptyString(marker))) {
      push(failures, `${suite.id}.result.markers must be a non-empty string array`);
    }
  }
};

const validateCatalog = catalog => {
  const failures = [];
  if (!isObject(catalog)) return ["catalog must be a JSON object"];
  if (catalog.schemaVersion !== 1) push(failures, "schemaVersion must be 1");
  if (!isNonEmptyString(catalog.description)) push(failures, "description is required");
  const tiers = asArray(catalog.tiers);
  for (const tier of ["daily", "nightly", "release"]) {
    if (!tiers.includes(tier)) push(failures, `tiers must include ${tier}`);
  }
  const suites = asArray(catalog.suites);
  if (suites.length === 0) push(failures, "suites must be non-empty");
  const ids = new Set();
  const tierCounts = new Map();
  let defaultDevCheckCount = 0;
  for (const suite of suites) {
    if (!isObject(suite)) {
      push(failures, "suite entries must be objects");
      continue;
    }
    if (!/^[a-z0-9][a-z0-9.-]+$/.test(suite.id ?? "")) {
      push(failures, "suite.id must use lowercase dot/dash notation");
    } else if (ids.has(suite.id)) {
      push(failures, `duplicate suite id: ${suite.id}`);
    } else {
      ids.add(suite.id);
    }
    if (!tiers.includes(suite.tier)) {
      push(failures, `${suite.id}.tier is not declared in tiers`);
    } else {
      tierCounts.set(suite.tier, (tierCounts.get(suite.tier) ?? 0) + 1);
    }
    for (const field of ["kind", "host", "purpose"]) {
      if (!isNonEmptyString(suite[field])) push(failures, `${suite.id}.${field} is required`);
    }
    if (typeof suite.defaultDevCheck !== "boolean") {
      push(failures, `${suite.id}.defaultDevCheck must be boolean`);
    } else if (suite.defaultDevCheck) {
      defaultDevCheckCount += 1;
      if (suite.tier !== "daily") {
        push(failures, `${suite.id} cannot run in default dev-check outside the daily tier`);
      }
    }
    const commands = asArray(suite.commands);
    if (commands.length === 0) push(failures, `${suite.id}.commands must be non-empty`);
    commands.forEach((command, index) => validateCommand(suite, command, index, failures));
    validateResult(suite, suite.result, failures);
    if (!isObject(suite.ci) || !isNonEmptyString(suite.ci.workflow) || !existsSync(resolveRepoPath(suite.ci.workflow))) {
      push(failures, `${suite.id}.ci.workflow must reference a checked-in workflow`);
    }
    if (!isObject(suite.ci) || !isNonEmptyString(suite.ci.gate)) {
      push(failures, `${suite.id}.ci.gate is required`);
    }
    const docs = asArray(suite.docs);
    if (docs.length === 0) push(failures, `${suite.id}.docs must be non-empty`);
    for (const doc of docs) {
      if (!isNonEmptyString(doc) || !existsSync(resolveRepoPath(doc))) {
        push(failures, `${suite.id}.docs references missing repo path: ${doc}`);
      }
    }
    for (const artifact of asArray(suite.artifacts)) {
      if (!isNonEmptyString(artifact) || !artifact.startsWith("artifacts/")) {
        push(failures, `${suite.id}.artifacts entries must be artifacts/ paths`);
      }
    }
  }
  for (const tier of ["daily", "nightly", "release"]) {
    if ((tierCounts.get(tier) ?? 0) === 0) push(failures, `missing suite for tier: ${tier}`);
  }
  if (defaultDevCheckCount === 0) {
    push(failures, "at least one daily suite must describe the default dev-check");
  }
  return failures;
};

const loadCatalog = manifest => {
  const manifestPath = resolveRepoPath(manifest);
  return JSON.parse(readFileSync(manifestPath, "utf8"));
};

const normalizedPlan = (catalog, tier) => {
  const suites = catalog.suites
    .filter(suite => tier === null || suite.tier === tier)
    .map(suite => ({
      id: suite.id,
      tier: suite.tier,
      kind: suite.kind,
      host: suite.host,
      defaultDevCheck: suite.defaultDevCheck,
      commands: suite.commands.map(command => command.argv.join(" ")),
      result: suite.result,
      ci: suite.ci,
      artifacts: suite.artifacts,
    }));
  return {
    schemaVersion: catalog.schemaVersion,
    tier,
    suiteCount: suites.length,
    suites,
  };
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
  const catalog = loadCatalog(options.manifest);
  const failures = validateCatalog(catalog);
  if (options.tier !== null && !catalog.tiers.includes(options.tier)) {
    failures.push(`unknown tier: ${options.tier}`);
  }
  if (failures.length > 0) {
    console.error("smoke gate catalog failed:");
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
  }
  const plan = normalizedPlan(catalog, options.tier);
  if (options.mode === "json") {
    console.log(JSON.stringify(plan, null, 2));
  } else if (options.mode === "list") {
    for (const suite of plan.suites) {
      console.log(`${suite.tier}: ${suite.id} [${suite.kind}] host=${suite.host}`);
      for (const command of suite.commands) console.log(`  ${command}`);
    }
  } else {
    console.log(`smoke gate catalog: ok (${catalog.suites.length} suites)`);
  }
};

main();
