#!/usr/bin/env node

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, extname, isAbsolute, join, parse, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { readMobileApp } from "../../scripts/mobile/app-config.mjs";

const androidResourceDirectory =
  /^(anim|animator|color|drawable|font|interpolator|layout|menu|mipmap|navigation|raw|transition|values|xml)(-[A-Za-z0-9_+.-]+)?$/;

const orientationValues = new Map([
  ["any", "unspecified"],
  ["portrait", "portrait"],
  ["landscape", "landscape"],
]);

const permissionCapabilities = new Map([
  ["camera", [{ name: "android.permission.CAMERA" }]],
  ["microphone", [{ name: "android.permission.RECORD_AUDIO" }]],
  ["location", [
    { name: "android.permission.ACCESS_COARSE_LOCATION" },
    { name: "android.permission.ACCESS_FINE_LOCATION" },
  ]],
  ["notifications", [{ name: "android.permission.POST_NOTIFICATIONS" }]],
  ["photos", [
    { name: "android.permission.READ_EXTERNAL_STORAGE", maxSdkVersion: 32 },
    { name: "android.permission.READ_MEDIA_IMAGES" },
  ]],
  ["clipboard", []],
]);

const ensureDir = path => mkdirSync(path, { recursive: true });

const portable = path => path.split(sep).join("/");

const isInside = (root, candidate) => {
  const path = relative(root, candidate);
  return path === "" || (path !== ".." && !path.startsWith(`..${sep}`) && !isAbsolute(path));
};

const xml = value => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&apos;");

const writeJson = (path, value) => {
  ensureDir(dirname(path));
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
};

const checkedWorkspacePath = (workspaceRoot, value) => {
  const requested = resolve(workspaceRoot, value);
  if (!existsSync(requested)) {
    throw new Error(`managed Android resource does not exist: ${requested}`);
  }
  const real = realpathSync(requested);
  if (!isInside(workspaceRoot, real)) {
    throw new Error(`managed Android resource escapes the workspace: ${requested}`);
  }
  return { requested, real };
};

const collectWorkspaceFiles = (requested, workspaceRoot) => {
  const files = [];
  const visitedDirectories = new Set();
  const visit = (path, relativePath) => {
    const real = realpathSync(path);
    if (!isInside(workspaceRoot, real)) {
      throw new Error(`managed Android resource escapes the workspace: ${path}`);
    }
    const info = statSync(real);
    if (!info.isDirectory()) {
      files.push({ source: real, relativePath });
      return;
    }
    if (visitedDirectories.has(real)) return;
    visitedDirectories.add(real);
    for (const name of readdirSync(real).sort()) {
      visit(join(real, name), relativePath ? join(relativePath, name) : name);
    }
  };
  visit(requested, "");
  return files;
};

const safeRawResourceName = (value, index) => {
  const extension = extname(value).toLowerCase().replace(/[^a-z0-9.]/g, "");
  const stem = basename(value, extname(value))
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, "_")
    .replace(/^_+|_+$/g, "") || "resource";
  return `moui_app_${String(index).padStart(3, "0")}_${stem}${extension}`;
};

const validateAndroidResourceTarget = (target, source) => {
  const parts = target.split(sep).filter(Boolean);
  if (parts.length < 2 || !androidResourceDirectory.test(parts[0])) {
    throw new Error(
      `managed Android resource directory must contain Android res type directories: ` +
        `${source} -> ${portable(target)}`,
    );
  }
  if (parts.some(part => part === "." || part === "..")) {
    throw new Error(`unsafe managed Android resource target: ${portable(target)}`);
  }
};

const stageAppResources = ({ resources, workspaceRoot, outputRoot }) => {
  const resourceRoot = join(outputRoot, "resources");
  rmSync(resourceRoot, { recursive: true, force: true });
  ensureDir(resourceRoot);
  const resourceDirs = [];
  const records = [];
  let rawOverlayRoot = "";
  const outputReal = realpathSync(outputRoot);

  resources.forEach((resource, index) => {
    const source = checkedWorkspacePath(workspaceRoot, resource);
    const info = statSync(source.real);
    if (!info.isDirectory()) {
      if (!rawOverlayRoot) {
        rawOverlayRoot = join(resourceRoot, "raw-overlay");
        ensureDir(join(rawOverlayRoot, "raw"));
        resourceDirs.push(rawOverlayRoot);
      }
      const destination = join(rawOverlayRoot, "raw", safeRawResourceName(resource, index));
      copyFileSync(source.real, destination);
      records.push({
        source: resource,
        kind: "raw-file",
        destination,
      });
      return;
    }

    const overlayRoot = join(resourceRoot, `overlay-${String(index).padStart(3, "0")}`);
    ensureDir(overlayRoot);
    const sourceDirectoryName = basename(source.requested);
    const typePrefix = androidResourceDirectory.test(sourceDirectoryName)
      ? sourceDirectoryName
      : "";
    if (isInside(source.real, outputReal)) {
      throw new Error(`managed Android resource directory must not contain its build output: ${source.requested}`);
    }
    if (!typePrefix) {
      for (const name of readdirSync(source.real).sort()) {
        if (!androidResourceDirectory.test(name)) {
          throw new Error(
            `managed Android resource directory must contain Android res type directories: ` +
              `${source.requested} -> ${name}`,
          );
        }
      }
    }
    const stagedFiles = [];
    for (const file of collectWorkspaceFiles(source.requested, workspaceRoot)) {
      const targetRelative = typePrefix
        ? join(typePrefix, file.relativePath)
        : file.relativePath;
      validateAndroidResourceTarget(targetRelative, file.source);
      const destination = join(overlayRoot, targetRelative);
      ensureDir(dirname(destination));
      copyFileSync(file.source, destination);
      stagedFiles.push(destination);
    }
    resourceDirs.push(overlayRoot);
    records.push({
      source: resource,
      kind: "resource-overlay",
      directory: overlayRoot,
      files: stagedFiles,
    });
  });

  return { resourceRoot, resourceDirs, records };
};

export const resolveAndroidPermissionCapabilities = capabilities => {
  const permissions = [];
  const seen = new Set();
  for (const capability of capabilities) {
    const mapped = permissionCapabilities.get(capability);
    if (!mapped) {
      throw new Error(
        `managed Android shell does not support mobile.permissions capability ` +
          `${JSON.stringify(capability)}; use a supported capability or eject the Android shell`,
      );
    }
    for (const permission of mapped) {
      const key = `${permission.name}:${permission.maxSdkVersion || ""}`;
      if (seen.has(key)) continue;
      seen.add(key);
      permissions.push({ ...permission });
    }
  }
  return permissions.sort((left, right) =>
    left.name.localeCompare(right.name) ||
      (left.maxSdkVersion || 0) - (right.maxSdkVersion || 0));
};

const renderManifest = ({ app, orientation, permissions }) => {
  const permissionLines = permissions.map(permission => {
    const maximum = permission.maxSdkVersion
      ? ` android:maxSdkVersion="${permission.maxSdkVersion}"`
      : "";
    return `    <uses-permission android:name="${xml(permission.name)}"${maximum} />`;
  });
  const prefix = permissionLines.length > 0 ? [...permissionLines, ""] : [];
  return [
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
    ...prefix,
    "    <application",
    '        android:allowBackup="false"',
    `        android:label="${xml(app.displayName)}"`,
    '        android:theme="@style/AppTheme">',
    "        <provider",
    '            android:name="dev.wzzc.moui.mobile.MoUIClipboardProvider"',
    '            android:authorities="${applicationId}.moui.clipboard"',
    '            android:exported="false"',
    '            android:grantUriPermissions="true" />',
    "        <activity",
    '            android:name="dev.wzzc.moui.mobile.MoUIActivity"',
    '            android:configChanges="density|keyboard|keyboardHidden|orientation|screenSize"',
    '            android:exported="true"',
    '            android:resizeableActivity="true"',
    `            android:screenOrientation="${orientation}">`,
    "            <meta-data",
    '                android:name="dev.wzzc.moui.NATIVE_LIBRARY"',
    `                android:value="${xml(app.android.nativeLibrary)}" />`,
    "            <meta-data",
    '                android:name="dev.wzzc.moui.FULLSCREEN"',
    `                android:value="${app.mobile.systemUi.fullscreen ? "true" : "false"}" />`,
    "            <meta-data",
    '                android:name="dev.wzzc.moui.STATUS_BAR"',
    `                android:value="${xml(app.mobile.systemUi.statusBar)}" />`,
    "            <intent-filter>",
    '                <action android:name="android.intent.action.MAIN" />',
    '                <category android:name="android.intent.category.LAUNCHER" />',
    "            </intent-filter>",
    "        </activity>",
    "    </application>",
    "</manifest>",
    "",
  ].join("\n");
};

export const resolveAndroidManagedShell = ({ app, buildDir, workspaceRoot = app?.paths?.workspaceRoot }) => {
  if (!app || app.schemaVersion !== 2 || app.shellApiVersion !== 1 || app.runtimeAbiVersion !== 1) {
    throw new Error("managed Android shell requires schema v2, shell API v1, and runtime ABI v1");
  }
  if (!app.android) throw new Error(`app ${app.id} does not configure Android`);
  if (!["managed", "ejected"].includes(app.android.shellMode)) {
    throw new Error(`app ${app.id} requests unsupported Android shellMode=${app.android.shellMode}`);
  }
  if (!Number.isInteger(app.android.minSdk) || app.android.minSdk < 23) {
    throw new Error("managed Android shell requires minSdk 23 or newer");
  }
  const expectedLibrary = `moui_${app.id.replace(/[^A-Za-z0-9_]/g, "_")}_android`;
  if (app.android.nativeLibrary !== expectedLibrary) {
    throw new Error(`managed Android shell requires fixed native library ${expectedLibrary}`);
  }
  const orientation = orientationValues.get(app.mobile.orientation);
  if (!orientation) throw new Error(`unsupported managed Android orientation: ${app.mobile.orientation}`);
  if (!["auto", "visible", "hidden"].includes(app.mobile.systemUi.statusBar)) {
    throw new Error(`unsupported managed Android status bar mode: ${app.mobile.systemUi.statusBar}`);
  }

  const resolvedBuildDir = resolve(buildDir);
  if (!isAbsolute(buildDir) || resolvedBuildDir === parse(resolvedBuildDir).root) {
    throw new Error("managed Android buildDir must be a safe absolute path");
  }
  const resolvedWorkspace = realpathSync(resolve(workspaceRoot));
  const managed = app.android.shellMode === "managed";
  const outputRoot = join(resolvedBuildDir, "android", `${app.android.shellMode}-shell`);
  rmSync(outputRoot, { recursive: true, force: true });
  ensureDir(outputRoot);

  const permissions = managed
    ? resolveAndroidPermissionCapabilities(app.mobile.permissions || [])
    : [];
  const appResources = managed
    ? stageAppResources({
      resources: app.mobile.resources || [],
      workspaceRoot: resolvedWorkspace,
      outputRoot,
    })
    : { resourceRoot: "", resourceDirs: [], records: [] };
  const manifestPath = managed ? join(outputRoot, "AndroidManifest.xml") : null;
  if (manifestPath) writeFileSync(manifestPath, renderManifest({ app, orientation, permissions }));

  const configPath = join(outputRoot, "shell-config.json");
  const result = {
    schemaVersion: 1,
    platform: "android",
    app: app.id,
    shellMode: app.android.shellMode,
    configurationOwnership: managed ? "framework-managed" : "project-owned",
    shellApiVersion: app.shellApiVersion,
    runtimeAbiVersion: app.runtimeAbiVersion,
    applicationId: app.android.applicationId,
    displayName: app.displayName,
    nativeLibrary: app.android.nativeLibrary,
    minSdk: app.android.minSdk,
    compileSdk: 36,
    targetSdk: 35,
    orientation: app.mobile.orientation,
    screenOrientation: orientation,
    systemUi: {
      fullscreen: app.mobile.systemUi.fullscreen,
      statusBar: app.mobile.systemUi.statusBar,
    },
    permissionCapabilities: [...(app.mobile.permissions || [])],
    androidPermissions: permissions,
    manifestPath,
    resourceDirs: appResources.resourceDirs,
    resources: appResources.records,
  };
  writeJson(configPath, result);
  return { ...result, configPath };
};

const usage = `Usage: moui/mobile/android/resolve-managed-shell.mjs --app <id> --build-dir <dir> [options]

Options:
  --workspace-root <path>  App workspace root. Default current directory.
  --moui-root <path>       Resolved MoUI package root.
  --skia-root <path>       Resolved moui_skia package root.
  --app-config <path>      App-owned schema v2 mobile.json.
  --contracts <path>       Release N compatibility contract registry.
  --app <id>               Mobile app id.
  --build-dir <path>       Android generated build input directory.
`;

const parseArgs = argv => {
  const options = {
    workspaceRoot: process.cwd(),
    mouiRoot: resolve(dirname(fileURLToPath(import.meta.url)), "../.."),
    skiaRoot: "",
    appConfigPath: "",
    contractsPath: "",
    app: "",
    buildDir: "",
  };
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith("--") || !value) throw new Error(`missing value after ${key}`);
    if (key === "--workspace-root") options.workspaceRoot = value;
    else if (key === "--moui-root") options.mouiRoot = value;
    else if (key === "--skia-root") options.skiaRoot = value;
    else if (key === "--app-config") options.appConfigPath = value;
    else if (key === "--contracts") options.contractsPath = value;
    else if (key === "--app") options.app = value;
    else if (key === "--build-dir") options.buildDir = value;
    else throw new Error(`unknown option: ${key}`);
  }
  return options;
};

const main = () => {
  const options = parseArgs(process.argv.slice(2));
  if (!options.app || !options.buildDir) throw new Error("--app and --build-dir are required");
  const workspaceRoot = resolve(options.workspaceRoot);
  const app = readMobileApp(options.app, {
    workspaceRoot,
    mouiRoot: resolve(options.mouiRoot),
    skiaRoot: options.skiaRoot ? resolve(options.skiaRoot) : undefined,
    appConfigPath: options.appConfigPath || undefined,
    contractsPath: options.contractsPath || undefined,
  });
  const result = resolveAndroidManagedShell({
    app,
    buildDir: isAbsolute(options.buildDir) ? options.buildDir : resolve(workspaceRoot, options.buildDir),
    workspaceRoot,
  });
  process.stdout.write(`${JSON.stringify({ configPath: result.configPath, manifestPath: result.manifestPath })}\n`);
};

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(`[moui-mobile-android-config] ${error.message}`);
    console.error(usage.trimEnd());
    process.exit(1);
  }
}
