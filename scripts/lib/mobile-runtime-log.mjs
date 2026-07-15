export const hasIosApplicationLog = (logs, productName, marker) =>
  logs.split(/\r?\n/g).some(line =>
    line.includes(`${productName}[`) && line.includes(marker));

export const iosSimulatorLaunchPid = output => {
  const match = output.match(/:\s*([0-9]+)\s*$/m);
  return match ? match[1] : "";
};

export const mobileResizeDimensions = logs => {
  const dimensions = new Set();
  for (const match of logs.matchAll(
    /moui-mobile (?:lifecycle attach|resize)[^\r\n]*?width=(\d+)[^\r\n]*?height=(\d+)/g,
  )) {
    dimensions.add(`${match[1]}x${match[2]}`);
  }
  return [...dimensions];
};

export const hasMobileResizeTransition = logs =>
  mobileResizeDimensions(logs).length >= 2;

const hasAcceptedClipboardCompletion = (logs, operation) =>
  logs.split(/\r?\n/g).some(line =>
    line.includes(`moui-mobile service clipboard complete operation=${operation}`)
    && (!line.includes("accepted=") || /accepted=(?:1|true)(?:\s|$)/.test(line)));

export const hasMobileTextClipboardRoundTrip = logs =>
  hasAcceptedClipboardCompletion(logs, "write-text")
  && hasAcceptedClipboardCompletion(logs, "read-text");

const mobileTestProbeCounters = [
  "platformViewCreate",
  "platformViewResize",
  "platformViewClip",
  "platformViewEvent",
  "platformViewDispose",
  "hostChannelSuccess",
  "hostChannelError",
  "hostChannelCancel",
  "hostChannelExactlyOnce",
  "hostChannelLateAfterDispose",
  "serviceSmokeFired",
  "serviceSmokeCompleted",
];
const mobileTestProbeObservationFields = mobileTestProbeCounters.filter(
  counter => !counter.startsWith("serviceSmoke"),
);
const mobileCapabilityObservationFields = [
  ...mobileTestProbeObservationFields,
  "gpuRecovery",
  "stress",
];

///|
/// Parse the latest complete, well-formed test-probe counter snapshot. A
/// counter is evidence only when the repo-only plugin logged the runtime
/// transition; API presence or plugin staging never creates observations.
export const parseMobileTestProbeSnapshot = logs => {
  if (typeof logs !== "string") return null;
  let latest = null;
  for (const match of logs.matchAll(
    /moui-mobile test-probe snapshot=(\{[^\r\n]*\})/g,
  )) {
    try {
      const parsed = JSON.parse(match[1]);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) continue;
      const snapshot = {};
      let valid = true;
      for (const counter of mobileTestProbeCounters) {
        const value = parsed[counter];
        if (!Number.isSafeInteger(value) || value < 0) {
          valid = false;
          break;
        }
        snapshot[counter] = value;
      }
      if (valid) latest = snapshot;
    } catch {
      // Keep the last complete snapshot when a later line is truncated.
    }
  }
  return latest;
};

export const mobileTestProbeObservations = logs => {
  const snapshot = parseMobileTestProbeSnapshot(logs);
  if (!snapshot) return {};
  return Object.fromEntries(
    mobileTestProbeObservationFields
      .filter(counter => snapshot[counter] > 0)
      .map(counter => [counter, "yes"]),
  );
};

export const pendingMobileCapabilityObservations = () => Object.fromEntries(
  mobileCapabilityObservationFields.map(field => [field, "pending"]),
);

///|
/// Parse the latest `moui-mobile service probe plan textField=x,y action=x,y`
/// line emitted by Android/HarmonyOS shells from MoUI semantics. Returns null
/// when no plan is present. Used when uiautomator/uitest cannot see Canvas nodes.
export const parseMobileServiceProbePlan = logs => {
  let plan = null;
  for (const match of logs.matchAll(
    /moui-mobile service probe plan[^\r\n]*?textField=(\d+),(\d+)[^\r\n]*?action=(\d+),(\d+)/g,
  )) {
    plan = {
      textField: { x: Number(match[1]), y: Number(match[2]) },
      action: { x: Number(match[3]), y: Number(match[4]) },
    };
  }
  return plan;
};

const normalizeRendererSelected = value => {
  if (value === "SkiaGpuNative" || value === "skia-gpu-native" || value === "skia-gpu") {
    return "SkiaGpuNative";
  }
  if (value === "SkiaRasterNative" || value === "skia-raster-native" || value === "skia-raster") {
    return "SkiaRasterNative";
  }
  return "";
};

const normalizeSurfaceRoute = value => {
  if (typeof value !== "string") return "";
  const route = value.trim().toLowerCase();
  if (["raster", "metal-gpu", "vulkan-gpu", "egl-gpu", "direct3d-gpu"].includes(route)) {
    return route;
  }
  return "";
};

///|
/// Parse the last `moui-mobile renderer configure ... status={...}` JSON from
/// runtime logs into the mobile-runtime-smoke `renderer` block. Returns null
/// when no configure status is present.
export const parseMobileRendererStatus = logs => {
  if (typeof logs !== "string" || !logs.includes("moui-mobile renderer configure")) {
    return null;
  }
  let last = null;
  for (const match of logs.matchAll(
    /moui-mobile renderer configure[^\r\n]*?status=(\{[^\r\n]*\})/g,
  )) {
    try {
      last = JSON.parse(match[1]);
    } catch {
      // keep scanning for a later well-formed status payload
    }
  }
  if (!last || typeof last !== "object") return null;
  const requested = typeof last.requested === "string" ? last.requested : "";
  const selected = normalizeRendererSelected(last.selected);
  const surfaceRoute = normalizeSurfaceRoute(last.surfaceRoute);
  if (!["auto", "skia-gpu", "skia-raster"].includes(requested) || !selected || !surfaceRoute) {
    return null;
  }
  return {
    requested,
    selected,
    surfaceRoute,
    gpuAvailable: last.gpuAvailable === true,
    gpuPromoted: last.gpuPromoted === true,
    fallbackReason: typeof last.fallbackReason === "string"
      ? last.fallbackReason
      : last.fallbackReason == null
        ? ""
        : String(last.fallbackReason),
  };
};

const defaultSurfaceRouteForPlatform = platform => {
  switch (platform) {
    case "ios":
      return "metal-gpu";
    case "android":
      return "vulkan-gpu";
    case "harmonyos":
      return "egl-gpu";
    case "macos":
      return "metal-gpu";
    case "windows":
      return "direct3d-gpu";
    case "linux":
      return "vulkan-gpu";
    default:
      return "";
  }
};

///|
/// Fallback renderer block from mobile-build.json when runtime logs lack a
/// configure status. Never invents gpuPromoted=true without log/build truth.
/// `platform` is used only to fill a missing surfaceRoute for GPU selections.
export const rendererBlockFromMobileBuild = (buildJson, platform = "") => {
  const renderer = buildJson?.renderer;
  if (!renderer || typeof renderer !== "object") return null;
  const requested = typeof renderer.requested === "string" ? renderer.requested : "";
  const selected = normalizeRendererSelected(renderer.selected);
  if (!["auto", "skia-gpu", "skia-raster"].includes(requested) || !selected) {
    return null;
  }
  let surfaceRoute = normalizeSurfaceRoute(renderer.surfaceRoute);
  if (!surfaceRoute) {
    surfaceRoute = selected === "SkiaGpuNative"
      ? defaultSurfaceRouteForPlatform(platform || buildJson?.platform || "")
      : "raster";
  }
  if (!surfaceRoute) return null;
  return {
    requested,
    selected: selected || "SkiaRasterNative",
    surfaceRoute,
    // Build packaging cannot prove runtime GPU availability; leave false unless
    // the build metadata explicitly records it.
    gpuAvailable: renderer.gpuAvailable === true,
    gpuPromoted: renderer.gpuPromoted === true,
    fallbackReason: typeof renderer.fallbackReason === "string"
      ? renderer.fallbackReason
      : renderer.fallbackReason == null
        ? ""
        : String(renderer.fallbackReason),
  };
};

///|
/// Pending seven-gate skeleton required by the mobile runtime validator when
/// `renderer.gpuPromoted=true` but no matching-device promotion claim exists.
/// Values stay false/zero so `--require-passed` still fails honestly.
export const pendingGpuPromotionEvidence = () => ({
  // Explicitly not a seven-gate claim. Runtime smoke may still pass while
  // these gates remain unproven.
  claimed: false,
  readbackEliminated: false,
  rendererThread: false,
  mailboxOk: false,
  performance: {
    p95FrameMs: 0,
    droppedFramePercent: 100,
    inputToPresentPVsyncIntervals: 0,
  },
  memory: {
    bounded: false,
    surfaceRecreationCycles: 0,
    foregroundBackgroundCycles: 0,
  },
  contextLoss: {
    recoveredWithinVsyncs: 0,
    rasterFallbackPreservedAppRuntime: false,
  },
  rasterFallback: {
    automaticAfterRepeatedFailure: false,
  },
});

export const mobileRuntimeStatus = (observations, screenshot, supportsScroll) => {
  const required = [
    "lifecycleAttach",
    "lifecycleDetach",
    "nonblankFirstFrame",
    "resize",
    "representativeInput",
    "cleanShutdown",
    "ime",
    "clipboard",
    "accessibility",
    "asyncImage",
    ...mobileCapabilityObservationFields,
  ];
  if (supportsScroll) required.push("scrollInput");
  const screenshotPassed = screenshot.width > 0
    && screenshot.height > 0
    && screenshot.contentPixels >= 1024
    && screenshot.distinctColorBuckets >= 4;
  if (screenshotPassed && required.every(key => observations[key] === "yes")) {
    return "passed";
  }
  const hasPartialEvidence = screenshotPassed
    || Object.values(observations).some(value => value === "yes");
  return hasPartialEvidence ? "partial" : "failed";
};

const validFrame = value =>
  value
  && Number.isFinite(value.x)
  && Number.isFinite(value.y)
  && Number.isFinite(value.width)
  && Number.isFinite(value.height)
  && value.width > 0
  && value.height > 0;

const iosIdbNodes = encoded => {
  try {
    const nodes = JSON.parse(encoded);
    return Array.isArray(nodes) ? nodes : [];
  } catch {
    return [];
  }
};

const iosNodeLabel = node => {
  for (const key of ["AXLabel", "label", "name", "value"]) {
    if (typeof node?.[key] === "string" && node[key]) return node[key];
  }
  return "";
};

const iosNodeCenter = node => validFrame(node?.frame) ? {
  x: Math.round(node.frame.x + node.frame.width / 2),
  y: Math.round(node.frame.y + node.frame.height / 2),
} : null;

export const iosIdbElementPlan = (encoded, labels) => {
  const wanted = new Set(labels.map(label => label.toLowerCase()));
  const node = iosIdbNodes(encoded).find(candidate =>
    candidate?.enabled !== false
    && validFrame(candidate?.frame)
    && wanted.has(iosNodeLabel(candidate).toLowerCase()));
  const tap = iosNodeCenter(node);
  return tap ? { label: iosNodeLabel(node), tap } : null;
};

export const iosIdbServiceProbePlan = encoded => {
  const nodes = iosIdbNodes(encoded);
  const textField = nodes.find(node =>
    node?.enabled !== false
    && validFrame(node?.frame)
    && iosNodeLabel(node) === "Service probe text");
  const action = nodes.find(node =>
    node?.enabled !== false
    && validFrame(node?.frame)
    && iosNodeLabel(node) === "Activate service probe");
  const root = nodes.find(node =>
    node?.type === "Application" && validFrame(node.frame));
  const textTap = iosNodeCenter(textField);
  const actionTap = iosNodeCenter(action);
  if (!textTap || !actionTap) return null;
  return {
    textField: { label: iosNodeLabel(textField), tap: textTap, frame: textField.frame },
    action: { label: iosNodeLabel(action), tap: actionTap, frame: action.frame },
    swipe: root ? {
      xStart: Math.round(root.frame.x + root.frame.width / 2),
      yStart: Math.round(root.frame.y + root.frame.height * 0.8),
      xEnd: Math.round(root.frame.x + root.frame.width / 2),
      yEnd: Math.round(root.frame.y + root.frame.height * 0.35),
    } : null,
  };
};

export const iosIdbInputPlan = encoded => {
  const nodes = iosIdbNodes(encoded);
  const button = nodes.find(node =>
    node
    && node.enabled !== false
    && (node.role === "AXButton" || node.type === "Button")
    && validFrame(node.frame));
  if (!button) return null;
  const root = nodes.find(node =>
    node && node.type === "Application" && validFrame(node.frame));
  const frame = button.frame;
  const screen = root?.frame;
  return {
    label: typeof button.AXLabel === "string" ? button.AXLabel : "",
    tap: {
      x: Math.round(frame.x + frame.width / 2),
      y: Math.round(frame.y + frame.height / 2),
    },
    swipe: screen ? {
      xStart: Math.round(screen.x + screen.width / 2),
      yStart: Math.round(screen.y + screen.height * 0.75),
      xEnd: Math.round(screen.x + screen.width / 2),
      yEnd: Math.round(screen.y + screen.height * 0.25),
    } : null,
  };
};
