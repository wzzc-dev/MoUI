#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { decodePng8 } from "./lib/png-rgba.mjs";
import {
  hasMobileResizeTransition,
  hasMobileTextClipboardRoundTrip,
  hasIosApplicationLog,
  iosIdbElementPlan,
  iosIdbInputPlan,
  iosIdbServiceProbePlan,
  iosSimulatorLaunchPid,
  mobileRuntimeStatus,
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
  if (logs.includes("moui-mobile lifecycle attach")) observations.lifecycleAttach = "yes";
  if (hasMobileResizeTransition(logs)) observations.resize = "yes";
  const receivedPointer = logs.includes("moui-mobile input pointer");
  const receivedScroll = logs.includes("moui-mobile input scroll");
  const visibleChange = pixelChange.changedPixels >= 16;
  if (receivedPointer && visibleChange) observations.representativeInput = "yes";
  if (supportsScroll && receivedScroll && visibleChange) observations.scrollInput = "yes";
  if (logs.includes("moui-mobile service ime state") && logs.includes("moui-mobile service ime edit")) {
    observations.ime = "yes";
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
  result = run("adb", [...serialArgs, "shell", "am", "start", "-n", `${appConfig.android.applicationId}/dev.wzzc.moui.mobile.MobileActivity`]);
  appendLog(logPath, "adb launch", result);
  if (result.status !== 0) return { observations };
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  result = run("adb", [...serialArgs, "exec-out", "screencap", "-p"], { encoding: "buffer" });
  if (result.status === 0 && result.stdout?.length > 0) writeFileSync(beforePath, result.stdout);
  let probePlan = null;
  if (appConfig.id === "component_gallery") {
    const dumped = run("adb", [...serialArgs, "shell", "uiautomator", "dump", "/sdcard/moui-window.xml"]);
    appendLog(logPath, "adb service probe accessibility dump", dumped);
    const tree = run("adb", [...serialArgs, "shell", "cat", "/sdcard/moui-window.xml"]);
    appendLog(logPath, "adb service probe accessibility tree", tree);
    probePlan = tree.status === 0 ? androidServiceProbePlan(tree.stdout || "") : null;
  }
  if (probePlan) {
    result = run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.textField.x), String(probePlan.textField.y)]);
    appendLog(logPath, "adb focus service probe text field", result);
    result = run("adb", [...serialArgs, "shell", "input", "text", "-ime-mobile-probe"]);
    appendLog(logPath, "adb service probe IME text", result);
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
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 800);
    run("adb", [...serialArgs, "shell", "settings", "put", "system", "user_rotation", (rotation.stdout || "0").trim() || "0"]);
    run("adb", [...serialArgs, "shell", "settings", "put", "system", "accelerometer_rotation", (accelerometer.stdout || "1").trim() || "1"]);
    if (assistiveTech) {
      const enabledServices = run("adb", [...serialArgs, "shell", "settings", "get", "secure", "enabled_accessibility_services"]);
      appendLog(logPath, "adb enabled accessibility services", enabledServices);
      if (/talkback/i.test(enabledServices.stdout || "")) {
        appendLog(logPath, "TalkBack focus service probe action", run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.action.x), String(probePlan.action.y)]));
        appendLog(logPath, "TalkBack activate service probe action", run("adb", [...serialArgs, "shell", "input", "tap", String(probePlan.action.x), String(probePlan.action.y)]));
      }
    }
  } else {
    result = run("adb", [...serialArgs, "shell", "input", "tap", "160", "240"]);
    appendLog(logPath, "adb tap", result);
  }
  if (appConfig.android.supportsScroll) {
    result = run("adb", [...serialArgs, "shell", "input", "swipe", "220", "680", "220", "320", "300"]);
    appendLog(logPath, "adb swipe", result);
  }
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 750);
  result = run("adb", [...serialArgs, "exec-out", "screencap", "-p"], { encoding: "buffer" });
  if (result.status === 0 && result.stdout?.length > 0) {
    writeFileSync(screenshotPath, result.stdout);
  }
  result = run("adb", [...serialArgs, "logcat", "-d", "-t", "400"]);
  appendLog(logPath, "adb logcat", result);
  const logs = result.stdout || "";
  const pixelChange = compareScreenshots(beforePath, screenshotPath);
  observeLogs(observations, logs, appConfig.android.supportsScroll, pixelChange);
  result = run("adb", [...serialArgs, "shell", "am", "force-stop", appConfig.android.applicationId]);
  appendLog(logPath, "adb force-stop", result);
  const detached = run("adb", [...serialArgs, "logcat", "-d", "-t", "100"]);
  appendLog(logPath, "adb detach logcat", detached);
  observations.lifecycleDetach = (detached.stdout || "").includes("moui-mobile lifecycle detach") ? "yes" : "no";
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
  const script = [
    'tell application "Simulator" to activate',
    'tell application "System Events"',
    `  click menu item "${menuItem}" of menu "Device" of menu bar 1 of process "Simulator"`,
    'end tell',
  ].join("\n");
  const result = run("osascript", ["-e", script]);
  appendLog(logPath, `Simulator ${menuItem}`, result);
  return result;
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
  result = run("xcrun", ["simctl", "launch", target, appConfig.ios.bundleId]);
  appendLog(logPath, "simctl launch", result);
  if (result.status !== 0) return { observations };
  const launchPid = iosSimulatorLaunchPid(result.stdout || "");
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  let idbReady = false;
  let inputPlan = null;
  let serviceProbePlan = null;
  if (idbTarget) {
    const connect = run("idb", ["connect", idbTarget]);
    appendLog(logPath, "idb connect", connect);
    idbReady = connect.status === 0;
    let tree = { status: 1, stdout: "", stderr: "idb companion connection failed" };
    if (idbReady) {
      const found = pollIosIdbPlan(idbTarget, encoded => {
        serviceProbePlan = appConfig.id === "component_gallery"
          ? iosIdbServiceProbePlan(encoded)
          : null;
        inputPlan = serviceProbePlan || iosIdbInputPlan(encoded);
        return inputPlan;
      });
      tree = found.tree;
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
  if (serviceProbePlan) {
    let action = iosIdbTap(idbTarget, serviceProbePlan.textField.tap);
    appendLog(logPath, "idb focus service probe text field", action);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
    action = run("idb", [
      "ui", "text", "ime-mobile-probe", "--udid", idbTarget,
    ]);
    appendLog(logPath, "idb service probe IME text", action);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);

    const selected = driveIosEditMenuAction({
      idbTarget,
      point: serviceProbePlan.textField.tap,
      labels: ["Select All", "Select"],
      logPath,
      heading: "service probe select all",
    });
    if (selected) {
      const copied = pollIosIdbPlan(
        idbTarget,
        encoded => iosIdbElementPlan(encoded, ["Copy"]),
        8,
      );
      appendLog(logPath, "service probe copy menu tree", copied.tree);
      if (copied.plan) {
        action = iosIdbTap(idbTarget, copied.plan.tap);
        appendLog(logPath, "service probe system Copy", action);
      }
    }
    action = run("xcrun", ["simctl", "pbpaste", target]);
    appendLog(logPath, "simctl clipboard after MoUI Copy", action);
    action = run("xcrun", ["simctl", "pbcopy", target], {
      input: "clipboard-service-probe-中文-👩‍💻",
    });
    appendLog(logPath, "simctl seed system clipboard", action);
    driveIosEditMenuAction({
      idbTarget,
      point: serviceProbePlan.textField.tap,
      labels: ["Paste"],
      logPath,
      heading: "service probe system Paste",
    });

    action = iosIdbTap(idbTarget, serviceProbePlan.action.tap);
    appendLog(logPath, "idb activate service probe button", action);
    const keyboardDismiss = run("idb", [
      "ui", "key", "41", "--udid", idbTarget,
    ]);
    appendLog(logPath, "idb dismiss keyboard", keyboardDismiss);

    const rotated = rotateIosSimulator("left", logPath);
    if (rotated.status === 0) {
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
      rotateIosSimulator("right", logPath);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
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

    if (assistiveTech) {
      const previousVoiceOver = run("idb", [
        "get", "--domain", "com.apple.Accessibility",
        "VoiceOverTouchEnabled", "--udid", idbTarget,
      ]);
      appendLog(logPath, "read simulator VoiceOver setting", previousVoiceOver);
      const enabled = run("idb", [
        "set", "--domain", "com.apple.Accessibility", "--type", "bool",
        "VoiceOverTouchEnabled", "true", "--udid", idbTarget,
      ]);
      appendLog(logPath, "enable simulator VoiceOver", enabled);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
      appendLog(logPath, "VoiceOver focus service probe action", iosIdbTap(
        idbTarget, serviceProbePlan.action.tap,
      ));
      appendLog(logPath, "VoiceOver activate service probe action first tap", iosIdbTap(
        idbTarget, serviceProbePlan.action.tap, 0.05,
      ));
      appendLog(logPath, "VoiceOver activate service probe action second tap", iosIdbTap(
        idbTarget, serviceProbePlan.action.tap, 0.05,
      ));
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
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 750);
  result = run("xcrun", ["simctl", "io", target, "screenshot", screenshotPath]);
  appendLog(logPath, "simctl screenshot after input", result);
  const appLogPredicate = launchPid
    ? `processIdentifier == ${launchPid} AND eventMessage CONTAINS 'moui-mobile'`
    : `process == '${appConfig.ios.productName}' AND eventMessage CONTAINS 'moui-mobile'`;
  result = run("xcrun", ["simctl", "spawn", target, "log", "show", "--style", "compact", "--last", "2m", "--predicate", appLogPredicate]);
  appendLog(logPath, "simctl log show", result);
  const logs = result.stdout || "";
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
  const detachPredicate = launchPid
    ? `processIdentifier == ${launchPid} AND eventMessage CONTAINS 'moui-mobile lifecycle detach'`
    : `process == '${appConfig.ios.productName}' AND eventMessage CONTAINS 'moui-mobile lifecycle detach'`;
  const detached = run("xcrun", ["simctl", "spawn", target, "log", "show", "--style", "compact", "--last", "1m", "--predicate", detachPredicate]);
  appendLog(logPath, "simctl detach log", detached);
  observations.lifecycleDetach = hasIosApplicationLog(
    detached.stdout || "",
    appConfig.ios.productName,
    "moui-mobile lifecycle detach",
  ) ? "yes" : "no";
  result = run("xcrun", ["simctl", "terminate", target, appConfig.ios.bundleId]);
  appendLog(logPath, "simctl terminate", result);
  observations.cleanShutdown = backgrounded.status === 0 && result.status === 0 ? "yes" : "no";
  return { observations, pixelChange };
};

const hdcArgs = device => device ? ["-t", device] : [];

const captureHarmonyScreenshot = (device, localPath, label, logPath) => {
  const remotePath = `/data/local/tmp/moui-${Date.now()}.png`;
  const targetArgs = hdcArgs(device);
  let result = run("hdc", [...targetArgs, "shell", "snapshot_display", "-f", remotePath]);
  appendLog(logPath, `${label} snapshot`, result);
  if (result.status !== 0) return result;
  result = run("hdc", [...targetArgs, "file", "recv", remotePath, localPath]);
  appendLog(logPath, `${label} recv`, result);
  run("hdc", [...targetArgs, "shell", "rm", "-f", remotePath]);
  return result;
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
  result = run("hdc", [...targetArgs, "shell", "aa", "start", "-a", "EntryAbility", "-b", appConfig.harmonyos.bundleName]);
  appendLog(logPath, "hdc launch", result);
  if (result.status !== 0) return { observations };
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1500);
  captureHarmonyScreenshot(device, beforePath, "hdc screenshot before input", logPath);
  result = run("hdc", [...targetArgs, "shell", "uitest", "uiInput", "click", "160", "240"]);
  appendLog(logPath, "hdc click", result);
  if (appConfig.harmonyos.supportsScroll) {
    result = run("hdc", [...targetArgs, "shell", "uitest", "uiInput", "swipe", "220", "680", "220", "320", "300"]);
    appendLog(logPath, "hdc swipe", result);
  }
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 750);
  captureHarmonyScreenshot(device, screenshotPath, "hdc screenshot after input", logPath);
  result = run("hdc", [...targetArgs, "shell", "hilog", "-d"]);
  appendLog(logPath, "hdc hilog", result);
  const logs = result.stdout || "";
  const pixelChange = compareScreenshots(beforePath, screenshotPath);
  observeLogs(observations, logs, appConfig.harmonyos.supportsScroll, pixelChange);
  result = run("hdc", [...targetArgs, "shell", "aa", "force-stop", appConfig.harmonyos.bundleName]);
  appendLog(logPath, "hdc force-stop", result);
  const detached = run("hdc", [...targetArgs, "shell", "hilog", "-d"]);
  appendLog(logPath, "hdc detach hilog", detached);
  observations.lifecycleDetach = (detached.stdout || "").includes("moui-mobile lifecycle detach") ? "yes" : "no";
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
