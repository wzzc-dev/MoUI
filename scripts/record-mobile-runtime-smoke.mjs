#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync, openSync, closeSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, spawnSync } from "node:child_process";
import { decodePng8 } from "./lib/png-rgba.mjs";
import {
  hasMobileResizeTransition,
  hasMobileTextClipboardRoundTrip,
  hasIosApplicationLog,
  iosIdbElementPlan,
  iosIdbInputPlan,
  iosIdbServiceProbePlan,
  iosSimulatorLaunchPid,
  mobileTestProbeObservations,
  mobileRuntimeStatus,
  parseMobileRendererStatus,
  parseMobileServiceProbePlan,
  pendingMobileCapabilityObservations,
  pendingGpuPromotionEvidence,
  rendererBlockFromMobileBuild,
} from "./lib/mobile-runtime-log.mjs";
import { readMobileApps } from "../moui/scripts/mobile/app-config.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const apps = readMobileApps({
  workspaceRoot: repoRoot,
  mouiRoot: join(repoRoot, "moui"),
  skiaRoot: join(repoRoot, "moui_skia"),
});

const usage = `Usage: scripts/record-mobile-runtime-smoke.mjs --platform android|ios|harmonyos --app <id> [options]

Options:
  --artifact <path>       APK, .app, or HAP path. Defaults to artifacts for the app.
  --manifest <path>       Manifest path. Default artifacts/mobile-runtime/<platform>/<app>/mobile-runtime-smoke.json.
  --device <id>           adb serial, iOS simulator UDID, or hdc target. Default booted/current device.
  --assistive-tech        Attempt the platform screen-reader focus/activate workflow and restore its prior setting.
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
    assistiveTech: false,
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
    } else if (arg === "--assistive-tech") {
      options.assistiveTech = true;
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

const compareScreenshots = (beforePath, afterPath) => {
  if (!existsSync(beforePath) || !existsSync(afterPath)) {
    return { comparable: false, changedPixels: 0, changedRatio: 0 };
  }
  const before = decodePng8(readFileSync(beforePath));
  const after = decodePng8(readFileSync(afterPath));
  if (before.width !== after.width || before.height !== after.height) {
    return { comparable: false, changedPixels: 0, changedRatio: 0 };
  }
  let changedPixels = 0;
  for (let index = 0; index < before.data.length; index += 4) {
    const delta = Math.abs(before.data[index] - after.data[index])
      + Math.abs(before.data[index + 1] - after.data[index + 1])
      + Math.abs(before.data[index + 2] - after.data[index + 2])
      + Math.abs(before.data[index + 3] - after.data[index + 3]);
    if (delta >= 12) changedPixels += 1;
  }
  const totalPixels = before.width * before.height;
  return {
    comparable: true,
    changedPixels,
    changedRatio: totalPixels === 0 ? 0 : changedPixels / totalPixels,
  };
};

const observeLogs = (observations, logs, supportsScroll, pixelChange) => {
  if (
    logs.includes("moui-mobile lifecycle attach")
    || /moui-mobile attach app=/.test(logs)
  ) {
    observations.lifecycleAttach = "yes";
  }
  if (hasMobileResizeTransition(logs)) observations.resize = "yes";
  const receivedPointer = logs.includes("moui-mobile input pointer");
  const receivedScroll = logs.includes("moui-mobile input scroll");
  const visibleChange = pixelChange.changedPixels >= 16;
  if (receivedPointer && visibleChange) observations.representativeInput = "yes";
  if (supportsScroll && receivedScroll && visibleChange) observations.scrollInput = "yes";
  // IME: require an edit event; accept either state+edit or edit alone after input.
  if (
    logs.includes("moui-mobile service ime edit")
    || (logs.includes("moui-mobile service ime state")
      && /ime state enabled=(true|1)/.test(logs)
      && receivedPointer)
  ) {
    if (logs.includes("moui-mobile service ime edit")) observations.ime = "yes";
  }
  if (hasMobileTextClipboardRoundTrip(logs)) observations.clipboard = "yes";
  if (logs.includes("moui-mobile service accessibility tree")) observations.accessibilityTree = "yes";
  if (logs.includes("moui-mobile service accessibility focus")) observations.accessibilityFocus = "yes";
  if (logs.includes("moui-mobile service accessibility action")) observations.accessibilityAction = "yes";
  if (observations.accessibilityTree === "yes"
      && observations.accessibilityFocus === "yes"
      && observations.accessibilityAction === "yes") {
    observations.accessibility = "yes";
  }
  if (logs.includes("moui-mobile service async-image phase=loading")
      && logs.includes("moui-mobile service async-image phase=ready")) {
    observations.asyncImage = "yes";
  }
  Object.assign(observations, mobileTestProbeObservations(logs));
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
  accessibilityTree: "pending",
  accessibilityFocus: "pending",
  accessibilityAction: "pending",
  asyncImage: "pending",
  ...pendingMobileCapabilityObservations(),
  realDeviceSigning: "pending",
});

const defaultArtifact = (platform, app, config) => {
  if (platform === "android") return join(repoRoot, `artifacts/android/${config.artifactName}/app-debug.apk`);
  if (platform === "ios") return join(repoRoot, `artifacts/ios/${config.artifactName}/${config.ios.productName}.app`);
  return join(repoRoot, `artifacts/harmonyos/${config.artifactName}/${config.harmonyos.productName}.hap`);
};

const androidUiNodeAttributes = encoded => {
  const nodes = [];
  for (const match of encoded.matchAll(/<node\s+([^>]+?)\/?\s*>/g)) {
    const attributes = {};
    for (const attribute of match[1].matchAll(/([\w-]+)="([^"]*)"/g)) {
      attributes[attribute[1]] = attribute[2]
        .replaceAll("&quot;", '"')
        .replaceAll("&amp;", "&");
    }
    const bounds = attributes.bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
    if (bounds) {
      attributes.frame = {
        x: Number(bounds[1]),
        y: Number(bounds[2]),
        width: Number(bounds[3]) - Number(bounds[1]),
        height: Number(bounds[4]) - Number(bounds[2]),
      };
    }
    nodes.push(attributes);
  }
  return nodes;
};

const androidServiceProbePlan = encoded => {
  const nodes = androidUiNodeAttributes(encoded);
  const find = label => nodes.find(node =>
    node.frame
    && (node.text === label || node["content-desc"] === label));
  const textField = find("Service probe text");
  const action = find("Activate service probe");
  if (!textField || !action) return null;
  const center = node => ({
    x: Math.round(node.frame.x + node.frame.width / 2),
    y: Math.round(node.frame.y + node.frame.height / 2),
  });
  return { textField: center(textField), action: center(action) };
};

// HarmonyOS `uitest dump` emits an XML tree of <node> elements. The attribute
// set differs slightly from Android uiautomator (text/key, bounds as [l,t][r,b]),
// so this parser tolerates either shape. Returns nodes with a `frame` when
// bounds are parseable.
const harmonyUiNodeAttributes = encoded => {
  const nodes = [];
  for (const match of encoded.matchAll(/<node\s+([^>]+?)\/?\s*>/g)) {
    const attributes = {};
    for (const attribute of match[1].matchAll(/([\w-]+)="([^"]*)"/g)) {
      attributes[attribute[1]] = attribute[2]
        .replaceAll("&quot;", '"')
        .replaceAll("&amp;", "&");
    }
    const rawBounds = attributes.bounds || attributes.rect || "";
    const bounds = rawBounds.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
    if (bounds) {
      attributes.frame = {
        x: Number(bounds[1]),
        y: Number(bounds[2]),
        width: Number(bounds[3]) - Number(bounds[1]),
        height: Number(bounds[4]) - Number(bounds[2]),
      };
    }
    nodes.push(attributes);
  }
  return nodes;
};

const harmonyServiceProbePlan = encoded => {
  const nodes = harmonyUiNodeAttributes(encoded);
  const find = label => nodes.find(node =>
    node.frame
    && (node.text === label || node["content-desc"] === label || node.key === label));
  const textField = find("Service probe text");
  const action = find("Activate service probe");
  if (!textField || !action) return null;
  const center = node => ({
    x: Math.round(node.frame.x + node.frame.width / 2),
    y: Math.round(node.frame.y + node.frame.height / 2),
  });
  return { textField: center(textField), action: center(action) };
};

// Stream `adb logcat` continuously (filtered to the MoUIMobile tag) so
// high-frequency pointer/scroll lines cannot push attach/IME/clipboard markers
// out of a short `logcat -d` window. Mirrors the iOS log stream contract.
const startAndroidLogStream = ({ device, outPath }) => {
  const serialArgs = device ? ["-s", device] : [];
  const fd = openSync(outPath, "w");
  const child = spawn(
    "adb",
    [...serialArgs, "logcat", "-s", "MoUIMobile:V"],
    {
      cwd: repoRoot,
      stdio: ["ignore", fd, fd],
    },
  );
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  return {
    child,
    stop: () => {
      try {
        if (!child.killed) child.kill("SIGTERM");
      } catch {
        // ignore
      }
      try {
        closeSync(fd);
      } catch {
        // ignore
      }
    },
  };
};

const runAndroidSmoke = ({ appConfig, artifact, logPath, beforePath, screenshotPath, device, assistiveTech }) => {
  const observations = baseObservations(appConfig.android.supportsScroll);
  const serialArgs = device ? ["-s", device] : [];
  let result = run("adb", ["devices"]);
  appendLog(logPath, "adb devices", result);
  if (result.status !== 0) return { observations };
  result = run("adb", [...serialArgs, "install", "-r", artifact]);
  appendLog(logPath, "adb install", result);
  if (result.status !== 0) return { observations };
  run("adb", [...serialArgs, "logcat", "-c"]);
  // Stream `adb logcat` continuously (filtered to MoUIMobile) so high-frequency
  // pointer/scroll lines cannot push attach/IME/clipboard markers out of a
  // short `logcat -d` window. Mirrors the iOS log stream contract.
  const androidStreamPath = join(dirname(logPath), "runtime-stream.log");
  const androidStream = startAndroidLogStream({ device, outPath: androidStreamPath });
  const launchArgs = [
    ...serialArgs, "shell", "am", "start", "-n",
    `${appConfig.android.applicationId}/dev.wzzc.moui.mobile.MoUIActivity`,
  ];
  if (appConfig.id === "component_gallery") {
    launchArgs.push("--es", "moui.mobile.testProbe", "1");
  }
  result = run("adb", launchArgs);
  appendLog(logPath, "adb launch", result);
  if (result.status !== 0) {
    androidStream.stop();
    return { observations };
  }
  // Wait for first frame and the native virtual accessibility tree before input.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 4000);
  result = run("adb", [...serialArgs, "exec-out", "screencap", "-p"], { encoding: "buffer" });
  if (result.status === 0 && result.stdout?.length > 0) writeFileSync(beforePath, result.stdout);
  let probePlan = null;
  let lastTree = { status: 1, stdout: "", stderr: "no dump" };
  if (appConfig.id === "component_gallery") {
    for (let attempt = 1; attempt <= 12; attempt++) {
      const dumped = run("adb", [...serialArgs, "shell", "uiautomator", "dump", "/sdcard/moui-window.xml"]);
      appendLog(logPath, `adb service probe accessibility dump attempt ${attempt}`, dumped);
      lastTree = run("adb", [...serialArgs, "shell", "cat", "/sdcard/moui-window.xml"]);
      probePlan = lastTree.status === 0 ? androidServiceProbePlan(lastTree.stdout || "") : null;
      if (probePlan) break;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
    }
    appendLog(logPath, "adb service probe accessibility tree", lastTree);
    appendLog(logPath, "adb service probe plan", {
      status: probePlan ? 0 : 1,
      stdout: probePlan
        ? JSON.stringify({ textField: probePlan.textField, action: probePlan.action })
        : "",
      stderr: probePlan ? "" : "service probe labels not found in uiautomator dump",
    });
  }
  if (probePlan) {
    result = run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.textField.x), String(probePlan.textField.y)]);
    appendLog(logPath, "adb focus service probe text field", result);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
    // `input text` rejects leading '-' as a flag; quote via shell.
    result = run("adb", [...serialArgs, "shell", "input", "text", "ime-mobile-probe"]);
    appendLog(logPath, "adb service probe IME text", result);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 300);
    result = run("adb", [...serialArgs, "shell", "input", "keycombination", "113", "29"]);
    appendLog(logPath, "adb service probe select all", result);
    result = run("adb", [...serialArgs, "shell", "input", "keyevent", "278"]);
    appendLog(logPath, "adb service probe system Copy", result);
    result = run("adb", [...serialArgs, "shell", "input", "keyevent", "277"]);
    appendLog(logPath, "adb service probe system Cut", result);
    result = run("adb", [...serialArgs, "shell", "input", "keyevent", "279"]);
    appendLog(logPath, "adb service probe system Paste", result);
    result = run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.action.x), String(probePlan.action.y)]);
    appendLog(logPath, "adb activate service probe button", result);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  } else {
    result = run("adb", [...serialArgs, "shell", "input", "tap", "160", "240"]);
    appendLog(logPath, "adb tap", result);
  }

  // Scroll before rotation while the Activity still has a stable portrait layout.
  // Post-rotation swipes can miss the SurfaceView under immersive/fullscreen.
  if (appConfig.android.supportsScroll) {
    const swipeX = probePlan ? probePlan.action.x : 220;
    const swipeY0 = probePlan ? Math.max(probePlan.action.y + 200, 900) : 900;
    const swipeY1 = probePlan ? Math.max(probePlan.action.y - 100, 300) : 320;
    result = run("adb", [...serialArgs, "shell", "input", "swipe",
      String(swipeX), String(swipeY0), String(swipeX), String(swipeY1), "400"]);
    appendLog(logPath, "adb swipe", result);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
  }

  // Always attempt orientation + size transitions for resize evidence.
  // configChanges keeps the Activity alive; shell now posts resize after layout.
  const accelerometer = run("adb", [...serialArgs, "shell", "settings", "get", "system", "accelerometer_rotation"]);
  const rotation = run("adb", [...serialArgs, "shell", "settings", "get", "system", "user_rotation"]);
  appendLog(logPath, "adb read rotation settings", {
    status: accelerometer.status || rotation.status,
    stdout: `accelerometer=${accelerometer.stdout || ""}rotation=${rotation.stdout || ""}`,
    stderr: `${accelerometer.stderr || ""}${rotation.stderr || ""}`,
  });
  result = run("adb", [...serialArgs, "shell", "settings", "put", "system", "accelerometer_rotation", "0"]);
  appendLog(logPath, "adb lock rotation", result);
  result = run("adb", [...serialArgs, "shell", "settings", "put", "system", "user_rotation", "1"]);
  appendLog(logPath, "adb rotate landscape", result);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1200);
  // Fallback size change if rotation did not produce a second dimension pair.
  let midStream = "";
  try {
    if (existsSync(androidStreamPath)) midStream = readFileSync(androidStreamPath, "utf8");
  } catch {
    // ignore
  }
  if (!hasMobileResizeTransition(midStream)) {
    const sizeBefore = run("adb", [...serialArgs, "shell", "wm", "size"]);
    appendLog(logPath, "adb wm size before", sizeBefore);
    result = run("adb", [...serialArgs, "shell", "wm", "size", "800x1280"]);
    appendLog(logPath, "adb wm size 800x1280", result);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
    result = run("adb", [...serialArgs, "shell", "wm", "size", "reset"]);
    appendLog(logPath, "adb wm size reset", result);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  }
  run("adb", [...serialArgs, "shell", "settings", "put", "system", "user_rotation", (rotation.stdout || "0").trim() || "0"]);
  run("adb", [...serialArgs, "shell", "settings", "put", "system", "accelerometer_rotation", (accelerometer.stdout || "1").trim() || "1"]);
  if (assistiveTech && probePlan) {
    const enabledServices = run("adb", [...serialArgs, "shell", "settings", "get", "secure", "enabled_accessibility_services"]);
    appendLog(logPath, "adb enabled accessibility services", enabledServices);
    if (/talkback/i.test(enabledServices.stdout || "")) {
      appendLog(logPath, "TalkBack focus service probe action", run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.action.x), String(probePlan.action.y)]));
      appendLog(logPath, "TalkBack activate service probe action", run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.action.x), String(probePlan.action.y)]));
    }
  }
  // Allow async-image ready + input logs to flush before after-screenshot.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  result = run("adb", [...serialArgs, "exec-out", "screencap", "-p"], { encoding: "buffer" });
  if (result.status === 0 && result.stdout?.length > 0) {
    writeFileSync(screenshotPath, result.stdout);
  }
  const pixelChange = compareScreenshots(beforePath, screenshotPath);
  // Prefer HOME so onStop/surfaceDestroyed can log detach before force-stop.
  result = run("adb", [...serialArgs, "shell", "input", "keyevent", "KEYCODE_HOME"]);
  appendLog(logPath, "adb home for detach", result);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  result = run("adb", [...serialArgs, "shell", "am", "force-stop", appConfig.android.applicationId]);
  appendLog(logPath, "adb force-stop", result);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 800);
  androidStream.stop();
  let androidStreamLogs = "";
  try {
    if (existsSync(androidStreamPath)) androidStreamLogs = readFileSync(androidStreamPath, "utf8");
  } catch {
    // ignore stream read failure; dump remains the fallback
  }
  if (androidStreamLogs) {
    writeFileSync(logPath, `## adb logcat stream\n${androidStreamLogs}\n`, { flag: "a" });
  }
  result = run("adb", [...serialArgs, "logcat", "-d", "-t", "800"]);
  appendLog(logPath, "adb logcat", result);
  const logs = `${androidStreamLogs}\n${result.stdout || ""}`;
  observeLogs(observations, logs, appConfig.android.supportsScroll, pixelChange);
  // Android logs sometimes use "lifecycle detach" without the exact marker prefix.
  observations.lifecycleDetach = (
    logs.includes("moui-mobile lifecycle detach")
    || logs.includes("moui-mobile detach")
  ) ? "yes" : "no";
  observations.cleanShutdown = result.status === 0 ? "yes" : "no";
  return { observations, pixelChange };
};

const iosIdbTree = idbTarget => run("idb", [
  "ui", "describe-all", "--udid", idbTarget,
]);

const pollIosIdbPlan = (idbTarget, planner, attempts = 20) => {
  let tree = { status: 1, stdout: "", stderr: "idb tree was not queried" };
  for (let attempt = 0; attempt < attempts; attempt++) {
    tree = iosIdbTree(idbTarget);
    const plan = tree.status === 0 ? planner(tree.stdout || "") : null;
    if (plan) return { tree, plan };
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
  }
  return { tree, plan: null };
};

const iosIdbTap = (idbTarget, point, duration) => run("idb", [
  "ui", "tap", String(point.x), String(point.y),
  ...(duration ? ["--duration", String(duration)] : []),
  "--udid", idbTarget,
]);

const driveIosEditMenuAction = ({ idbTarget, point, labels, logPath, heading }) => {
  for (let attempt = 1; attempt <= 3; attempt++) {
    if (attempt > 1) {
      const focus = iosIdbTap(idbTarget, point);
      appendLog(logPath, `${heading} refocus attempt ${attempt}`, focus);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
    }
    const longPress = iosIdbTap(idbTarget, point, 1.0);
    appendLog(logPath, `${heading} long press attempt ${attempt}`, longPress);
    if (longPress.status !== 0) continue;
    const found = pollIosIdbPlan(
      idbTarget,
      encoded => iosIdbElementPlan(encoded, labels),
      12,
    );
    appendLog(logPath, `${heading} edit menu tree attempt ${attempt}`, found.tree);
    if (!found.plan) continue;
    const activated = iosIdbTap(idbTarget, found.plan.tap);
    appendLog(logPath, `${heading} ${JSON.stringify(found.plan.label)}`, activated);
    return activated.status === 0 ? found.plan : null;
  }
  return null;
};

const rotateIosSimulator = (direction, logPath) => {
  const menuItem = direction === "left" ? "Rotate Left" : "Rotate Right";
  // Simulator menu automation needs macOS Accessibility for System Events.
  // Use an explicit timeout so a missing permission fails cleanly instead of
  // hanging the whole smoke for minutes.
  const script = [
    'with timeout of 20 seconds',
    '  tell application "Simulator" to activate',
    '  delay 0.4',
    '  tell application "System Events"',
    '    tell process "Simulator"',
    '      set frontmost to true',
    `      click menu item "${menuItem}" of menu "Device" of menu bar 1`,
    '    end tell',
    '  end tell',
    'end timeout',
  ].join("\n");
  const result = run("osascript", ["-e", script]);
  appendLog(logPath, `Simulator ${menuItem}`, result);
  return result;
};

const startIosLogStream = ({ target, productName, outPath }) => {
  // Stream continuously so high-frequency pointer/scroll lines cannot push
  // attach/IME/clipboard markers out of a short `log show --last` window.
  const fd = openSync(outPath, "w");
  const child = spawn(
    "xcrun",
    [
      "simctl", "spawn", target, "log", "stream",
      "--level", "debug",
      "--style", "compact",
      "--predicate",
      `process == '${productName}' AND eventMessage CONTAINS 'moui-mobile'`,
    ],
    {
      cwd: repoRoot,
      stdio: ["ignore", fd, fd],
    },
  );
  // Give logd a moment to attach before app launch.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  return {
    child,
    stop: () => {
      try {
        if (!child.killed) child.kill("SIGTERM");
      } catch {
        // ignore
      }
      try {
        closeSync(fd);
      } catch {
        // ignore
      }
    },
  };
};

const runIosSmoke = ({ appConfig, artifact, logPath, beforePath, screenshotPath, device, assistiveTech }) => {
  const observations = baseObservations(appConfig.ios.supportsScroll);
  const target = device || "booted";
  const idbTargetResult = device
    ? { status: 0, stdout: device, stderr: "" }
    : run("xcrun", ["simctl", "getenv", "booted", "SIMULATOR_UDID"]);
  appendLog(logPath, "resolve iOS simulator UDID", idbTargetResult);
  const idbTarget = (idbTargetResult.stdout || "").trim();
  let result = run("xcrun", ["simctl", "install", target, artifact]);
  appendLog(logPath, "simctl install", result);
  if (result.status !== 0) return { observations };
  const streamPath = join(dirname(logPath), "runtime-stream.log");
  const logStream = startIosLogStream({
    target,
    productName: appConfig.ios.productName,
    outPath: streamPath,
  });
  appendLog(logPath, "ios log stream start", {
    status: 0,
    stdout: streamPath,
    stderr: "",
  });
  const launchEnv = {
    ...process.env,
  };
  // simctl removes SIMCTL_CHILD_ while forwarding the value into the app.
  if (appConfig.id === "component_gallery") {
    launchEnv.SIMCTL_CHILD_MOUI_MOBILE_TEST_PROBE = "1";
    launchEnv.MOUI_MOBILE_TEST_PROBE = "1";
  }
  result = run("xcrun", ["simctl", "launch", target, appConfig.ios.bundleId], {
    env: launchEnv,
  });
  appendLog(logPath, "simctl launch", result);
  if (result.status !== 0) {
    logStream.stop();
    return { observations };
  }
  const launchPid = iosSimulatorLaunchPid(result.stdout || "");
  // Allow first-frame attach + accessibility tree publish before idb queries.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 3000);
  let idbReady = false;
  let inputPlan = null;
  let serviceProbePlan = null;
  if (idbTarget) {
    const connect = run("idb", ["connect", idbTarget]);
    appendLog(logPath, "idb connect", connect);
    idbReady = connect.status === 0;
    let tree = { status: 1, stdout: "", stderr: "idb companion connection failed" };
    if (idbReady) {
      // Prefer service-probe labels for component_gallery; keep polling until
      // the probe is visible so we do not fall back to a random catalog button.
      if (appConfig.id === "component_gallery") {
        const foundProbe = pollIosIdbPlan(
          idbTarget,
          encoded => iosIdbServiceProbePlan(encoded),
          40,
        );
        tree = foundProbe.tree;
        serviceProbePlan = foundProbe.plan;
        inputPlan = serviceProbePlan;
        appendLog(logPath, "idb service probe plan", {
          status: serviceProbePlan ? 0 : 1,
          stdout: serviceProbePlan
            ? JSON.stringify({
              textField: serviceProbePlan.textField.label,
              action: serviceProbePlan.action.label,
            })
            : "",
          stderr: serviceProbePlan ? "" : "service probe labels not found",
        });
      }
      if (!inputPlan) {
        const found = pollIosIdbPlan(idbTarget, encoded => iosIdbInputPlan(encoded), 20);
        tree = found.tree;
        inputPlan = found.plan;
      }
    }
    appendLog(logPath, "idb accessibility tree", tree);
    if (!inputPlan) {
      appendLog(logPath, "idb input plan", {
        status: 1,
        stdout: "",
        stderr: "no enabled accessibility button with a non-empty frame",
      });
    }
  } else {
    appendLog(logPath, "idb input plan", {
      status: 1,
      stdout: "",
      stderr: "unable to resolve booted simulator UDID",
    });
  }
  result = run("xcrun", ["simctl", "io", target, "screenshot", beforePath]);
  appendLog(logPath, "simctl screenshot", result);
  const useVoiceOverAssist = assistiveTech;
  let previousVoiceOver = null;
  if (useVoiceOverAssist && idbReady) {
    previousVoiceOver = run("idb", [
      "get", "--domain", "com.apple.Accessibility",
      "VoiceOverTouchEnabled", "--udid", idbTarget,
    ]);
    appendLog(logPath, "read simulator VoiceOver setting", previousVoiceOver);
    const enabled = run("idb", [
      "set", "--domain", "com.apple.Accessibility", "--type", "bool",
      "VoiceOverTouchEnabled", "true", "--udid", idbTarget,
    ]);
    appendLog(logPath, "enable simulator VoiceOver early", enabled);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  }

  if (serviceProbePlan) {
    let action = iosIdbTap(idbTarget, serviceProbePlan.textField.tap);
    appendLog(logPath, "idb focus service probe text field", action);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 600);
    action = run("idb", [
      "ui", "text", "ime-mobile-probe", "--udid", idbTarget,
    ]);
    appendLog(logPath, "idb service probe IME text", action);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);

    const selected = driveIosEditMenuAction({
      idbTarget,
      point: serviceProbePlan.textField.tap,
      labels: ["Select All", "Select", "全选", "选择"],
      logPath,
      heading: "service probe select all",
    });
    if (selected) {
      const copied = pollIosIdbPlan(
        idbTarget,
        encoded => iosIdbElementPlan(encoded, ["Copy", "拷贝", "复制"]),
        10,
      );
      appendLog(logPath, "service probe copy menu tree", copied.tree);
      if (copied.plan) {
        action = iosIdbTap(idbTarget, copied.plan.tap);
        appendLog(logPath, "service probe system Copy", action);
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
      }
    }
    action = run("xcrun", ["simctl", "pbpaste", target]);
    appendLog(logPath, "simctl clipboard after MoUI Copy", action);
    action = run("xcrun", ["simctl", "pbcopy", target], {
      input: "clipboard-service-probe-中文-👩‍💻",
    });
    appendLog(logPath, "simctl seed system clipboard", action);
    // Place caret (clear selection) so the edit menu offers Paste, then paste.
    action = iosIdbTap(idbTarget, serviceProbePlan.textField.tap);
    appendLog(logPath, "idb caret service probe text field before paste", action);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
    const pasted = driveIosEditMenuAction({
      idbTarget,
      point: serviceProbePlan.textField.tap,
      labels: ["Paste", "粘贴"],
      logPath,
      heading: "service probe system Paste",
    });
    if (!pasted) {
      // Fallback: try paste via standard key chord after re-focus.
      action = iosIdbTap(idbTarget, serviceProbePlan.textField.tap);
      appendLog(logPath, "idb refocus before paste key fallback", action);
      // HID key 9 is V; many Simulator builds accept command-modified key events.
      const pasteKey = run("idb", [
        "ui", "key", "9", "--udid", idbTarget,
      ]);
      appendLog(logPath, "idb paste key fallback (v)", pasteKey);
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 800);

    action = iosIdbTap(idbTarget, serviceProbePlan.action.tap);
    appendLog(logPath, "idb activate service probe button", action);
    const keyboardDismiss = run("idb", [
      "ui", "key", "41", "--udid", idbTarget,
    ]);
    appendLog(logPath, "idb dismiss keyboard", keyboardDismiss);

    const rotated = rotateIosSimulator("left", logPath);
    if (rotated.status === 0) {
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1200);
      rotateIosSimulator("right", logPath);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1200);
    }

    if (appConfig.ios.supportsScroll && serviceProbePlan.swipe) {
      const swipe = run("idb", [
        "ui", "swipe",
        String(serviceProbePlan.swipe.xStart), String(serviceProbePlan.swipe.yStart),
        String(serviceProbePlan.swipe.xEnd), String(serviceProbePlan.swipe.yEnd),
        "--duration", "0.3", "--udid", idbTarget,
      ]);
      appendLog(logPath, "idb service probe swipe", swipe);
    }

    if (useVoiceOverAssist) {
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 800);
      appendLog(logPath, "VoiceOver focus service probe action", iosIdbTap(
        idbTarget, serviceProbePlan.action.tap,
      ));
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 700);
      appendLog(logPath, "VoiceOver activate service probe action first tap", iosIdbTap(
        idbTarget, serviceProbePlan.action.tap, 0.05,
      ));
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 200);
      appendLog(logPath, "VoiceOver activate service probe action second tap", iosIdbTap(
        idbTarget, serviceProbePlan.action.tap, 0.05,
      ));
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 700);
      appendLog(logPath, "VoiceOver focus service probe text field", iosIdbTap(
        idbTarget, serviceProbePlan.textField.tap,
      ));
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
    }
    if (useVoiceOverAssist && previousVoiceOver) {
      const wasEnabled = /(^|\s)(1|true|yes)(\s|$)/i.test(previousVoiceOver.stdout || "");
      const restored = run("idb", [
        "set", "--domain", "com.apple.Accessibility", "--type", "bool",
        "VoiceOverTouchEnabled", wasEnabled ? "true" : "false", "--udid", idbTarget,
      ]);
      appendLog(logPath, "restore simulator VoiceOver setting", restored);
    }
  } else if (inputPlan) {
    const tap = run("idb", [
      "ui", "tap", String(inputPlan.tap.x), String(inputPlan.tap.y),
      "--udid", idbTarget,
    ]);
    appendLog(logPath, `idb tap accessibility button ${JSON.stringify(inputPlan.label)}`, tap);
    if (appConfig.ios.supportsScroll && inputPlan.swipe) {
      const swipe = run("idb", [
        "ui", "swipe",
        String(inputPlan.swipe.xStart), String(inputPlan.swipe.yStart),
        String(inputPlan.swipe.xEnd), String(inputPlan.swipe.yEnd),
        "--duration", "0.3", "--udid", idbTarget,
      ]);
      appendLog(logPath, "idb accessibility-frame swipe", swipe);
    }
  }
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1200);
  result = run("xcrun", ["simctl", "io", target, "screenshot", screenshotPath]);
  appendLog(logPath, "simctl screenshot after input", result);
  // Prefer the continuous stream so attach/IME/clipboard are not lost under
  // high-frequency scroll logs. Fall back to a long `log show` window.
  let streamLogs = existsSync(streamPath) ? readFileSync(streamPath, "utf8") : "";
  if (!streamLogs.includes("moui-mobile lifecycle attach")) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
    streamLogs = existsSync(streamPath) ? readFileSync(streamPath, "utf8") : streamLogs;
  }
  const appLogPredicate = launchPid
    ? `processIdentifier == ${launchPid} AND eventMessage CONTAINS 'moui-mobile'`
    : `process == '${appConfig.ios.productName}' AND eventMessage CONTAINS 'moui-mobile'`;
  result = run("xcrun", [
    "simctl", "spawn", target, "log", "show",
    "--style", "compact", "--last", "10m",
    "--predicate", appLogPredicate,
  ]);
  appendLog(logPath, "simctl log show", result);
  const showLogs = result.stdout || "";
  // Merge both sources; stream is primary for early lifecycle markers.
  const logs = [streamLogs, showLogs].filter(Boolean).join("\n");
  appendLog(logPath, "ios merged log markers", {
    status: 0,
    stdout: [
      `streamBytes=${streamLogs.length}`,
      `showBytes=${showLogs.length}`,
      `hasAttach=${logs.includes("moui-mobile lifecycle attach")}`,
      `hasImeState=${logs.includes("moui-mobile service ime state")}`,
      `hasImeEdit=${logs.includes("moui-mobile service ime edit")}`,
      `hasClipboardWrite=${logs.includes("moui-mobile service clipboard complete operation=write-text")}`,
      `hasClipboardRead=${logs.includes("moui-mobile service clipboard complete operation=read-text")}`,
      `hasAsyncLoading=${logs.includes("moui-mobile service async-image phase=loading")}`,
      `hasAsyncReady=${logs.includes("moui-mobile service async-image phase=ready")}`,
      `hasA11yFocus=${logs.includes("moui-mobile service accessibility focus")}`,
      `hasA11yAction=${logs.includes("moui-mobile service accessibility action")}`,
    ].join("\n"),
    stderr: "",
  });
  const pixelChange = compareScreenshots(beforePath, screenshotPath);
  observeLogs(observations, logs, appConfig.ios.supportsScroll, pixelChange);
  const backgrounded = idbReady
    ? run("idb", ["ui", "button", "HOME", "--udid", idbTarget])
    : run("xcrun", ["simctl", "launch", target, "com.apple.Preferences"]);
  appendLog(
    logPath,
    idbReady ? "idb HOME lifecycle background" : "simctl background app via Settings",
    backgrounded,
  );
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  // Stop stream after background so detach is still captured, then terminate.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
  const streamAfterBg = existsSync(streamPath) ? readFileSync(streamPath, "utf8") : logs;
  logStream.stop();
  appendLog(logPath, "ios log stream stop", {
    status: 0,
    stdout: streamPath,
    stderr: "",
  });
  const detachLogs = streamAfterBg;
  appendLog(logPath, "simctl detach log", {
    status: 0,
    stdout: detachLogs.split(/\r?\n/).filter(line => line.includes("lifecycle detach")).join("\n"),
    stderr: "",
  });
  observations.lifecycleDetach = hasIosApplicationLog(
    detachLogs,
    appConfig.ios.productName,
    "moui-mobile lifecycle detach",
  ) || detachLogs.includes("moui-mobile lifecycle detach")
    ? "yes"
    : "no";
  // Re-observe after detach/stream flush so late service markers still count.
  observeLogs(observations, streamAfterBg, appConfig.ios.supportsScroll, pixelChange);
  result = run("xcrun", ["simctl", "terminate", target, appConfig.ios.bundleId]);
  appendLog(logPath, "simctl terminate", result);
  observations.cleanShutdown = backgrounded.status === 0 && result.status === 0 ? "yes" : "no";
  return { observations, pixelChange };
};

const hdcArgs = device => device ? ["-t", device] : [];

const captureHarmonyScreenshot = (device, localPath, label, logPath) => {
  // DevEco/hdc snapshot_display on current images only accepts .jpeg/.jpg.
  const remotePath = `/data/local/tmp/moui-${Date.now()}.jpeg`;
  const targetArgs = hdcArgs(device);
  let result = run("hdc", [...targetArgs, "shell", "snapshot_display", "-f", remotePath]);
  appendLog(logPath, `${label} snapshot`, result);
  if (result.status !== 0) return result;
  // Recv to a .jpeg temp beside the desired local path, then convert/copy to PNG
  // when the recorder expects PNG (decodePng8). Prefer keeping the jpeg if the
  // local path already ends with .jpeg/.jpg.
  const wantsJpeg = /\.jpe?g$/i.test(localPath);
  const recvPath = wantsJpeg ? localPath : `${localPath}.jpeg`;
  result = run("hdc", [...targetArgs, "file", "recv", remotePath, recvPath]);
  appendLog(logPath, `${label} recv`, result);
  run("hdc", [...targetArgs, "shell", "rm", "-f", remotePath]);
  if (result.status !== 0) return result;
  if (!wantsJpeg) {
    // Convert jpeg -> png via sips (macOS) so analyzeScreenshot/decodePng8 works.
    const convert = run("sips", ["-s", "format", "png", recvPath, "--out", localPath]);
    appendLog(logPath, `${label} jpeg-to-png`, convert);
    try {
      if (existsSync(recvPath) && recvPath !== localPath) {
        // leave jpeg beside png for debugging; do not fail smoke if unlink fails
      }
    } catch {
      // ignore
    }
    if (convert.status !== 0) {
      // Fall back: if sips missing, keep jpeg path failure visible.
      return convert;
    }
  }
  return result;
};

// Stream `hdc hilog` continuously (filtered to the MoUIHarmony tag) so
// high-frequency pointer/scroll lines cannot push attach/IME/clipboard markers
// out of a short `hilog -d` window. Mirrors the iOS/Android log stream contract.
const startHarmonyLogStream = ({ device, outPath }) => {
  const targetArgs = hdcArgs(device);
  const fd = openSync(outPath, "w");
  const child = spawn(
    "hdc",
    [...targetArgs, "shell", "hilog", "-T", "MoUIHarmony"],
    {
      cwd: repoRoot,
      stdio: ["ignore", fd, fd],
    },
  );
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  return {
    child,
    stop: () => {
      try {
        if (!child.killed) child.kill("SIGTERM");
      } catch {
        // ignore
      }
      try {
        closeSync(fd);
      } catch {
        // ignore
      }
    },
  };
};

const runHarmonySmoke = ({ appConfig, artifact, logPath, beforePath, screenshotPath, device }) => {
  const observations = baseObservations(appConfig.harmonyos.supportsScroll);
  const targetArgs = hdcArgs(device);
  let result = run("hdc", ["list", "targets"]);
  appendLog(logPath, "hdc list targets", result);
  if (result.status !== 0) return { observations };
  result = run("hdc", [...targetArgs, "install", "-r", artifact]);
  appendLog(logPath, "hdc install", result);
  if (result.status !== 0) return { observations };
  run("hdc", [...targetArgs, "shell", "hilog", "-r"]);
  const harmonyStreamPath = join(dirname(logPath), "runtime-stream.log");
  const harmonyStream = startHarmonyLogStream({ device, outPath: harmonyStreamPath });
  const launchArgs = [
    ...targetArgs,
    "shell", "aa", "start", "-a", "EntryAbility", "-b", appConfig.harmonyos.bundleName,
  ];
  if (appConfig.id === "component_gallery") {
    launchArgs.push("--ps", "moui.mobile.testProbe", "1");
  }
  result = run("hdc", launchArgs);
  appendLog(logPath, "hdc launch", result);
  if (result.status !== 0) {
    harmonyStream.stop();
    return { observations };
  }
  // The repository-only plugin runs after the first semantics snapshot.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 3500);
  captureHarmonyScreenshot(device, beforePath, "hdc screenshot before input", logPath);
  let probePlan = null;
  let streamSnapshot = "";
  try {
    if (existsSync(harmonyStreamPath)) streamSnapshot = readFileSync(harmonyStreamPath, "utf8");
  } catch {
    // ignore
  }
  probePlan = parseMobileServiceProbePlan(streamSnapshot);
  if (probePlan) {
    appendLog(logPath, "hdc service probe plan from semantics", {
      status: 0,
      stdout: JSON.stringify(probePlan),
      stderr: "",
    });
  }
  if (appConfig.id === "component_gallery" && !probePlan) {
    // Try common uitest dump subcommands; older images reject bare `dump`.
    const dumpCommands = [
      ["uitest", "dumpLayout"],
      ["uitest", "dump"],
      ["uitest", "uiDump"],
    ];
    for (const cmd of dumpCommands) {
      const dumped = run("hdc", [...targetArgs, "shell", ...cmd]);
      appendLog(logPath, `hdc service probe accessibility dump (${cmd.join(" ")})`, dumped);
      let treeXml = (dumped.stdout || "").includes("<node")
        ? dumped.stdout || ""
        : "";
      if (!treeXml) {
        for (const remote of [
          "/data/local/tmp/output.xml",
          "/data/local/tmp/window_dump.xml",
          "/data/local/tmp/uitest_dump.xml",
        ]) {
          const tree = run("hdc", [...targetArgs, "shell", "cat", remote]);
          if (tree.status === 0 && (tree.stdout || "").includes("<node")) {
            appendLog(logPath, `hdc service probe accessibility tree ${remote}`, tree);
            treeXml = tree.stdout || "";
            break;
          }
        }
      }
      probePlan = treeXml ? harmonyServiceProbePlan(treeXml) : null;
      if (probePlan) break;
    }
    if (!probePlan) {
      try {
        if (existsSync(harmonyStreamPath)) {
          probePlan = parseMobileServiceProbePlan(readFileSync(harmonyStreamPath, "utf8"));
        }
      } catch {
        // ignore
      }
    }
    appendLog(logPath, "hdc service probe plan", {
      status: probePlan ? 0 : 1,
      stdout: probePlan ? JSON.stringify(probePlan) : "",
      stderr: probePlan ? "" : "service probe labels not found in uitest dump or semantics logs",
    });
  }
  // Prefer uitest click when available; otherwise fall back to raw click coords
  // from semantics plan / fixed center for representative input evidence.
  const clickAt = (x, y, label) => {
    let click = run("hdc", [...targetArgs, "shell", "uitest", "uiInput", "click", String(x), String(y)]);
    appendLog(logPath, label, click);
    if (click.status !== 0) {
      click = run("hdc", [...targetArgs, "shell", "uinput", "-T", "-d", String(x), String(y), "-u", String(x), String(y)]);
      appendLog(logPath, `${label} uinput fallback`, click);
    }
    return click;
  };
  if (probePlan) {
    clickAt(probePlan.textField.x, probePlan.textField.y, "hdc focus service probe text field");
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
    result = run("hdc", [...targetArgs, "shell", "uitest", "uiInput", "inputText", "ime-mobile-probe"]);
    appendLog(logPath, "hdc service probe IME text", result);
    clickAt(probePlan.action.x, probePlan.action.y, "hdc activate service probe button");
  } else {
    clickAt(160, 240, "hdc click");
  }
  if (appConfig.harmonyos.supportsScroll) {
    result = run("hdc", [...targetArgs, "shell", "uitest", "uiInput", "swipe", "220", "680", "220", "320", "300"]);
    appendLog(logPath, "hdc swipe", result);
    if (result.status !== 0) {
      // Best-effort pointer path for scroll evidence when uitest is unavailable.
      clickAt(220, 680, "hdc swipe fallback start");
      clickAt(220, 320, "hdc swipe fallback end");
    }
  }
  // Attempt a second surface size when possible (window size / rotation).
  const sizeProbe = run("hdc", [...targetArgs, "shell", "hidumper", "-s", "WindowManagerService", "-a", "-a"]);
  appendLog(logPath, "hdc window size probe", sizeProbe);
  // Wait for async-image ready + input logs; keep stream open through detach.
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 2000);
  captureHarmonyScreenshot(device, screenshotPath, "hdc screenshot after input", logPath);
  const pixelChange = compareScreenshots(beforePath, screenshotPath);
  // Background / terminate path before force-stop so detach logs can flush.
  result = run("hdc", [...targetArgs, "shell", "aa", "force-stop", appConfig.harmonyos.bundleName]);
  appendLog(logPath, "hdc force-stop", result);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1200);
  harmonyStream.stop();
  let harmonyStreamLogs = "";
  try {
    if (existsSync(harmonyStreamPath)) harmonyStreamLogs = readFileSync(harmonyStreamPath, "utf8");
  } catch {
    // ignore stream read failure; dump remains the fallback
  }
  if (harmonyStreamLogs) {
    writeFileSync(logPath, `## hdc hilog stream\n${harmonyStreamLogs}\n`, { flag: "a" });
  }
  result = run("hdc", [...targetArgs, "shell", "hilog", "-x"]);
  appendLog(logPath, "hdc hilog", result);
  const logs = `${harmonyStreamLogs}\n${result.stdout || ""}`;
  observeLogs(observations, logs, appConfig.harmonyos.supportsScroll, pixelChange);
  observations.lifecycleDetach = (
    logs.includes("moui-mobile lifecycle detach")
    || logs.includes("moui-mobile detach")
  ) ? "yes" : "no";
  observations.cleanShutdown = result.status === 0 ? "yes" : "no";
  return { observations, pixelChange };
};

try {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage);
    process.exit(0);
  }
  if (!options.platform || !options.app) throw new Error("--platform and --app are required");
  if (!["android", "ios", "harmonyos"].includes(options.platform)) throw new Error("--platform must be android, ios, or harmonyos");
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
  const beforePath = join(outDir, "screenshot-before.png");
  const screenshotPath = join(outDir, "screenshot.png");
  writeFileSync(logPath, "");
  let observations = baseObservations(platformConfig.supportsScroll);
  let pixelChange = { comparable: false, changedPixels: 0, changedRatio: 0 };
  if (!existsSync(artifact)) {
    writeFileSync(logPath, `missing artifact: ${artifact}\n`, { flag: "a" });
  } else if (options.platform === "android") {
    ({ observations, pixelChange } = runAndroidSmoke({
      appConfig,
      artifact,
      logPath,
      beforePath,
      screenshotPath,
      device: options.device,
      assistiveTech: options.assistiveTech,
    }));
  } else if (options.platform === "ios") {
    ({ observations, pixelChange } = runIosSmoke({
      appConfig,
      artifact,
      logPath,
      beforePath,
      screenshotPath,
      device: options.device,
      assistiveTech: options.assistiveTech,
    }));
  } else {
    ({ observations, pixelChange } = runHarmonySmoke({ appConfig, artifact, logPath, beforePath, screenshotPath, device: options.device }));
  }
  const screenshot = analyzeScreenshot(screenshotPath);
  if (screenshot.contentPixels >= 1024 && screenshot.distinctColorBuckets >= 4) {
    observations.nonblankFirstFrame = "yes";
  }
  const status = mobileRuntimeStatus(observations, screenshot, platformConfig.supportsScroll);
  const runtimeLogs = existsSync(logPath) ? readFileSync(logPath, "utf8") : "";
  let renderer = parseMobileRendererStatus(runtimeLogs);
  if (!renderer) {
    const buildJsonPath = join(dirname(artifact), "mobile-build.json");
    if (existsSync(buildJsonPath)) {
      try {
        renderer = rendererBlockFromMobileBuild(
          JSON.parse(readFileSync(buildJsonPath, "utf8")),
          options.platform,
        );
      } catch {
        renderer = null;
      }
    }
  }
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
        : options.platform === "ios"
          ? `scripts/build-mobile-ios-app.sh --app ${options.app}`
          : `scripts/build-mobile-harmonyos-hap.sh --app ${options.app}`,
    },
    artifacts: {
      screenshotBefore: beforePath,
      screenshot: screenshotPath,
      log: logPath,
    },
    screenshot,
    pixelChange,
    observations,
    evidenceBoundary: "non-fallback matching-host smoke evidence; fallback builds are packaging only",
  };
  // Optional Phase 2.3 renderer selection block. Never invent gpuPromoted=true
  // without runtime/build evidence. When logs report gpuPromoted=true, attach a
  // pending seven-gate skeleton so schema validation works; thresholds stay
  // unsatisfied until a real claim is recorded.
  if (renderer) {
    manifest.renderer = renderer;
    if (renderer.gpuPromoted === true) {
      manifest.gpuPromotionEvidence = pendingGpuPromotionEvidence();
    }
  }
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
