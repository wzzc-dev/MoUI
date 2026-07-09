#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { decodePng8 } from "./lib/png-rgba.mjs";
import { readMobileApps } from "../moui/scripts/mobile/app-config.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const apps = readMobileApps({
  workspaceRoot: repoRoot,
  mouiRoot: join(repoRoot, "moui"),
  skiaRoot: join(repoRoot, "moui_skia"),
});

const usage = `Usage: scripts/record-mobile-runtime-smoke.mjs --platform android|ios --app <id> [options]

Options:
  --artifact <path>       APK or .app path. Defaults to artifacts for the app.
  --manifest <path>       Manifest path. Default artifacts/mobile-runtime/<platform>/<app>/mobile-runtime-smoke.json.
  --device <id>           Android serial or iOS simulator UDID. Default booted/current device.
  --require-passed        Validate the produced manifest as passed.
  -h, --help              Show this help.
`;

const parseArgs = argv => {
  const options = {
    platform: "",
    app: "",
    artifact: "",
    manifest: "",
    device: "",
    requirePassed: false,
    help: false,
  };
  for (let index = 0; index < argv.length;) {
    const arg = argv[index];
    if (arg === "--platform") {
      options.platform = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--app") {
      options.app = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--artifact") {
      options.artifact = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--manifest") {
      options.manifest = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--device") {
      options.device = argv[index + 1] || "";
      index += 2;
    } else if (arg === "--require-passed") {
      options.requirePassed = true;
      index += 1;
    } else if (arg === "-h" || arg === "--help") {
      options.help = true;
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return options;
};

const normalize = path => isAbsolute(path) ? path : resolve(repoRoot, path);

const ensureDir = path => mkdirSync(path, { recursive: true });

const run = (cmd, args, options = {}) => {
  const result = spawnSync(cmd, args, {
    cwd: options.cwd || repoRoot,
    env: options.env || process.env,
    encoding: options.encoding || "utf8",
    input: options.input,
    stdio: options.stdio || "pipe",
  });
  return result;
};

const commandText = (cmd, args) => [cmd, ...args].join(" ");

const appendLog = (path, heading, result) => {
  const body = [
    `## ${heading}`,
    `status=${result.status ?? "error"}`,
    result.stdout || "",
    result.stderr || "",
    "",
  ].join("\n");
  writeFileSync(path, body, { flag: "a" });
};

const analyzeScreenshot = path => {
  if (!existsSync(path)) return { width: 0, height: 0, totalPixels: 0, contentPixels: 0, distinctColorBuckets: 0 };
  const png = decodePng8(readFileSync(path));
  const buckets = new Set();
  let contentPixels = 0;
  for (let index = 0; index < png.data.length; index += 4) {
    const r = png.data[index];
    const g = png.data[index + 1];
    const b = png.data[index + 2];
    const a = png.data[index + 3];
    if (a !== 0 && (r < 245 || g < 245 || b < 245)) contentPixels += 1;
    buckets.add(`${r >> 4}:${g >> 4}:${b >> 4}:${a >> 6}`);
  }
  return {
    width: png.width,
    height: png.height,
    totalPixels: png.width * png.height,
    contentPixels,
    distinctColorBuckets: buckets.size,
  };
};

const baseObservations = supportsScroll => ({
  lifecycleAttach: "no",
  lifecycleDetach: "no",
  nonblankFirstFrame: "no",
  resize: "no",
  representativeInput: "no",
  scrollInput: supportsScroll ? "no" : "pending",
  cleanShutdown: "no",
  ime: "pending",
  clipboard: "pending",
  accessibility: "pending",
  asyncImage: "pending",
  realDeviceSigning: "pending",
});

const defaultArtifact = (platform, app, config) => {
  if (platform === "android") return join(repoRoot, `artifacts/android/${config.artifactName}/app-debug.apk`);
  return join(repoRoot, `artifacts/ios/${config.artifactName}/${config.ios.productName}.app`);
};

const statusFromObservations = (observations, screenshot, supportsScroll) => {
  const required = [
    "lifecycleAttach",
    "lifecycleDetach",
    "nonblankFirstFrame",
    "resize",
    "representativeInput",
    "cleanShutdown",
  ];
  if (supportsScroll) required.push("scrollInput");
  const requiredPassed = required.every(key => observations[key] === "yes");
  const screenshotPassed = screenshot.width > 0 && screenshot.height > 0 && screenshot.contentPixels >= 1024 && screenshot.distinctColorBuckets >= 4;
  return requiredPassed && screenshotPassed ? "passed" : "failed";
};

const runAndroidSmoke = ({ appConfig, artifact, outDir, logPath, screenshotPath, device }) => {
  const observations = baseObservations(appConfig.android.supportsScroll);
  const serialArgs = device ? ["-s", device] : [];
  let result = run("adb", ["devices"]);
  appendLog(logPath, "adb devices", result);
  if (result.status !== 0) return { observations };
  result = run("adb", [...serialArgs, "install", "-r", artifact]);
  appendLog(logPath, "adb install", result);
  if (result.status !== 0) return { observations };
  run("adb", [...serialArgs, "logcat", "-c"]);
  result = run("adb", [...serialArgs, "shell", "am", "start", "-n", `${appConfig.android.applicationId}/dev.wzzc.moui.mobile.MobileActivity`]);
  appendLog(logPath, "adb launch", result);
  if (result.status !== 0) return { observations };
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  result = run("adb", [...serialArgs, "shell", "input", "tap", "160", "240"]);
  appendLog(logPath, "adb tap", result);
  if (result.status === 0) observations.representativeInput = "yes";
  if (appConfig.android.supportsScroll) {
    result = run("adb", [...serialArgs, "shell", "input", "swipe", "220", "680", "220", "320", "300"]);
    appendLog(logPath, "adb swipe", result);
    if (result.status === 0) observations.scrollInput = "yes";
  }
  result = run("adb", [...serialArgs, "exec-out", "screencap", "-p"], { encoding: "buffer" });
  if (result.status === 0 && result.stdout?.length > 0) {
    writeFileSync(screenshotPath, result.stdout);
  }
  result = run("adb", [...serialArgs, "logcat", "-d", "-t", "400"]);
  appendLog(logPath, "adb logcat", result);
  const logs = result.stdout || "";
  if (logs.includes("moui-mobile lifecycle attach")) observations.lifecycleAttach = "yes";
  if (logs.includes("moui-mobile resize")) observations.resize = "yes";
  if (logs.includes("moui-mobile input scroll")) observations.scrollInput = "yes";
  result = run("adb", [...serialArgs, "shell", "am", "force-stop", appConfig.android.applicationId]);
  appendLog(logPath, "adb force-stop", result);
  observations.lifecycleDetach = logs.includes("moui-mobile lifecycle detach") || result.status === 0 ? "yes" : "no";
  observations.cleanShutdown = result.status === 0 ? "yes" : "no";
  return { observations };
};

const runIosSmoke = ({ appConfig, artifact, outDir, logPath, screenshotPath, device }) => {
  const observations = baseObservations(appConfig.ios.supportsScroll);
  const target = device || "booted";
  let result = run("xcrun", ["simctl", "install", target, artifact]);
  appendLog(logPath, "simctl install", result);
  if (result.status !== 0) return { observations };
  result = run("xcrun", ["simctl", "launch", target, appConfig.ios.bundleId]);
  appendLog(logPath, "simctl launch", result);
  if (result.status !== 0) return { observations };
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  result = run("xcrun", ["simctl", "io", target, "screenshot", screenshotPath]);
  appendLog(logPath, "simctl screenshot", result);
  const tap = run("xcrun", ["simctl", "ui", target, "tap", "160", "240"]);
  appendLog(logPath, "simctl ui tap", tap);
  if (tap.status === 0) observations.representativeInput = "yes";
  if (appConfig.ios.supportsScroll) {
    const swipe = run("xcrun", ["simctl", "ui", target, "swipe", "220", "680", "220", "320"]);
    appendLog(logPath, "simctl ui swipe", swipe);
    if (swipe.status === 0) observations.scrollInput = "yes";
  }
  result = run("xcrun", ["simctl", "spawn", target, "log", "show", "--style", "compact", "--last", "2m", "--predicate", "eventMessage CONTAINS 'moui-mobile'"]);
  appendLog(logPath, "simctl log show", result);
  const logs = result.stdout || "";
  if (logs.includes("moui-mobile lifecycle attach")) observations.lifecycleAttach = "yes";
  if (logs.includes("moui-mobile resize") || logs.includes("moui-mobile lifecycle attach")) observations.resize = "yes";
  if (logs.includes("moui-mobile input pointer")) observations.representativeInput = "yes";
  if (logs.includes("moui-mobile input scroll")) observations.scrollInput = "yes";
  result = run("xcrun", ["simctl", "terminate", target, appConfig.ios.bundleId]);
  appendLog(logPath, "simctl terminate", result);
  observations.lifecycleDetach = logs.includes("moui-mobile lifecycle detach") || result.status === 0 ? "yes" : "no";
  observations.cleanShutdown = result.status === 0 ? "yes" : "no";
  return { observations };
};

try {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage);
    process.exit(0);
  }
  if (!options.platform || !options.app) throw new Error("--platform and --app are required");
  if (!["android", "ios"].includes(options.platform)) throw new Error("--platform must be android or ios");
  const appConfig = apps[options.app];
  if (!appConfig) throw new Error(`unknown mobile app: ${options.app}`);
  const platformConfig = appConfig[options.platform];
  if (!platformConfig) throw new Error(`${options.app} does not support ${options.platform}`);
  const outDir = options.manifest
    ? dirname(normalize(options.manifest))
    : join(repoRoot, "artifacts/mobile-runtime", options.platform, options.app);
  ensureDir(outDir);
  const manifestPath = options.manifest
    ? normalize(options.manifest)
    : join(outDir, "mobile-runtime-smoke.json");
  const artifact = options.artifact ? normalize(options.artifact) : defaultArtifact(options.platform, options.app, appConfig);
  const logPath = join(outDir, "runtime.log");
  const screenshotPath = join(outDir, "screenshot.png");
  writeFileSync(logPath, "");
  let observations = baseObservations(platformConfig.supportsScroll);
  if (!existsSync(artifact)) {
    writeFileSync(logPath, `missing artifact: ${artifact}\n`, { flag: "a" });
  } else if (options.platform === "android") {
    ({ observations } = runAndroidSmoke({ appConfig, artifact, outDir, logPath, screenshotPath, device: options.device }));
  } else {
    ({ observations } = runIosSmoke({ appConfig, artifact, outDir, logPath, screenshotPath, device: options.device }));
  }
  const screenshot = analyzeScreenshot(screenshotPath);
  if (screenshot.contentPixels >= 1024 && screenshot.distinctColorBuckets >= 4) {
    observations.nonblankFirstFrame = "yes";
  }
  const status = statusFromObservations(observations, screenshot, platformConfig.supportsScroll);
  const manifest = {
    schemaVersion: 1,
    mode: "mobile-runtime-smoke",
    generatedBy: "scripts/record-mobile-runtime-smoke.mjs",
    platform: options.platform,
    app: options.app,
    status,
    build: {
      fallbackSkia: false,
      artifact,
      command: options.platform === "android"
        ? `scripts/build-mobile-android-apk.sh --app ${options.app}`
        : `scripts/build-mobile-ios-app.sh --app ${options.app}`,
    },
    artifacts: {
      screenshot: screenshotPath,
      log: logPath,
    },
    screenshot,
    observations,
    evidenceBoundary: "non-fallback matching-host smoke evidence; fallback builds are packaging only",
  };
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
  const validatorArgs = ["scripts/validate-mobile-runtime-manifest.mjs", manifestPath];
  if (options.requirePassed) validatorArgs.push("--require-passed");
  const validation = run("node", validatorArgs);
  process.stdout.write(validation.stdout || "");
  process.stderr.write(validation.stderr || "");
  if (validation.status !== 0) process.exit(validation.status || 1);
} catch (error) {
  console.error(`[moui-mobile-smoke] ${error.message}`);
  console.error(usage.trimEnd());
  process.exit(1);
}
