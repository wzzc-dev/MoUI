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

export const hasMobileTextClipboardRoundTrip = logs =>
  logs.includes("moui-mobile service clipboard complete operation=write-text")
  && logs.includes("moui-mobile service clipboard complete operation=read-text");

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
