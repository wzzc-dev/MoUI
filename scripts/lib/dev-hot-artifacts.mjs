// Stale native dev hot-reload artifact detection.
//
// `moui_devhost/dev_hot/` is generated and Git-ignored. A tree written before
// the standalone-module fix has no `moon.mod`/`moon.work` of its own, so Moon
// attributes its packages to the parent `wzzc-dev/moui_devhost` module and
// rejects the plugin's app import during workspace resolution. That failure is
// opaque and happens before any compile, so it cannot be diagnosed by
// `moui doctor` (which first has to build). This module is plain Node: the
// check facade and `scripts/moui-dev.mjs` both run it before invoking Moon.

import { existsSync, readFileSync, statSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import { hotPlatformForNodePlatform } from "../moui-dev-hot-plan.mjs";

export const DEV_HOT_MODULE_NAME = "wzzc-dev/moui_dev_hot";
export const DEV_HOT_DEFAULT_OUT = "moui_devhost/dev_hot";
export const DEV_HOT_MANIFEST_SCHEMA_VERSION = 1;

// Format 1 was implicit: artifacts carried `schemaVersion: 1` but no marker,
// and the layout was not specified beyond the manifest. Format 2 requires the
// standalone `moon.mod`/`moon.work` module plus this marker. Bump this only
// when the generated layout changes in a way the old output cannot satisfy.
export const DEV_HOT_GENERATOR_FORMAT = 2;

const HOT_PLATFORMS = new Set(["macos", "linux", "windows"]);

// Modules the generated plugin imports by construction. Anything else that
// looks like `<module>/<package>` in the generated import block is the app.
const FRAMEWORK_MODULES = new Set([
  "wzzc-dev/moui",
  "wzzc-dev/moui_devhost",
  "wzzc-dev/moui_devtools",
  "wzzc-dev/moui_skia_renderer",
]);

const GENERATED_FILES = [
  [join("host", "moon.pkg"), "generated host package"],
  [join("host", "main.mbt"), "generated host program"],
  [join("plugin", "moon.pkg"), "generated plugin package"],
  [join("plugin", "main.mbt"), "generated plugin bridge"],
];

const toRepoPath = (repoRoot, path) => {
  const rel = relative(repoRoot, path).split(sep).join("/");
  return rel === "" || rel.startsWith("..") ? path.split(sep).join("/") : rel;
};

const readText = path => {
  try {
    return readFileSync(path, "utf8");
  } catch (_) {
    return null;
  }
};

const isNonEmptyFile = path => {
  try {
    const stat = statSync(path);
    return stat.isFile() && stat.size > 0;
  } catch (_) {
    return false;
  }
};

const readModuleName = path => readText(path)?.match(/^\s*name\s*=\s*"([^"]*)"/m)?.[1] ?? null;

const readWorkspaceMembers = path => {
  const text = readText(path);
  if (text === null) return null;
  const block = text.match(/members\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  return [...block.matchAll(/"([^"]+)"/g)].map(match => match[1]);
};

// Recover the app module when the manifest is missing or predates the
// `appModule` field, so the recovery command still names the real app instead
// of a placeholder.
const deriveAppModuleFromPlugin = pluginPackageText => {
  if (!pluginPackageText) return "";
  const block = pluginPackageText.match(/import\s*\{([\s\S]*?)\}/)?.[1] ?? pluginPackageText;
  for (const match of block.matchAll(/"([^"]+)"/g)) {
    const parts = match[1].split("/");
    if (parts.length < 3) continue;
    const moduleName = `${parts[0]}/${parts[1]}`;
    if (moduleName.startsWith("moonbitlang/") || FRAMEWORK_MODULES.has(moduleName)) continue;
    return moduleName;
  }
  return "";
};

const describeJsonValue = value => (value === undefined ? "missing" : JSON.stringify(value));

const manifestAppModule = manifest => {
  if (!manifest || typeof manifest !== "object") return "";
  if (typeof manifest.appModule === "string" && manifest.appModule !== "") return manifest.appModule;
  if (typeof manifest.app === "string" && manifest.app.split("/").length >= 2) {
    return manifest.app.split("/").slice(0, 2).join("/");
  }
  return "";
};

const manifestAppPackage = manifest => {
  if (!manifest || typeof manifest !== "object") return "app";
  if (typeof manifest.appPackage === "string" && manifest.appPackage !== "") return manifest.appPackage;
  if (typeof manifest.app === "string" && manifest.app.split("/").length >= 3) {
    return manifest.app.split("/")[2];
  }
  return "app";
};

const recoveryPlatform = manifest => {
  const recorded = manifest && typeof manifest === "object" ? manifest.platform : "";
  if (HOT_PLATFORMS.has(recorded)) return recorded;
  return hotPlatformForNodePlatform(process.platform) ?? "<platform>";
};

const buildRecovery = ({ out, manifest, appModule }) => {
  const platform = recoveryPlatform(manifest);
  const generateCommand =
    `node scripts/moui-dev-hot-generate.mjs --root . --app ${appModule || "<app-module>"} ` +
    `--platform ${platform}`;
  return {
    generateCommand,
    removeCommands: [`rm -rf ${out}`, `Remove-Item -Recurse -Force ${out}`],
    isolateCommands: [`mv ${out} ${out}.stale`, `Move-Item ${out} ${out}.stale`],
  };
};

/**
 * Inspect one generated `dev_hot` tree.
 *
 * Returns `{ status, repoRoot, out, outDir, issues, recovery }` where status is
 * `absent` (no artifacts: nothing to do), `ok` (current format and standalone
 * structure) or `stale` (any issue; `issues[].code` is stable for tests).
 */
export const diagnoseDevHotArtifacts = ({
  repoRoot = ".",
  out = DEV_HOT_DEFAULT_OUT,
} = {}) => {
  const root = resolve(repoRoot);
  const outDir = resolve(root, out);
  const outRel = toRepoPath(root, outDir);
  const issues = [];
  const base = { repoRoot: root, outDir, out: outRel };

  if (!existsSync(outDir)) {
    return { ...base, status: "absent", issues, recovery: null };
  }
  if (!statSync(outDir).isDirectory()) {
    issues.push({
      code: "dev-hot.not-directory",
      path: outRel,
      detail: "expected a generated directory, found a file",
    });
    return {
      ...base,
      status: "stale",
      issues,
      recovery: buildRecovery({ out: outRel, manifest: null, appModule: "" }),
    };
  }

  let manifest = null;
  const manifestPath = join(outDir, "manifest.json");
  if (!existsSync(manifestPath)) {
    issues.push({
      code: "dev-hot.manifest.missing",
      path: `${outRel}/manifest.json`,
      detail: "the generation manifest is missing",
    });
  } else {
    const text = readText(manifestPath);
    if (text === null || text.trim() === "") {
      issues.push({
        code: "dev-hot.manifest.empty",
        path: `${outRel}/manifest.json`,
        detail: "the generation manifest is empty or unreadable",
      });
    } else {
      try {
        manifest = JSON.parse(text);
      } catch (_) {
        issues.push({
          code: "dev-hot.manifest.invalid-json",
          path: `${outRel}/manifest.json`,
          detail: "the generation manifest is not valid JSON",
        });
      }
      if (manifest !== null && (typeof manifest !== "object" || Array.isArray(manifest))) {
        issues.push({
          code: "dev-hot.manifest.not-object",
          path: `${outRel}/manifest.json`,
          detail: "the generation manifest must be a JSON object",
        });
        manifest = null;
      }
    }
  }

  if (manifest !== null) {
    if (manifest.schemaVersion !== DEV_HOT_MANIFEST_SCHEMA_VERSION) {
      issues.push({
        code: "dev-hot.manifest.schema-version",
        path: `${outRel}/manifest.json`,
        detail:
          `schemaVersion is ${describeJsonValue(manifest.schemaVersion)}, expected ` +
          `${DEV_HOT_MANIFEST_SCHEMA_VERSION}`,
      });
    }
    if (manifest.generatorFormat === undefined) {
      issues.push({
        code: "dev-hot.manifest.generator-format",
        path: `${outRel}/manifest.json`,
        detail:
          "no generatorFormat marker: written by an older generator (format 1); the " +
          `current generator writes format ${DEV_HOT_GENERATOR_FORMAT}`,
      });
    } else if (manifest.generatorFormat !== DEV_HOT_GENERATOR_FORMAT) {
      issues.push({
        code: "dev-hot.manifest.generator-format",
        path: `${outRel}/manifest.json`,
        detail:
          `generatorFormat is ${describeJsonValue(manifest.generatorFormat)}, expected ` +
          `${DEV_HOT_GENERATOR_FORMAT}`,
      });
    }
    if (manifest.module !== DEV_HOT_MODULE_NAME) {
      issues.push({
        code: "dev-hot.manifest.module",
        path: `${outRel}/manifest.json`,
        detail:
          `module is ${describeJsonValue(manifest.module)}, expected "${DEV_HOT_MODULE_NAME}"`,
      });
    }
  }

  const pluginPackagePath = join(outDir, "plugin", "moon.pkg");
  const pluginPackageText = readText(pluginPackagePath);
  const appModule =
    manifestAppModule(manifest) || deriveAppModuleFromPlugin(pluginPackageText ?? "");
  const appPackage = manifestAppPackage(manifest);

  // The module boundary is the load-bearing part: without its own `moon.mod`
  // the generated packages belong to `wzzc-dev/moui_devhost`, whose manifest
  // stays free of app dependencies by design.
  const modulePath = join(outDir, "moon.mod");
  const moduleRel = `${outRel}/moon.mod`;
  if (!isNonEmptyFile(modulePath)) {
    issues.push({
      code: "dev-hot.moon-mod.missing",
      path: moduleRel,
      detail:
        "no standalone module manifest; Moon attributes dev_hot packages to the parent " +
        "module wzzc-dev/moui_devhost, so the app import fails workspace resolution",
    });
  } else {
    const moduleName = readModuleName(modulePath);
    if (moduleName !== DEV_HOT_MODULE_NAME) {
      issues.push({
        code: "dev-hot.moon-mod.name",
        path: moduleRel,
        detail: `module name is ${describeJsonValue(moduleName)}, expected "${DEV_HOT_MODULE_NAME}"`,
      });
    }
    if (appModule) {
      const moduleText = readText(modulePath) ?? "";
      if (!moduleText.includes(`"${appModule}@`)) {
        issues.push({
          code: "dev-hot.moon-mod.app-dependency",
          path: moduleRel,
          detail:
            `the generated module does not declare the app dependency "${appModule}@<version>"; ` +
            `the plugin cannot import ${appModule}/${appPackage}`,
        });
      }
    }
  }

  const workPath = join(outDir, "moon.work");
  const workRel = `${outRel}/moon.work`;
  const members = readWorkspaceMembers(workPath);
  if (members === null) {
    issues.push({
      code: "dev-hot.moon-work.missing",
      path: workRel,
      detail:
        "no standalone workspace manifest; the generated module is not resolved as its own " +
        "workspace with a mirrored member list",
    });
  } else {
    if (!members.includes(".")) {
      issues.push({
        code: "dev-hot.moon-work.members",
        path: workRel,
        detail: 'the member list does not include "." (the generated module root)',
      });
    }
    if (appModule) {
      const appRoot = resolve(root, appModule);
      const resolved = members.map(member => resolve(outDir, member));
      if (!resolved.includes(appRoot)) {
        issues.push({
          code: "dev-hot.moon-work.app-member",
          path: workRel,
          detail: `the member list does not include the app module directory (${appModule})`,
        });
      }
    }
  }

  for (const [rel, label] of GENERATED_FILES) {
    const abs = join(outDir, rel);
    if (!isNonEmptyFile(abs)) {
      issues.push({
        code: "dev-hot.file.missing",
        path: `${outRel}/${rel.split(sep).join("/")}`,
        detail: `${label} is missing or empty`,
      });
    }
  }

  if (appModule && pluginPackageText !== null) {
    const appImport = `${appModule}/${appPackage}`;
    if (!pluginPackageText.includes(`"${appImport}"`)) {
      issues.push({
        code: "dev-hot.plugin.app-import",
        path: `${outRel}/plugin/moon.pkg`,
        detail: `the generated plugin does not import "${appImport}"`,
      });
    }
  }

  return {
    ...base,
    status: issues.length === 0 ? "ok" : "stale",
    issues,
    recovery:
      issues.length === 0
        ? null
        : buildRecovery({ out: outRel, manifest, appModule }),
  };
};

/** Render a diagnosis as the multi-line text printed by the check facade and
 * `moui dev`. Always includes concrete paths plus a rebuild-and-remove
 * recovery, because the stale tree replaces the whole `dev_hot/` directory. */
export const formatDevHotDiagnosis = diagnosis => {
  const { status, out, repoRoot, issues, recovery } = diagnosis;
  if (status === "absent") {
    return `moui-dev-hot: no generated native hot-reload artifacts at ${out} (nothing to check)`;
  }
  if (status === "ok") {
    return (
      `moui-dev-hot: generated native hot-reload artifacts at ${out} are current ` +
      `(format ${DEV_HOT_GENERATOR_FORMAT}, module ${DEV_HOT_MODULE_NAME})`
    );
  }
  const lines = [
    `moui-dev-hot: stale native hot-reload artifacts at ${out}`,
    ...issues.map(issue => `  - ${issue.path}: ${issue.detail}`),
    "",
    "Moon resolves this tree into wzzc-dev/moui_devhost before compiling anything, so",
    "checks and builds fail during package resolution instead of at the real error.",
    `Recovery (run from the repository root ${repoRoot}):`,
    "  Rebuild the generated tree; the generator replaces the entire dev_hot/ directory:",
    `    ${recovery.generateCommand}`,
    "  End any 'moui dev --hot' session using this tree before regenerating.",
    "  Not using native hot reload? Move the stale directory aside or delete it:",
    `    POSIX:      ${recovery.isolateCommands[0]}   |   ${recovery.removeCommands[0]}`,
    `    PowerShell: ${recovery.isolateCommands[1]}   |   ${recovery.removeCommands[1]}`,
  ];
  return lines.join("\n");
};
