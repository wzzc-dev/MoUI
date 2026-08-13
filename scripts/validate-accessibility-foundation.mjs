#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const DEFAULT_PROBE = "checks/accessibility-probe.json";
const DEFAULT_WORK_PACKAGES = "checks/accessibility-work-packages.json";
const SEMANTICS_CONTRACT_PATH = "moui/core/semantics.mbt";
const REQUIRED_WORK_PACKAGES = Array.from(
  { length: 10 },
  (_, index) => `NA-${String(index).padStart(2, "0")}`,
);
const REQUIRED_PROBE_IDS = [
  "a11y.button",
  "a11y.checkbox",
  "a11y.slider",
  "a11y.textfield",
  "a11y.dialog",
  "a11y.tree",
  "a11y.grid",
  "a11y.scroll",
  "a11y.status",
  "a11y.alert",
  "a11y.image",
  "a11y.separator",
];
const REQUIRED_PLATFORM_QUERIES = ["web", "macos", "windows", "linux"];
const REQUIRED_EVIDENCE_FIELDS = [
  "level",
  "commit",
  "host",
  "os",
  "architecture",
  "window",
  "backend",
  "generations",
  "semanticsCommits",
  "nativeTree",
  "actions",
  "keyboardFocus",
  "accessibilityFocus",
  "announcements",
  "environment",
  "result",
  "failures",
  "unverifiedCapabilities",
];
const REQUIRED_SCREEN_READER_FIELDS = [
  "screenReader",
  "navigation",
  "spokenOutput",
];
const REQUIRED_HANDOFF_FIELDS = [
  "task",
  "changed_files",
  "tests",
  "api_diff",
  "evidence",
  "known_gaps",
  "blocked_by",
];
const ALLOWED_SCHEMA_TYPES = new Set([
  "array",
  "boolean",
  "integer",
  "number",
  "object",
  "string",
]);

const isObject = value =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const push = (failures, path, message) => {
  failures.push(`${path}: ${message}`);
};

const validateStringArray = (
  value,
  path,
  failures,
  { nonEmpty = false, unique = true } = {},
) => {
  if (!Array.isArray(value)) {
    push(failures, path, "must be an array of non-empty strings");
    return [];
  }
  if (nonEmpty && value.length === 0) {
    push(failures, path, "must not be empty");
  }
  const seen = new Set();
  for (const [index, item] of value.entries()) {
    if (typeof item !== "string" || item.length === 0) {
      push(failures, `${path}[${index}]`, "must be a non-empty string");
      continue;
    }
    if (unique && seen.has(item)) {
      push(failures, path, `contains duplicate value ${JSON.stringify(item)}`);
    }
    seen.add(item);
  }
  return value.filter(item => typeof item === "string" && item.length > 0);
};

const validateSchemaDescriptor = (schema, path, failures) => {
  if (!isObject(schema)) {
    push(failures, path, "must be a schema object");
    return;
  }
  if (!ALLOWED_SCHEMA_TYPES.has(schema.type)) {
    push(failures, `${path}.type`, "must be a supported JSON value type");
    return;
  }
  if (schema.enum !== undefined) {
    if (!Array.isArray(schema.enum) || schema.enum.length === 0) {
      push(failures, `${path}.enum`, "must be a non-empty array");
    } else if (new Set(schema.enum.map(value => JSON.stringify(value))).size !== schema.enum.length) {
      push(failures, `${path}.enum`, "must not contain duplicate values");
    }
  }
  if (schema.type === "array") {
    if (!isObject(schema.items)) {
      push(failures, `${path}.items`, "is required for array schemas");
    } else {
      validateSchemaDescriptor(schema.items, `${path}.items`, failures);
    }
  }
  if (schema.type !== "object") return;
  if (schema.additionalProperties !== undefined &&
      typeof schema.additionalProperties !== "boolean") {
    push(failures, `${path}.additionalProperties`, "must be boolean");
  }
  if (schema.properties !== undefined && !isObject(schema.properties)) {
    push(failures, `${path}.properties`, "must be an object");
    return;
  }
  const properties = isObject(schema.properties) ? schema.properties : {};
  const required = validateStringArray(
    schema.required ?? [],
    `${path}.required`,
    failures,
  );
  for (const field of required) {
    if (!Object.hasOwn(properties, field)) {
      push(failures, `${path}.properties`, `is missing required field ${field}`);
    }
  }
  for (const [field, childSchema] of Object.entries(properties)) {
    validateSchemaDescriptor(childSchema, `${path}.properties.${field}`, failures);
  }
};

const matchesType = (value, type) => {
  switch (type) {
    case "array": return Array.isArray(value);
    case "boolean": return typeof value === "boolean";
    case "integer": return Number.isInteger(value);
    case "number": return typeof value === "number" && Number.isFinite(value);
    case "object": return isObject(value);
    case "string": return typeof value === "string";
    default: return false;
  }
};

const validateValueAgainstSchema = (value, schema, path, failures) => {
  if (!isObject(schema) || !matchesType(value, schema.type)) {
    push(failures, path, `must be of type ${schema?.type ?? "unknown"}`);
    return;
  }
  if (Array.isArray(schema.enum) && !schema.enum.some(item => Object.is(item, value))) {
    push(failures, path, `must be one of ${schema.enum.join(", ")}`);
  }
  if (schema.type === "array") {
    for (const [index, item] of value.entries()) {
      validateValueAgainstSchema(item, schema.items, `${path}[${index}]`, failures);
    }
  }
  if (schema.type !== "object") return;
  const required = Array.isArray(schema.required) ? schema.required : [];
  for (const field of required) {
    if (!Object.hasOwn(value, field)) {
      push(failures, path, `is missing required field ${field}`);
    }
  }
  const properties = isObject(schema.properties) ? schema.properties : {};
  for (const [field, child] of Object.entries(value)) {
    if (Object.hasOwn(properties, field)) {
      validateValueAgainstSchema(child, properties[field], `${path}.${field}`, failures);
    } else if (schema.additionalProperties === false) {
      push(failures, path, `contains unsupported field ${field}`);
    }
  }
};

const globToRegExp = pattern => {
  let source = "^";
  for (const char of pattern) {
    if (char === "*") source += ".*";
    else if ("\\^$+?.()|{}[]".includes(char)) source += `\\${char}`;
    else source += char;
  }
  return new RegExp(`${source}(?:/.*)?$`);
};

const ownerPathMatches = (pattern, path) => globToRegExp(pattern).test(path);

export const validateProbeCatalog = probe => {
  const failures = [];
  if (!isObject(probe)) return ["probe: must be a JSON object"];
  if (probe.schemaVersion !== 1) push(failures, "probe.schemaVersion", "must be 1");
  if (typeof probe.description !== "string" || probe.description.length === 0) {
    push(failures, "probe.description", "is required");
  }
  if (typeof probe.route !== "string" || probe.route.length === 0) {
    push(failures, "probe.route", "is required");
  }
  if (!Array.isArray(probe.controls) || probe.controls.length === 0) {
    push(failures, "probe.controls", "must be a non-empty array");
  } else {
    const ids = new Set();
    for (const [index, control] of probe.controls.entries()) {
      const path = `probe.controls[${index}]`;
      if (!isObject(control)) {
        push(failures, path, "must be an object");
        continue;
      }
      if (typeof control.id !== "string" || !/^a11y\.[a-z][a-z0-9_-]*$/.test(control.id)) {
        push(failures, `${path}.id`, "must use stable a11y.<name> notation");
      } else if (ids.has(control.id)) {
        push(failures, "probe.controls", `contains duplicate id ${control.id}`);
      } else {
        ids.add(control.id);
      }
      if (typeof control.role !== "string" || control.role.length === 0) {
        push(failures, `${path}.role`, "is required");
      }
      const requiredFields = validateStringArray(
        control.requiredFields,
        `${path}.requiredFields`,
        failures,
      );
      const actions = control.actions === undefined
        ? []
        : validateStringArray(control.actions, `${path}.actions`, failures, { nonEmpty: true });
      for (const action of actions) {
        if (!/^[a-z][a-z0-9_]*$/.test(action)) {
          push(failures, `${path}.actions`, `invalid action name ${action}`);
        }
      }
      if (requiredFields.includes("actions") !== (actions.length > 0)) {
        push(
          failures,
          path,
          "requiredFields must include actions exactly when actions are advertised",
        );
      }
    }
    for (const id of REQUIRED_PROBE_IDS) {
      if (!ids.has(id)) push(failures, "probe.controls", `is missing canonical id ${id}`);
    }
  }
  if (!isObject(probe.platformQueries)) {
    push(failures, "probe.platformQueries", "must be an object");
  } else {
    for (const platform of REQUIRED_PLATFORM_QUERIES) {
      if (typeof probe.platformQueries[platform] !== "string" || probe.platformQueries[platform].length === 0) {
        push(failures, `probe.platformQueries.${platform}`, "is required");
      }
    }
  }
  if (!isObject(probe.evidence)) {
    push(failures, "probe.evidence", "must be an object");
  } else {
    if (typeof probe.evidence.artifactRoot !== "string" || !probe.evidence.artifactRoot.startsWith("artifacts/")) {
      push(failures, "probe.evidence.artifactRoot", "must stay under artifacts/");
    }
    validateSchemaDescriptor(
      probe.evidence.manifestSchema,
      "probe.evidence.manifestSchema",
      failures,
    );
    const required = new Set(probe.evidence.manifestSchema?.required ?? []);
    for (const field of REQUIRED_EVIDENCE_FIELDS) {
      if (!required.has(field)) {
        push(failures, "probe.evidence.manifestSchema.required", `is missing ${field}`);
      }
    }
    const screenReaderRequired = validateStringArray(
      probe.evidence.screenReaderRequired,
      "probe.evidence.screenReaderRequired",
      failures,
      { nonEmpty: true },
    );
    for (const field of REQUIRED_SCREEN_READER_FIELDS) {
      if (!screenReaderRequired.includes(field)) {
        push(failures, "probe.evidence.screenReaderRequired", `is missing ${field}`);
      }
      if (!Object.hasOwn(probe.evidence.manifestSchema?.properties ?? {}, field)) {
        push(failures, "probe.evidence.manifestSchema.properties", `is missing ${field}`);
      }
    }
  }
  return failures;
};

const findDependencyCycles = packages => {
  const dependencies = new Map(packages.map(pkg => [pkg.id, pkg.depends_on ?? []]));
  const visiting = new Set();
  const visited = new Set();
  const stack = [];
  const cycles = [];
  const visit = id => {
    if (visiting.has(id)) {
      const start = stack.indexOf(id);
      cycles.push([...stack.slice(start), id].join(" -> "));
      return;
    }
    if (visited.has(id) || !dependencies.has(id)) return;
    visiting.add(id);
    stack.push(id);
    for (const dependency of dependencies.get(id)) visit(dependency);
    stack.pop();
    visiting.delete(id);
    visited.add(id);
  };
  for (const id of dependencies.keys()) visit(id);
  return [...new Set(cycles)];
};

export const validateWorkPackageCatalog = catalog => {
  const failures = [];
  if (!isObject(catalog)) return ["workPackages: must be a JSON object"];
  if (catalog.schemaVersion !== 1) push(failures, "workPackages.schemaVersion", "must be 1");
  if (typeof catalog.description !== "string" || catalog.description.length === 0) {
    push(failures, "workPackages.description", "is required");
  }
  validateSchemaDescriptor(catalog.handoffSchema, "workPackages.handoffSchema", failures);
  const handoffRequired = new Set(catalog.handoffSchema?.required ?? []);
  for (const field of REQUIRED_HANDOFF_FIELDS) {
    if (!handoffRequired.has(field)) {
      push(failures, "workPackages.handoffSchema.required", `is missing ${field}`);
    }
  }
  if (catalog.handoffSchema?.additionalProperties !== false) {
    push(failures, "workPackages.handoffSchema.additionalProperties", "must be false");
  }
  if (!Array.isArray(catalog.packages) || catalog.packages.length === 0) {
    push(failures, "workPackages.packages", "must be a non-empty array");
    return failures;
  }
  const ids = new Set();
  const validPackages = [];
  for (const [index, pkg] of catalog.packages.entries()) {
    const path = `workPackages.packages[${index}]`;
    if (!isObject(pkg)) {
      push(failures, path, "must be an object");
      continue;
    }
    validPackages.push(pkg);
    if (typeof pkg.id !== "string" || !/^NA-\d{2}$/.test(pkg.id)) {
      push(failures, `${path}.id`, "must use NA-xx notation");
    } else if (ids.has(pkg.id)) {
      push(failures, "workPackages.packages", `contains duplicate id ${pkg.id}`);
    } else {
      ids.add(pkg.id);
    }
    validateStringArray(pkg.owner_paths, `${path}.owner_paths`, failures, { nonEmpty: true });
    validateStringArray(pkg.depends_on, `${path}.depends_on`, failures);
    validateStringArray(pkg.validation, `${path}.validation`, failures, { nonEmpty: true });
    if (!new Set(["L0", "L1", "L2", "L3"]).has(pkg.evidence_level)) {
      push(failures, `${path}.evidence_level`, "must be L0, L1, L2, or L3");
    }
    if (typeof pkg.can_parallel !== "boolean") {
      push(failures, `${path}.can_parallel`, "must be boolean");
    }
  }
  for (const id of REQUIRED_WORK_PACKAGES) {
    if (!ids.has(id)) push(failures, "workPackages.packages", `is missing ${id}`);
  }
  for (const pkg of validPackages) {
    for (const dependency of pkg.depends_on ?? []) {
      if (dependency === pkg.id) {
        push(failures, `workPackages.${pkg.id}.depends_on`, "cannot include itself");
      } else if (!ids.has(dependency)) {
        push(failures, `workPackages.${pkg.id}.depends_on`, `references unknown package ${dependency}`);
      }
    }
  }
  for (const cycle of findDependencyCycles(validPackages)) {
    push(failures, "workPackages.packages", `dependency cycle detected: ${cycle}`);
  }
  const semanticsOwners = validPackages.filter(pkg =>
    (pkg.owner_paths ?? []).some(pattern =>
      typeof pattern === "string" && ownerPathMatches(pattern, SEMANTICS_CONTRACT_PATH),
    ),
  );
  if (!semanticsOwners.some(pkg => pkg.id === "NA-01")) {
    push(failures, "workPackages.NA-01.owner_paths", `must own ${SEMANTICS_CONTRACT_PATH}`);
  }
  for (const pkg of semanticsOwners) {
    if (pkg.id !== "NA-01") {
      push(
        failures,
        `workPackages.${pkg.id}.owner_paths`,
        `must not overlap ${SEMANTICS_CONTRACT_PATH}; it is exclusively owned by NA-01`,
      );
    }
  }
  return failures;
};

export const validateHandoff = (handoff, workPackages) => {
  const failures = [];
  validateValueAgainstSchema(handoff, workPackages.handoffSchema, "handoff", failures);
  if (!isObject(handoff)) return failures;
  const pkg = workPackages.packages.find(item => item.id === handoff.task);
  if (!pkg) {
    push(failures, "handoff.task", "must reference a known work package");
    return failures;
  }
  for (const [index, file] of (handoff.changed_files ?? []).entries()) {
    if (typeof file !== "string") continue;
    if (file.startsWith("/") || file.includes("..")) {
      push(failures, `handoff.changed_files[${index}]`, "must be a repository-relative path");
    } else if (!(pkg.owner_paths ?? []).some(pattern => ownerPathMatches(pattern, file))) {
      push(failures, `handoff.changed_files[${index}]`, `is outside ${handoff.task} owner_paths`);
    }
  }
  return failures;
};

export const validateEvidenceManifest = (
  manifest,
  probe,
  requireScreenReader = false,
  requireNativeClient = false,
) => {
  const failures = [];
  validateValueAgainstSchema(manifest, probe.evidence.manifestSchema, "evidence", failures);
  if (requireScreenReader && isObject(manifest)) {
    for (const field of probe.evidence.screenReaderRequired) {
      if (!Object.hasOwn(manifest, field)) {
        push(failures, "evidence", `is missing screen-reader field ${field}`);
      }
    }
  }
  if (requireNativeClient && isObject(manifest)) {
    if (manifest.level !== "L2") {
      push(failures, "evidence.level", "must be L2 when native-client evidence is required");
    }
    if (manifest.result !== "passed") {
      push(failures, "evidence.result", "must be passed for L2 evidence");
    }
    if (!Array.isArray(manifest.generations) || manifest.generations.length < 2) {
      push(failures, "evidence.generations", "must contain at least two committed generations for L2 evidence");
    }
    if (!Array.isArray(manifest.semanticsCommits) || manifest.semanticsCommits.length < 2) {
      push(failures, "evidence.semanticsCommits", "must contain at least two full/delta commit records for L2 evidence");
    }
    const requiredNativeSources = {
      macos: "ax-api",
      web: "chrome-accessibility-tree",
      windows: "uia-client",
      linux: "at-spi-client",
    };
    const requiredSource = requiredNativeSources[manifest.backend] ?? "";
    if (!isObject(manifest.nativeTree) ||
        (requiredSource ? manifest.nativeTree.source !== requiredSource :
          typeof manifest.nativeTree.source !== "string" || manifest.nativeTree.source.length === 0)) {
      push(
        failures,
        "evidence.nativeTree.source",
        requiredSource ? `must be ${requiredSource} for this L2 manifest` : "must identify the native client for this L2 manifest",
      );
    }
    if (!Array.isArray(manifest.actions) || manifest.actions.length === 0 ||
        manifest.actions.some(action => !isObject(action) || action.result !== "passed")) {
      push(failures, "evidence.actions", "must contain only passed native-client actions for L2 evidence");
    }
    if (Array.isArray(manifest.failures) && manifest.failures.length > 0) {
      push(failures, "evidence.failures", "must be empty for L2 evidence");
    }
  }
  if (requireScreenReader && isObject(manifest) && manifest.level !== "L3") {
    push(failures, "evidence.level", "must be L3 when screen-reader evidence is required");
  }
  return failures;
};

const readJson = path => JSON.parse(readFileSync(resolve(path), "utf8"));

const usage = () => {
  console.error(
    "Usage: node scripts/validate-accessibility-foundation.mjs " +
    "[--probe PATH] [--work-packages PATH] [--handoff PATH] " +
    "[--evidence PATH] [--require-native-client] [--require-screen-reader]",
  );
};

const parseArgs = args => {
  const options = {
    probe: DEFAULT_PROBE,
    workPackages: DEFAULT_WORK_PACKAGES,
    handoff: "",
    evidence: "",
    requireScreenReader: false,
    requireNativeClient: false,
  };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (["--probe", "--work-packages", "--handoff", "--evidence"].includes(arg)) {
      const value = args[index + 1];
      if (!value) throw new Error(`${arg} requires a path`);
      if (arg === "--probe") options.probe = value;
      if (arg === "--work-packages") options.workPackages = value;
      if (arg === "--handoff") options.handoff = value;
      if (arg === "--evidence") options.evidence = value;
      index += 1;
    } else if (arg === "--require-screen-reader") {
      options.requireScreenReader = true;
    } else if (arg === "--require-native-client") {
      options.requireNativeClient = true;
    } else if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (options.requireScreenReader && !options.evidence) {
    throw new Error("--require-screen-reader requires --evidence");
  }
  if (options.requireNativeClient && !options.evidence) {
    throw new Error("--require-native-client requires --evidence");
  }
  return options;
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
  const failures = [];
  let probe;
  let workPackages;
  try {
    probe = readJson(options.probe);
    workPackages = readJson(options.workPackages);
  } catch (error) {
    console.error(`Accessibility foundation validation failed: ${error.message}`);
    process.exit(1);
  }
  failures.push(...validateProbeCatalog(probe));
  failures.push(...validateWorkPackageCatalog(workPackages));
  if (options.handoff) {
    try {
      failures.push(...validateHandoff(readJson(options.handoff), workPackages));
    } catch (error) {
      failures.push(`handoff: ${error.message}`);
    }
  }
  if (options.evidence) {
    try {
      failures.push(
        ...validateEvidenceManifest(
          readJson(options.evidence),
          probe,
          options.requireScreenReader,
          options.requireNativeClient,
        ),
      );
    } catch (error) {
      failures.push(`evidence: ${error.message}`);
    }
  }
  if (failures.length > 0) {
    console.error("Accessibility foundation validation failed:");
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
  }
  console.log(
    `Accessibility foundation validation passed (${probe.controls.length} probes, ` +
    `${workPackages.packages.length} work packages).`,
  );
};

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main();
}
