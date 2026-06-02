#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { inflateSync } from "node:zlib";

const usage = () => {
  console.error(
    "Usage: node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 [--manifest artifacts/conformance/web-runtime-presentation.json] [--timeout-ms 12000] [--require-passed]",
  );
};

let baseUrl = "";
let cdpUrl = "";
let manifestPath = "artifacts/conformance/web-runtime-presentation.json";
let timeoutMs = 12000;
let requirePassed = false;

const args = process.argv.slice(2);
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === "--base-url") {
    baseUrl = args[i + 1] ?? "";
    i += 1;
  } else if (args[i] === "--cdp-url") {
    cdpUrl = args[i + 1] ?? "";
    i += 1;
  } else if (args[i] === "--manifest") {
    manifestPath = args[i + 1] ?? "";
    i += 1;
  } else if (args[i] === "--timeout-ms") {
    timeoutMs = Number(args[i + 1] ?? "");
    i += 1;
  } else if (args[i] === "--require-passed") {
    requirePassed = true;
  } else if (args[i] === "--help" || args[i] === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${args[i]}`);
    usage();
    process.exit(2);
  }
}

const localUrlPattern = /^http:\/\/(127\.0\.0\.1|localhost):\d+(\/.*)?$/;

if (!localUrlPattern.test(baseUrl) || !localUrlPattern.test(cdpUrl)) {
  usage();
  console.error("--base-url and --cdp-url must be local HTTP URLs.");
  process.exit(2);
}
if (!manifestPath) {
  usage();
  console.error("--manifest must not be empty.");
  process.exit(2);
}
if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
  usage();
  console.error("--timeout-ms must be a positive number.");
  process.exit(2);
}

const targets = [
  {
    name: "showcase-web-wasm",
    packagePath: "examples/showcase/web_wasm",
    path: "examples/showcase/web_wasm/index.html",
  },
  {
    name: "markdown-editor-web-wasm",
    packagePath: "examples/markdown_editor/web_wasm",
    path: "examples/markdown_editor/web_wasm/index.html",
  },
];

const normalizeBaseUrl = url => url.replace(/\/+$/, "");
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

const failedObservations = () => ({
  pageLoaded: "no",
  webGpuAvailable: "no",
  adapterRequested: "no",
  deviceRequested: "no",
  wasmStarted: "no",
  statusRunning: "no",
  canvasCreated: "no",
  canvasSized: "no",
  nonblankScreenshot: "no",
  cleanConsole: "no",
  resizeEvent: "no",
  resizedCanvas: "no",
  pointerInput: "no",
  keyboardInput: "no",
  textInput: "no",
  targetClosed: "no",
});

const failedPlatformObservations = () => ({
  windowOpened: "no",
  resizeRedraw: "no",
  representativeInput: "no",
  cleanExit: "no",
  surface: "no",
  redraw: "no",
  resizeScale: "no",
  consumerInput: "no",
  textInput: "no",
  rendererHandle: "no",
  cleanShutdown: "no",
});

const evidenceBoundary =
  "Browser-local WebGPU, wasm app startup, canvas sizing, resize/input event-bridge, target close, and screenshot evidence for the named browser session; this does not prove cross-browser compatibility, deterministic pixels, or native platform runtime behavior.";

const writeManifest = manifest => {
  mkdirSync(dirname(manifestPath), { recursive: true });
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`web runtime presentation manifest: ${manifestPath}`);
};

const validateManifest = () => {
  const validationArgs = ["scripts/validate-web-runtime-presentation-manifest.mjs", manifestPath];
  if (requirePassed) validationArgs.push("--require-passed");
  const validation = spawnSync(process.execPath, validationArgs, { encoding: "utf8" });
  if (validation.stdout) process.stdout.write(validation.stdout);
  if (validation.stderr) process.stderr.write(validation.stderr);
  if (validation.status !== 0) {
    process.exit(validation.status ?? 1);
  }
};

const writePreflightFailureManifest = error => {
  const message = error?.message || String(error);
  const targetResults = targets.map(target => ({
    name: target.name,
    packagePath: target.packagePath,
    path: target.path,
    url: `${normalizeBaseUrl(baseUrl)}/${target.path}?debug=1`,
    status: "failed",
    title: "unavailable",
    statusText: "Failed",
    bodyFailed: true,
    navigatorGpu: false,
    canvas: {
      count: 0,
      hostWidth: 0,
      hostHeight: 0,
      canvasWidth: 0,
      canvasHeight: 0,
      clientWidth: 0,
      clientHeight: 0,
    },
    runtimeSignals: {
      adapterRequested: false,
      deviceRequested: false,
      wasmStarted: false,
      running: false,
    },
    evidenceEvents: [],
    screenshot: {
      artifact: join("artifacts/conformance/web-runtime-presentation", `${target.name}.png`),
      width: 0,
      height: 0,
      totalPixels: 0,
      contentPixels: 0,
      distinctColorBuckets: 0,
    },
    observations: failedObservations(),
    consoleErrors: [message],
    notes: ["Browser/CDP preflight failed before page evidence could be collected"],
  }));
  const manifest = {
    schemaVersion: 1,
    mode: "web-runtime-presentation",
    generatedBy: "scripts/record-web-runtime-presentation.mjs",
    baseUrl: normalizeBaseUrl(baseUrl),
    cdpUrl: normalizeBaseUrl(cdpUrl),
    overallStatus: "failed",
    evidenceBoundary,
    browser: {
      product: "unavailable",
      userAgent: "unavailable",
      protocolVersion: "unavailable",
    },
    platformObservations: failedPlatformObservations(),
    targets: targetResults,
  };
  writeManifest(manifest);
  validateManifest();
  console.error(`web runtime presentation preflight failed: ${message}`);
  process.exit(1);
};

const fetchJson = async url => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status} ${response.statusText}`);
  }
  return await response.json();
};

class CdpSession {
  constructor(webSocketUrl) {
    this.webSocketUrl = webSocketUrl;
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
  }

  async connect() {
    this.socket = new WebSocket(this.webSocketUrl);
    this.socket.addEventListener("message", event => this.onMessage(event));
    await new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error(`Timed out connecting to ${this.webSocketUrl}`)),
        timeoutMs,
      );
      this.socket.addEventListener("open", () => {
        clearTimeout(timer);
        resolve();
      }, { once: true });
      this.socket.addEventListener("error", error => {
        clearTimeout(timer);
        reject(new Error(`WebSocket connection failed: ${error.message || error.type}`));
      }, { once: true });
    });
  }

  onMessage(event) {
    const message = JSON.parse(event.data);
    if (message.id && this.pending.has(message.id)) {
      const { resolve, reject } = this.pending.get(message.id);
      this.pending.delete(message.id);
      if (message.error) {
        reject(new Error(message.error.message || JSON.stringify(message.error)));
      } else {
        resolve(message.result ?? {});
      }
      return;
    }
    if (message.method) {
      this.events.push(message);
    }
  }

  send(method, params = {}) {
    const id = this.nextId;
    this.nextId += 1;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timed out waiting for CDP method ${method}`));
      }, timeoutMs);
      this.pending.set(id, {
        resolve: result => {
          clearTimeout(timer);
          resolve(result);
        },
        reject: error => {
          clearTimeout(timer);
          reject(error);
        },
      });
      this.socket.send(payload);
    });
  }

  close() {
    this.socket?.close();
  }
}

const createPageTarget = async () => {
  const response = await fetch(`${normalizeBaseUrl(cdpUrl)}/json/new?about:blank`, {
    method: "PUT",
  });
  if (!response.ok) {
    throw new Error(`CDP target creation failed: ${response.status} ${response.statusText}`);
  }
  return await response.json();
};

const closePageTarget = async id => {
  try {
    const response = await fetch(`${normalizeBaseUrl(cdpUrl)}/json/close/${encodeURIComponent(id)}`);
    if (!response.ok) return false;
    const deadline = Date.now() + Math.min(timeoutMs, 2000);
    while (Date.now() < deadline) {
      await sleep(100);
      const targets = await fetchJson(`${normalizeBaseUrl(cdpUrl)}/json/list`);
      if (!targets.some(target => target?.id === id)) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
};

const evaluate = async (session, expression) => {
  const result = await session.send("Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (result.exceptionDetails) {
    throw new Error(
      result.exceptionDetails.text || result.exceptionDetails.exception?.description || "evaluation failed",
    );
  }
  return result.result?.value;
};

const paeth = (a, b, c) => {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
};

const decodePng8 = buffer => {
  if (buffer.toString("ascii", 1, 4) !== "PNG") {
    throw new Error("screenshot is not a PNG");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  const idat = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    const data = buffer.subarray(dataStart, dataEnd);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
    offset = dataEnd + 4;
  }

  if (bitDepth !== 8 || ![2, 6].includes(colorType)) {
    throw new Error(`unsupported PNG screenshot format bitDepth=${bitDepth} colorType=${colorType}`);
  }

  const channels = colorType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = inflateSync(Buffer.concat(idat));
  const pixels = Buffer.alloc(width * height * 4);
  let rawOffset = 0;
  const previous = Buffer.alloc(stride);
  const current = Buffer.alloc(stride);

  for (let y = 0; y < height; y += 1) {
    const filter = raw[rawOffset];
    rawOffset += 1;
    raw.copy(current, 0, rawOffset, rawOffset + stride);
    rawOffset += stride;

    for (let x = 0; x < stride; x += 1) {
      const left = x >= channels ? current[x - channels] : 0;
      const up = previous[x];
      const upLeft = x >= channels ? previous[x - channels] : 0;
      if (filter === 1) {
        current[x] = (current[x] + left) & 0xff;
      } else if (filter === 2) {
        current[x] = (current[x] + up) & 0xff;
      } else if (filter === 3) {
        current[x] = (current[x] + Math.floor((left + up) / 2)) & 0xff;
      } else if (filter === 4) {
        current[x] = (current[x] + paeth(left, up, upLeft)) & 0xff;
      } else if (filter !== 0) {
        throw new Error(`unsupported PNG filter ${filter}`);
      }
    }

    for (let x = 0; x < width; x += 1) {
      const src = x * channels;
      const dst = (y * width + x) * 4;
      pixels[dst] = current[src];
      pixels[dst + 1] = current[src + 1];
      pixels[dst + 2] = current[src + 2];
      pixels[dst + 3] = channels === 4 ? current[src + 3] : 255;
    }

    current.copy(previous);
  }

  return { width, height, data: pixels };
};

const summarizeScreenshot = base64 => {
  const buffer = Buffer.from(base64, "base64");
  const png = decodePng8(buffer);
  const buckets = new Set();
  let contentPixels = 0;
  for (let i = 0; i < png.data.length; i += 4) {
    const r = png.data[i];
    const g = png.data[i + 1];
    const b = png.data[i + 2];
    const a = png.data[i + 3];
    if (a > 0 && (r < 240 || g < 240 || b < 240)) {
      contentPixels += 1;
    }
    buckets.add(`${r >> 4}:${g >> 4}:${b >> 4}:${a >> 4}`);
  }
  return {
    width: png.width,
    height: png.height,
    totalPixels: png.width * png.height,
    contentPixels,
    distinctColorBuckets: buckets.size,
  };
};

const collectPageState = async session => {
  return await evaluate(session, `(() => {
    const status = document.querySelector("#status")?.textContent?.trim() || "";
    const log = document.querySelector("#log")?.textContent || "";
    const host = document.querySelector("#canvas-host");
    const canvas = host?.querySelector("canvas") || document.querySelector("canvas");
    const hostRect = host?.getBoundingClientRect?.();
    return {
      title: document.title,
      statusText: status,
      logText: log,
      bodyFailed: document.body.classList.contains("failed"),
      navigatorGpu: !!navigator.gpu,
      canvas: {
        count: document.querySelectorAll("canvas").length,
        hostWidth: hostRect?.width || 0,
        hostHeight: hostRect?.height || 0,
        canvasWidth: canvas?.width || 0,
        canvasHeight: canvas?.height || 0,
        clientWidth: canvas?.clientWidth || 0,
        clientHeight: canvas?.clientHeight || 0,
      },
    };
  })()`);
};

const collectEvidenceEvents = async session => {
  return await evaluate(session, `(() => {
    const events = globalThis.__mouiWebRuntimeEvidence?.events;
    return Array.isArray(events) ? events : [];
  })()`);
};

const canvasRectForInput = async session => {
  return await evaluate(session, `(() => {
    const canvas = document.querySelector("#canvas-host canvas") || document.querySelector("canvas");
    const rect = canvas?.getBoundingClientRect?.();
    return {
      left: rect?.left || 0,
      top: rect?.top || 0,
      width: rect?.width || 0,
      height: rect?.height || 0,
    };
  })()`);
};

const textInputPoint = target => {
  if (target.name === "markdown-editor-web-wasm") {
    return { x: 560, y: 300 };
  }
  return { x: 150, y: 185 };
};

const performInteractionProbe = async (session, target) => {
  await session.send("Emulation.setDeviceMetricsOverride", {
    width: 1120,
    height: 720,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await evaluate(session, `window.dispatchEvent(new Event("resize"))`);
  await sleep(350);

  const rect = await canvasRectForInput(session);
  const fallbackX = Math.max(20, Math.round(rect.left + rect.width / 2));
  const fallbackY = Math.max(20, Math.round(rect.top + rect.height / 2));
  const inputPoint = textInputPoint(target);
  const x = rect.width > 0 ? Math.min(rect.left + rect.width - 12, Math.max(rect.left + 12, inputPoint.x)) : fallbackX;
  const y = rect.height > 0 ? Math.min(rect.top + rect.height - 12, Math.max(rect.top + 12, inputPoint.y)) : fallbackY;

  await session.send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, button: "none" });
  await session.send("Input.dispatchMouseEvent", {
    type: "mousePressed",
    x,
    y,
    button: "left",
    buttons: 1,
    clickCount: 1,
  });
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseReleased",
    x,
    y,
    button: "left",
    buttons: 0,
    clickCount: 1,
  });
  await sleep(250);
  await session.send("Input.dispatchKeyEvent", {
    type: "keyDown",
    key: "a",
    code: "KeyA",
    text: "a",
    unmodifiedText: "a",
    windowsVirtualKeyCode: 65,
    nativeVirtualKeyCode: 65,
  });
  await session.send("Input.dispatchKeyEvent", {
    type: "keyUp",
    key: "a",
    code: "KeyA",
    windowsVirtualKeyCode: 65,
    nativeVirtualKeyCode: 65,
  });
  await session.send("Input.insertText", { text: "moui" });
  await sleep(550);
};

const runtimeSignalsFromLog = logText => ({
  adapterRequested: logText.includes("Requesting WebGPU adapter"),
  deviceRequested: logText.includes("Requesting WebGPU device"),
  wasmStarted: logText.includes("MoonBit app started") || logText.includes("MoonBit wasm-gc started"),
  running: logText.includes("MoonBit wasm-gc started") || logText.includes("Running"),
});

const hasEvent = (events, names) => events.some(event => names.includes(event?.name));

const deriveTargetStatus = (target, observations) => {
  const required = [
    "pageLoaded",
    "webGpuAvailable",
    "adapterRequested",
    "deviceRequested",
    "wasmStarted",
    "statusRunning",
    "canvasCreated",
    "canvasSized",
    "nonblankScreenshot",
    "cleanConsole",
    "resizeEvent",
    "resizedCanvas",
    "pointerInput",
    "keyboardInput",
    "targetClosed",
  ];
  if (target.name === "markdown-editor-web-wasm") {
    required.push("textInput");
  }
  return required.every(key => observations[key] === "yes") ? "passed" : "failed";
};

const consoleErrorsFor = events => {
  const messages = [];
  for (const event of events) {
    if (event.method === "Runtime.exceptionThrown") {
      messages.push(event.params?.exceptionDetails?.text || "Runtime exception");
    }
    if (event.method === "Runtime.consoleAPICalled" && event.params?.type === "error") {
      const args = event.params.args ?? [];
      const text = args
        .map(arg => arg.value ?? arg.description ?? arg.unserializableValue ?? "")
        .filter(value => value !== "")
        .join(" ");
      messages.push(text || "console.error");
    }
    if (event.method === "Log.entryAdded" && event.params?.entry?.level === "error") {
      const url = event.params.entry.url || "";
      if (url.endsWith("/favicon.ico")) {
        continue;
      }
      const text = event.params.entry.text || "log error";
      messages.push(url ? `${text} (${url})` : text);
    }
  }
  return [...new Set(messages)];
};

const probeTarget = async target => {
  const pageTarget = await createPageTarget();
  const session = new CdpSession(pageTarget.webSocketDebuggerUrl);
  const url = `${normalizeBaseUrl(baseUrl)}/${target.path}?debug=1&evidence=${Date.now()}`;
  const artifact = join(
    "artifacts/conformance/web-runtime-presentation",
    `${target.name}.png`,
  );
  const notes = [];

  try {
    await session.connect();
    await session.send("Page.enable");
    await session.send("Network.enable");
    await session.send("Network.setCacheDisabled", { cacheDisabled: true });
    await session.send("Runtime.enable");
    await session.send("Log.enable");
    await session.send("Page.addScriptToEvaluateOnNewDocument", {
      source: `globalThis.__mouiWebRuntimeEvidence = {
        events: [],
        recordEvent(event) { this.events.push(event); }
      };`,
    });
    await session.send("Emulation.setDeviceMetricsOverride", {
      width: 1280,
      height: 800,
      deviceScaleFactor: 1,
      mobile: false,
    });
    await session.send("Page.navigate", { url });

    const deadline = Date.now() + timeoutMs;
    let state = await collectPageState(session);
    while (Date.now() < deadline) {
      state = await collectPageState(session);
      if (state.statusText === "Running" || state.bodyFailed) break;
      await sleep(250);
    }
    await sleep(500);
    await performInteractionProbe(session, target);
    state = await collectPageState(session);

    let screenshotError = "";
    let screenshot = {
      artifact,
      width: 0,
      height: 0,
      totalPixels: 0,
      contentPixels: 0,
      distinctColorBuckets: 0,
    };
    try {
      const screenshotResult = await session.send("Page.captureScreenshot", {
        format: "png",
        fromSurface: true,
      });
      mkdirSync(dirname(artifact), { recursive: true });
      writeFileSync(artifact, Buffer.from(screenshotResult.data, "base64"));
      screenshot = {
        artifact,
        ...(await summarizeScreenshot(screenshotResult.data)),
      };
    } catch (error) {
      screenshotError = `Screenshot capture failed: ${error.message}`;
    }
    const runtimeSignals = runtimeSignalsFromLog(state.logText);
    const evidenceEvents = await collectEvidenceEvents(session);
    const errors = consoleErrorsFor(session.events);
    if (screenshotError) {
      errors.push(screenshotError);
    }
    if (state.statusText !== "Running") {
      notes.push(`status was '${state.statusText || ""}'`);
    }
    if (state.bodyFailed) {
      notes.push("page marked body.failed");
    }
    if (!state.navigatorGpu) {
      notes.push("navigator.gpu unavailable in this browser session");
    }
    if (errors.length > 0) {
      notes.push("console/runtime errors were observed");
    }
    if (screenshotError) {
      notes.push("screenshot capture failed");
    }
    if (screenshot.contentPixels < 500 || screenshot.distinctColorBuckets < 6) {
      notes.push("screenshot did not meet nonblank content threshold");
    }

    const targetClosed = await closePageTarget(pageTarget.id);
    const observations = {
      pageLoaded: "yes",
      webGpuAvailable: state.navigatorGpu ? "yes" : "no",
      adapterRequested: runtimeSignals.adapterRequested ? "yes" : "no",
      deviceRequested: runtimeSignals.deviceRequested ? "yes" : "no",
      wasmStarted: runtimeSignals.wasmStarted ? "yes" : "no",
      statusRunning: state.statusText === "Running" ? "yes" : "no",
      canvasCreated: state.canvas.count > 0 ? "yes" : "no",
      canvasSized: state.canvas.canvasWidth > 0 && state.canvas.canvasHeight > 0 ? "yes" : "no",
      nonblankScreenshot: screenshot.contentPixels >= 500 && screenshot.distinctColorBuckets >= 6 ? "yes" : "no",
      cleanConsole: errors.length === 0 ? "yes" : "no",
      resizeEvent: hasEvent(evidenceEvents, ["resize"]) ? "yes" : "no",
      resizedCanvas: state.canvas.clientWidth === 1120 && state.canvas.clientHeight === 720 ? "yes" : "no",
      pointerInput: hasEvent(evidenceEvents, ["pointer_down", "pointer_up", "pointer_move"]) ? "yes" : "no",
      keyboardInput: hasEvent(evidenceEvents, ["key_down", "key_up"]) ? "yes" : "no",
      textInput: hasEvent(evidenceEvents, ["ime_commit"]) ? "yes" : "no",
      targetClosed: targetClosed ? "yes" : "no",
    };
    if (observations.resizeEvent !== "yes" || observations.resizedCanvas !== "yes") {
      notes.push("resize evidence did not reach the wasm event bridge and resized canvas state");
    }
    if (observations.pointerInput !== "yes" || observations.keyboardInput !== "yes") {
      notes.push("representative input evidence did not reach the wasm event bridge");
    }
    if (observations.textInput !== "yes") {
      notes.push("text input commit was not observed for this target");
    }
    if (observations.targetClosed !== "yes") {
      notes.push("CDP target did not close cleanly after evidence collection");
    }
    const status = deriveTargetStatus(target, observations);

    return {
      name: target.name,
      packagePath: target.packagePath,
      path: target.path,
      url,
      status,
      title: state.title,
      statusText: state.statusText,
      bodyFailed: state.bodyFailed,
      navigatorGpu: state.navigatorGpu,
      canvas: state.canvas,
      runtimeSignals,
      evidenceEvents,
      screenshot,
      observations,
      consoleErrors: errors,
      notes,
    };
  } catch (error) {
    const fallbackScreenshot = {
      artifact,
      width: 0,
      height: 0,
      totalPixels: 0,
      contentPixels: 0,
      distinctColorBuckets: 0,
    };
    return {
      name: target.name,
      packagePath: target.packagePath,
      path: target.path,
      url,
      status: "failed",
      title: "unavailable",
      statusText: "Failed",
      bodyFailed: true,
      navigatorGpu: false,
      canvas: {
        count: 0,
        hostWidth: 0,
        hostHeight: 0,
        canvasWidth: 0,
        canvasHeight: 0,
        clientWidth: 0,
        clientHeight: 0,
      },
      runtimeSignals: {
        adapterRequested: false,
        deviceRequested: false,
        wasmStarted: false,
        running: false,
      },
      screenshot: fallbackScreenshot,
      evidenceEvents: [],
      observations: {
        pageLoaded: "no",
        webGpuAvailable: "no",
        adapterRequested: "no",
        deviceRequested: "no",
        wasmStarted: "no",
        statusRunning: "no",
        canvasCreated: "no",
        canvasSized: "no",
        nonblankScreenshot: "no",
        cleanConsole: "no",
      },
      consoleErrors: [error.message],
      notes: ["CDP probe failed before page evidence was complete"],
    };
  } finally {
    session.close();
    await closePageTarget(pageTarget.id);
  }
};

const allTargetsObserved = (targets, key) =>
  targets.length > 0 && targets.every(target => target?.observations?.[key] === "yes");

const markdownTextInputObserved = targets =>
  targets.some(target =>
    target?.name === "markdown-editor-web-wasm" &&
    target?.observations?.textInput === "yes"
  );

const derivePlatformObservations = targetResults => ({
  windowOpened: allTargetsObserved(targetResults, "pageLoaded") ? "yes" : "no",
  resizeRedraw:
    allTargetsObserved(targetResults, "resizeEvent") &&
    allTargetsObserved(targetResults, "resizedCanvas") &&
    allTargetsObserved(targetResults, "nonblankScreenshot")
      ? "yes"
      : "no",
  representativeInput:
    allTargetsObserved(targetResults, "pointerInput") &&
    allTargetsObserved(targetResults, "keyboardInput")
      ? "yes"
      : "no",
  cleanExit: allTargetsObserved(targetResults, "targetClosed") ? "yes" : "no",
  surface:
    allTargetsObserved(targetResults, "webGpuAvailable") &&
    allTargetsObserved(targetResults, "deviceRequested") &&
    allTargetsObserved(targetResults, "canvasCreated") &&
    allTargetsObserved(targetResults, "canvasSized")
      ? "yes"
      : "no",
  redraw:
    allTargetsObserved(targetResults, "statusRunning") &&
    allTargetsObserved(targetResults, "nonblankScreenshot") &&
    allTargetsObserved(targetResults, "cleanConsole")
      ? "yes"
      : "no",
  resizeScale:
    allTargetsObserved(targetResults, "resizeEvent") &&
    allTargetsObserved(targetResults, "resizedCanvas")
      ? "yes"
      : "no",
  consumerInput:
    allTargetsObserved(targetResults, "pointerInput") &&
    allTargetsObserved(targetResults, "keyboardInput")
      ? "yes"
      : "no",
  textInput: markdownTextInputObserved(targetResults) ? "yes" : "no",
  rendererHandle:
    allTargetsObserved(targetResults, "deviceRequested") &&
    allTargetsObserved(targetResults, "wasmStarted") &&
    allTargetsObserved(targetResults, "cleanConsole")
      ? "yes"
      : "no",
  cleanShutdown: allTargetsObserved(targetResults, "targetClosed") ? "yes" : "no",
});

let browserVersion;
try {
  browserVersion = await fetchJson(`${normalizeBaseUrl(cdpUrl)}/json/version`);
} catch (error) {
  writePreflightFailureManifest(error);
}
const targetResults = [];

for (const target of targets) {
  targetResults.push(await probeTarget(target));
}

const platformObservations = derivePlatformObservations(targetResults);
const overallStatus =
  targetResults.every(target => target.status === "passed") &&
  Object.values(platformObservations).every(value => value === "yes")
    ? "passed"
    : "failed";

const manifest = {
  schemaVersion: 1,
  mode: "web-runtime-presentation",
  generatedBy: "scripts/record-web-runtime-presentation.mjs",
  baseUrl: normalizeBaseUrl(baseUrl),
  cdpUrl: normalizeBaseUrl(cdpUrl),
  overallStatus,
  evidenceBoundary,
  browser: {
    product: browserVersion.Browser ?? "unknown",
    userAgent: browserVersion["User-Agent"] ?? "unknown",
    protocolVersion: browserVersion["Protocol-Version"] ?? "unknown",
  },
  platformObservations,
  targets: targetResults,
};

writeManifest(manifest);
validateManifest();

if (requirePassed && overallStatus !== "passed") {
  process.exit(1);
}

console.log(`web runtime presentation: ${overallStatus}`);
