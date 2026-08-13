#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import {
  CdpSession,
  closePageTarget,
  createPageTarget,
  evaluate,
  fetchJson,
} from "./lib/web-runtime-cdp.mjs";
import { validateEvidenceManifest } from "./validate-accessibility-foundation.mjs";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const probe = JSON.parse(readFileSync(resolve(repoRoot, "checks/accessibility-probe.json"), "utf8"));
const defaultManifest = resolve(repoRoot, "artifacts/accessibility/web/manifest.json");
const stableIds = probe.controls.map(control => control.id);
const expectedRoles = new Map([
  ["a11y.button", "button"],
  ["a11y.checkbox", "checkbox"],
  ["a11y.slider", "slider"],
  ["a11y.textfield", "textbox"],
  ["a11y.dialog", "dialog"],
  ["a11y.tree", "tree"],
  ["a11y.grid", "grid"],
  ["a11y.scroll", "region"],
  ["a11y.status", "status"],
  ["a11y.alert", "alert"],
  ["a11y.image", "image"],
  ["a11y.separator", "separator"],
]);

const args = process.argv.slice(2);
const options = {
  baseUrl: "",
  cdpUrl: "",
  manifest: defaultManifest,
  timeoutMs: 20000,
  requirePassed: false,
};
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (["--base-url", "--cdp-url", "--manifest", "--timeout-ms"].includes(arg)) {
    const value = args[index + 1];
    if (!value) throw new Error(`${arg} requires a value`);
    if (arg === "--base-url") options.baseUrl = value.replace(/\/+$/, "");
    if (arg === "--cdp-url") options.cdpUrl = value.replace(/\/+$/, "");
    if (arg === "--manifest") options.manifest = resolve(repoRoot, value);
    if (arg === "--timeout-ms") options.timeoutMs = Number(value);
    index += 1;
  } else if (arg === "--require-passed") {
    options.requirePassed = true;
  } else if (arg === "--help" || arg === "-h") {
    console.error("Usage: node scripts/record-web-accessibility-evidence.mjs --base-url URL --cdp-url URL [--manifest PATH] [--timeout-ms N] [--require-passed]");
    process.exit(0);
  } else {
    throw new Error(`unknown argument: ${arg}`);
  }
}
if (!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(options.baseUrl) ||
    !/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(options.cdpUrl)) {
  throw new Error("--base-url and --cdp-url must be local HTTP URLs");
}
if (!Number.isFinite(options.timeoutMs) || options.timeoutMs <= 0) {
  throw new Error("--timeout-ms must be positive");
}

const sleep = ms => new Promise(resolvePromise => setTimeout(resolvePromise, ms));
const ensureDir = path => mkdirSync(dirname(path), { recursive: true });
const writeManifest = manifest => {
  ensureDir(options.manifest);
  writeFileSync(options.manifest, `${JSON.stringify(manifest, null, 2)}\n`);
};
const command = (name, commandArgs) => {
  const result = spawnSync(name, commandArgs, { cwd: repoRoot, encoding: "utf8" });
  return (result.stdout ?? "").trim() || (result.stderr ?? "").trim() || "unknown";
};
const attrMap = attributes => {
  const result = {};
  for (let index = 0; index < (attributes?.length ?? 0); index += 2) {
    result[attributes[index]] = attributes[index + 1] ?? "";
  }
  return result;
};
const propertyMap = properties => Object.fromEntries(
  (properties ?? []).map(property => [property.name, property.value?.value ?? null]),
);
const semanticSelector = id => `[data-moui-semantic-id="${id}"]`;

const pageState = async session => evaluate(session, `(() => {
  const nodes = [...document.querySelectorAll('[data-moui-semantic-id]')];
  const active = document.activeElement;
  return {
    generation: document.querySelector('.moui-semantics-layer')?.dataset?.mouiSemanticsGeneration ?? '',
    ids: nodes.map(node => node.getAttribute('data-moui-semantic-id')).filter(Boolean),
    nodeIds: Object.fromEntries(nodes.map(node => [
      node.getAttribute('data-moui-semantic-id'),
      node.getAttribute('data-moui-semantics-node-id') ?? '',
    ])),
    activeSemanticId: active?.getAttribute?.('data-moui-semantic-id') ?? '',
    activeTag: active?.tagName?.toLowerCase?.() ?? '',
    statusText: nodes.find(node => node.getAttribute('data-moui-semantic-id') === 'a11y.status')?.textContent ?? '',
    alertText: nodes.find(node => node.getAttribute('data-moui-semantic-id') === 'a11y.alert')?.textContent ?? '',
    attributes: Object.fromEntries(nodes.map(node => [
      node.getAttribute('data-moui-semantic-id'),
      Object.fromEntries([...node.attributes].map(attribute => [attribute.name, attribute.value])),
    ])),
  };
})()`);

const waitFor = async (predicate, session, label) => {
  const deadline = Date.now() + options.timeoutMs;
  let value;
  while (Date.now() < deadline) {
    value = await predicate();
    if (value) return value;
    await sleep(120);
  }
  throw new Error(`timed out waiting for ${label}`);
};

const waitForIds = (session, ids) => waitFor(
  async () => {
    const state = await pageState(session);
    return ids.every(id => state.ids.includes(id)) ? state : undefined;
  },
  session,
  `semantic ids ${ids.join(", ")}`,
);

const observeEvents = session => evaluate(session, "globalThis.__mouiAccessibilityActionEvidence ?? []");
const observeSemantics = session => evaluate(session, "globalThis.__mouiAccessibilitySemanticsEvidence ?? []");
const waitForActionEvent = async (session, nodeId, action, startIndex) => waitFor(
  async () => (await observeEvents(session)).slice(startIndex).find(event =>
    event?.name === "accessibility_action" &&
    `${event.node_id}` === `${nodeId}` &&
    event.action === action,
  ),
  session,
  `${action} receipt for ${nodeId}`,
);

const nativeDomTree = async (session, axNodes) => {
  const nodes = [];
  for (const axNode of axNodes) {
    if (!Number.isInteger(axNode.backendDOMNodeId)) continue;
    try {
      const described = await session.send("DOM.describeNode", {
        backendNodeId: axNode.backendDOMNodeId,
        depth: 0,
      });
      const attributes = attrMap(described.node?.attributes);
      const semanticId = attributes["data-moui-semantic-id"];
      if (!semanticId) continue;
      nodes.push({
        semanticId,
        role: axNode.role?.value ?? "",
        name: axNode.name?.value ?? "",
        value: axNode.value?.value ?? null,
        properties: propertyMap(axNode.properties),
        attributes,
        backendDOMNodeId: axNode.backendDOMNodeId,
      });
    } catch (_) {
      // AX nodes can disappear between tree and DOM queries during a commit.
    }
  }
  return nodes;
};

const collectTree = async session => {
  const tree = await session.send("Accessibility.getFullAXTree");
  return {
    source: "chrome-accessibility-tree",
    nodes: await nativeDomTree(session, tree.nodes ?? []),
    nodeCount: tree.nodes?.length ?? 0,
  };
};

const runAction = async (session, id, action, operation, actions, focusLog) => {
  const beforeState = await pageState(session);
  const nodeId = beforeState.nodeIds[id];
  if (!nodeId) throw new Error(`DOM node id is missing for ${id}`);
  const beforeEvents = await observeEvents(session);
  const startIndex = beforeEvents.length;
  await operation();
  const event = await waitForActionEvent(session, nodeId, action, startIndex);
  const afterState = await pageState(session);
  actions.push({
    id,
    action,
    source: "chrome-cdp",
    result: event.status === "passed" ? "passed" : "failed",
    requestGeneration: event.request_generation ?? beforeState.generation,
    before: event.before ?? "",
    after: event.after ?? "",
    pendingWork: event.pending_work ?? false,
    error: event.error ?? "",
  });
  focusLog.push({
    action,
    id,
    generation: afterState.generation,
    semanticId: afterState.activeSemanticId,
    tag: afterState.activeTag,
  });
  if (event.status !== "passed") throw new Error(`${action} for ${id} was rejected: ${event.error}`);
  return afterState;
};

const key = async (session, keyValue, code = keyValue) => {
  await session.send("Input.dispatchKeyEvent", { type: "keyDown", key: keyValue, code });
  await session.send("Input.dispatchKeyEvent", { type: "keyUp", key: keyValue, code });
};
const focus = session => evaluate(session, "document.activeElement?.blur();");
const focusSemantic = (session, id) => evaluate(session, `document.querySelector(${JSON.stringify(semanticSelector(id))})?.focus()`);
const clickSemantic = (session, id) => evaluate(session, `document.querySelector(${JSON.stringify(semanticSelector(id))})?.click()`);

const main = async () => {
  const common = {
    level: "L2",
    commit: command("git", ["rev-parse", "HEAD"]),
    host: command("uname", ["-n"]),
    os: `${process.platform} ${command("uname", ["-r"])}`,
    architecture: command("uname", ["-m"]),
    window: "showcase/accessibility-probe",
    backend: "web",
    generations: [],
    nativeTree: { source: "chrome-accessibility-tree", requiredIdentifiers: stableIds, missingIdentifiers: [], nodes: [], nodeCount: 0 },
    semanticsCommits: [],
    actions: [],
    keyboardFocus: [],
    accessibilityFocus: [],
    announcements: [],
    environment: {},
    result: "failed",
    failures: [],
    unverifiedCapabilities: ["voiceover", "narrator", "orca"],
  };
  if (!options.baseUrl || !options.cdpUrl) throw new Error("CDP arguments are required");
  let target;
  let session;
  try {
    target = await createPageTarget(options.cdpUrl);
    session = new CdpSession(target.webSocketDebuggerUrl, options.timeoutMs);
    await session.connect();
    for (const domain of ["Page", "Runtime", "DOM", "Accessibility"]) await session.send(`${domain}.enable`);
    await session.send("Page.navigate", {
      url: `${options.baseUrl}/examples/showcase/web_wasm/index.html?section=accessibility-probe&debug=1&observation=${Date.now()}`,
    });
    await waitForIds(session, stableIds.filter(id => id !== "a11y.dialog"));
    const generations = new Set();
    const focusLog = [];
    const semanticsCommits = [];
    const recordSemanticsCommits = async () => {
      const observed = await observeSemantics(session);
      while (semanticsCommits.length < observed.length) {
        const commit = observed[semanticsCommits.length];
        semanticsCommits.push({
          kind: commit.kind,
          generation: `${commit.generation}`,
          root: `${commit.root ?? ""}`,
          focused: `${commit.focused ?? ""}`,
          upsertedNodeIds: (commit.nodes ?? []).map(node => `${node.node_id}`),
          semanticIds: (commit.nodes ?? []).map(node => node.semantic_id).filter(Boolean),
          removedNodeIds: (commit.removed ?? []).map(id => `${id}`),
        });
        generations.add(`${commit.generation}`);
      }
    };
    const initial = await pageState(session);
    await recordSemanticsCommits();
    generations.add(initial.generation);
    const initialTree = await collectTree(session);
    const initialById = new Map(initialTree.nodes.map(node => [node.semanticId, node]));
    for (const id of stableIds.filter(item => item !== "a11y.dialog")) {
      const node = initialById.get(id);
      if (!node) common.failures.push(`AX tree is missing ${id}`);
      else if (expectedRoles.get(id) !== node.role) common.failures.push(`${id} AX role ${node.role} != ${expectedRoles.get(id)}`);
    }
    if (initialById.get("a11y.checkbox")?.properties?.checked !== "true") {
      common.failures.push("AX checkbox did not expose checked=true");
    }
    const sliderAttributes = initialById.get("a11y.slider")?.attributes ?? {};
    for (const [name, expected] of [["aria-valuemin", "0"], ["aria-valuemax", "1"]]) {
      if (sliderAttributes[name] !== expected) common.failures.push(`slider ${name} was not ${expected}`);
    }
    const statusAttributes = initialById.get("a11y.status")?.attributes ?? {};
    const alertAttributes = initialById.get("a11y.alert")?.attributes ?? {};
    if (statusAttributes["aria-live"] !== "polite" || statusAttributes["aria-atomic"] !== "true") common.failures.push("status live attributes are incomplete");
    if (alertAttributes["aria-live"] !== "assertive" || alertAttributes["aria-atomic"] !== "true") common.failures.push("alert live attributes are incomplete");

    await runAction(session, "a11y.button", "activate", () => clickSemantic(session, "a11y.button"), common.actions, focusLog);
    const modalState = await waitForIds(session, ["a11y.dialog"]);
    for (const id of stableIds.filter(item => item !== "a11y.dialog")) {
      if (modalState.ids.includes(id)) common.failures.push(`modal semantics did not isolate background node ${id}`);
    }
    const dialogTree = await collectTree(session);
    const dialog = dialogTree.nodes.find(node => node.semanticId === "a11y.dialog");
    if (!dialog || dialog.role !== "dialog" || dialog.attributes["aria-modal"] !== "true") common.failures.push("opened dialog is missing AX dialog/aria-modal");
    generations.add((await pageState(session)).generation);

    await runAction(session, "a11y.dialog", "dismiss", async () => {
      await focusSemantic(session, "a11y.dialog");
      await key(session, "Escape");
    }, common.actions, focusLog);
    await waitFor(
      async () => !(await pageState(session)).ids.includes("a11y.dialog"),
      session,
      "dialog removal",
    );
    const closedState = await waitForIds(session, stableIds.filter(id => id !== "a11y.dialog"));
    generations.add(closedState.generation);

    await runAction(session, "a11y.checkbox", "activate", () => clickSemantic(session, "a11y.checkbox"), common.actions, focusLog);
    const checkboxTree = await collectTree(session);
    if (checkboxTree.nodes.find(node => node.semanticId === "a11y.checkbox")?.properties?.checked !== "false") common.failures.push("checkbox action did not expose checked=false");
    await runAction(session, "a11y.slider", "increment", async () => { await focusSemantic(session, "a11y.slider"); await key(session, "ArrowRight", "ArrowRight"); }, common.actions, focusLog);
    await runAction(session, "a11y.slider", "decrement", async () => { await focusSemantic(session, "a11y.slider"); await key(session, "ArrowLeft", "ArrowLeft"); }, common.actions, focusLog);
    await runAction(session, "a11y.slider", "set-numeric-value", async () => evaluate(session, `(() => { const node = document.querySelector(${JSON.stringify(semanticSelector("a11y.slider"))}); node.focus(); node.value = "0.7"; node.dispatchEvent(new Event("input", { bubbles: true })); })()`), common.actions, focusLog);
    const sliderAfter = (await collectTree(session)).nodes.find(node => node.semanticId === "a11y.slider");
    if (sliderAfter?.attributes?.["aria-valuenow"] !== "0.7") common.failures.push("slider set numeric value was not reflected in AX DOM attributes");

    await runAction(session, "a11y.textfield", "focus", () => focusSemantic(session, "a11y.textfield"), common.actions, focusLog);
    await runAction(session, "a11y.textfield", "set-text", async () => {
      await evaluate(session, `(() => { const node = document.querySelector(${JSON.stringify(semanticSelector("a11y.textfield"))}); node.focus(); node.value = "agent evidence"; node.dispatchEvent(new Event("input", { bubbles: true })); })()`);
    }, common.actions, focusLog);
    await runAction(session, "a11y.textfield", "set-selection", () => evaluate(session, `(() => { const node = document.querySelector(${JSON.stringify(semanticSelector("a11y.textfield"))}); node.focus(); node.setSelectionRange(0, 5); node.dispatchEvent(new Event("select", { bubbles: true })); })()`), common.actions, focusLog);
    await runAction(session, "a11y.textfield", "submit", async () => { await focusSemantic(session, "a11y.textfield"); await key(session, "Enter"); }, common.actions, focusLog);

    const finalState = await pageState(session);
    await recordSemanticsCommits();
    const finalTree = await collectTree(session);
    common.generations = [...generations, ...common.actions.flatMap(action => [action.requestGeneration, action.before, action.after])]
      .filter(Boolean)
      .filter((value, index, values) => values.indexOf(value) === index)
      .sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1);
    const observedNodes = [...new Map(
      [...initialTree.nodes, ...dialogTree.nodes, ...finalTree.nodes]
        .map(node => [node.semanticId, node]),
    ).values()];
    common.nativeTree = {
      source: "chrome-accessibility-tree",
      requiredIdentifiers: stableIds,
      missingIdentifiers: stableIds.filter(id => !observedNodes.some(node => node.semanticId === id)),
      nodes: observedNodes,
      nodeCount: finalTree.nodeCount,
      modalSubtree: dialogTree.nodes.filter(node => node.semanticId === "a11y.dialog"),
      deletedIdentifiers: ["a11y.dialog"],
    };
    common.semanticsCommits = semanticsCommits;
    common.keyboardFocus = focusLog;
    common.accessibilityFocus = common.actions.map(action => ({ generation: action.after, semanticId: action.id, source: "chrome-accessibility-tree" }));
    common.announcements = [
      { semanticId: "a11y.status", live: "polite", atomic: true, text: finalState.statusText },
      { semanticId: "a11y.alert", live: "assertive", atomic: true, text: finalState.alertText },
    ];
    common.environment = await evaluate(session, `({ textScale: window.devicePixelRatio, accessibilityContrast: window.matchMedia('(prefers-contrast: more)').matches ? 'more' : 'no-preference', reducedMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches })`);
    if (common.nativeTree.missingIdentifiers.length > 0) common.failures.push(`AX tree is missing ${common.nativeTree.missingIdentifiers.join(", ")}`);
    if (common.actions.some(action => action.result !== "passed")) common.failures.push("one or more Chrome actions did not receive a passed runtime receipt");
    if (common.failures.length === 0) common.result = "passed";
  } catch (error) {
    common.failures.push(error.message);
  } finally {
    session?.close();
    if (target) await closePageTarget({ cdpUrl: options.cdpUrl, id: target.id, timeoutMs: 2000, sleep });
  }
  const validation = validateEvidenceManifest(common, probe, false, options.requirePassed);
  common.failures.push(...validation);
  writeManifest(common);
  console.log(`wrote ${options.manifest}`);
  for (const failure of common.failures) console.error(`- ${failure}`);
  if (options.requirePassed && common.failures.length > 0) process.exit(1);
};

main().catch(error => {
  console.error(error.stack || error.message);
  process.exit(1);
});
