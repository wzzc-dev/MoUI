#!/usr/bin/env node

import { readFileSync } from "node:fs";
import {
  connectWindowWeb,
  createWindowWebImports,
  normalizeCanvasWheelDelta,
} from "../moui/backend/web/browser_runtime.js";

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const elementsById = new Map();

class FakeElement {
  constructor(tagName = "div") {
    this.tagName = tagName.toUpperCase();
    this.children = [];
    this.parentElement = null;
    this.style = {};
    this.listeners = new Map();
    this.attributes = new Map();
    this.dataset = {};
    this.id = "";
    this.width = 400;
    this.height = 300;
    this.clientWidth = 400;
    this.clientHeight = 300;
    this.value = "";
    this.textContent = "";
    this.tabIndex = -1;
  }

  appendChild(child) {
    child.parentElement = this;
    this.children.push(child);
    if (child.id) elementsById.set(child.id, child);
    return child;
  }

  remove() {
    if (!this.parentElement) return;
    this.parentElement.children = this.parentElement.children.filter(child => child !== this);
    if (this.id) elementsById.delete(this.id);
    this.parentElement = null;
  }

  contains(target) {
    if (target === this) return true;
    return this.children.some(child => child.contains(target));
  }

  setAttribute(name, value) { this.attributes.set(name, `${value}`); }
  removeAttribute(name) { this.attributes.delete(name); }
  getAttribute(name) { return this.attributes.get(name) ?? null; }

  addEventListener(type, handler, options) {
    const handlers = this.listeners.get(type) ?? [];
    handlers.push({ handler, options });
    this.listeners.set(type, handlers);
  }

  removeEventListener(type, handler) {
    const handlers = this.listeners.get(type) ?? [];
    this.listeners.set(type, handlers.filter(entry => entry.handler !== handler));
  }

  dispatch(type, init = {}) {
    const event = {
      type,
      button: 0,
      buttons: 0,
      pointerId: 1,
      pointerType: "mouse",
      clientX: 0,
      clientY: 0,
      cancelable: true,
      defaultPrevented: false,
      preventDefault() { this.defaultPrevented = true; },
      ...init,
    };
    if (!event.target) event.target = this;
    const path = [];
    for (let current = this; current; current = current.parentElement) path.push(current);
    for (const current of [...path].reverse()) {
      event.currentTarget = current;
      for (const { handler, options } of current.listeners.get(type) ?? []) {
        if (options?.capture) handler(event);
      }
    }
    for (const current of path) {
      event.currentTarget = current;
      for (const { handler, options } of current.listeners.get(type) ?? []) {
        if (!options?.capture) handler(event);
      }
    }
    return event;
  }

  focus() { fakeDocument.activeElement = this; }
  select() {}
  setPointerCapture(pointerId) { this.capturedPointerId = pointerId; }
  releasePointerCapture(pointerId) { this.releasedPointerId = pointerId; }

  getBoundingClientRect() {
    return {
      left: 0,
      top: 0,
      width: this.clientWidth || this.width || 1,
      height: this.clientHeight || this.height || 1,
    };
  }
}

class FakeCanvasElement extends FakeElement {
  constructor() { super("canvas"); }
}

const fakeDocument = {
  body: new FakeElement("body"),
  activeElement: null,
  title: "",
  createElement(tagName) {
    return tagName === "canvas" ? new FakeCanvasElement() : new FakeElement(tagName);
  },
  getElementById(id) { return elementsById.get(id) ?? null; },
  querySelector() { return null; },
  execCommand() { return true; },
};

const windowListeners = new Map();
const fakeWindow = {
  devicePixelRatio: 1,
  innerWidth: 400,
  innerHeight: 300,
  location: new URL("http://example.test/?section=overview"),
  history: { pushState() {}, replaceState() {}, back() {}, forward() {} },
  addEventListener(type, handler) {
    const handlers = windowListeners.get(type) ?? [];
    handlers.push(handler);
    windowListeners.set(type, handlers);
  },
  removeEventListener(type, handler) {
    const handlers = windowListeners.get(type) ?? [];
    windowListeners.set(type, handlers.filter(current => current !== handler));
  },
  matchMedia() { return { matches: false, addEventListener() {}, removeEventListener() {} }; },
};

globalThis.HTMLElement = FakeElement;
globalThis.HTMLCanvasElement = FakeCanvasElement;
globalThis.Node = FakeElement;
globalThis.document = fakeDocument;
globalThis.window = fakeWindow;

const localSettings = new Map();
globalThis.localStorage = {
  getItem(key) { return localSettings.has(key) ? localSettings.get(key) : null; },
  setItem(key, value) { localSettings.set(key, `${value}`); },
  removeItem(key) { localSettings.delete(key); },
};

const webString = (imports, value) => {
  const handle = imports.begin_create_string();
  for (const char of value) {
    imports.string_append_char(handle, char.codePointAt(0));
  }
  return imports.finish_create_string(handle);
};

const readWebString = (imports, handle) => {
  let value = "";
  for (;;) {
    const codePoint = imports.string_read_char(handle);
    if (codePoint < 0) break;
    value += String.fromCodePoint(codePoint);
  }
  imports.finish_read_string(handle);
  return value;
};

const createRuntime = ({ pointerFlags = 1 } = {}) => {
  const imports = createWindowWebImports();
  const events = [];
  imports.set_dispatch_event(() => {});
  imports.set_dispatch_pointer_input((rawId, kind, x, y, deltaX, deltaY, button, modifiers) => {
    const event = { rawId, kind, x, y, deltaX, deltaY, button, modifiers };
    events.push(event);
    return typeof pointerFlags === "function" ? pointerFlags(event) : pointerFlags;
  });
  const canvas = imports.create_canvas("", 400, 300);
  imports.install_canvas_events(7, canvas);
  return { imports, canvas, events };
};

{
  const imports = createWindowWebImports();
  assert(!imports.settings_has_value(webString(imports, "editor/theme")));
  assert(
    imports.settings_write(
      webString(imports, "editor/theme"),
      webString(imports, "dark"),
    ),
  );
  assert(imports.settings_has_value(webString(imports, "editor/theme")));
  assert(
    readWebString(
      imports,
      imports.settings_read(webString(imports, "editor/theme")),
    ) === "dark",
  );
  assert(
    imports.settings_write(
      webString(imports, "editor/empty"),
      webString(imports, ""),
    ),
  );
  assert(imports.settings_has_value(webString(imports, "editor/empty")));
  assert(
    readWebString(
      imports,
      imports.settings_read(webString(imports, "editor/empty")),
    ) === "",
  );
  assert(imports.settings_remove(webString(imports, "editor/theme")));
  assert(!imports.settings_has_value(webString(imports, "editor/theme")));
}

{
  const imports = createWindowWebImports();
  let legacyCalls = 0;
  let pointerCalls = 0;
  connectWindowWeb({
    exports: {
      web_dispatch_event() { legacyCalls += 1; },
      web_dispatch_pointer_input() { pointerCalls += 1; return 1; },
    },
  }, imports);
  const canvas = imports.create_canvas("", 400, 300);
  imports.install_canvas_events(9, canvas);
  canvas.dispatch("pointerdown", { clientX: 6, clientY: 7 });
  assert(pointerCalls === 1 && legacyCalls === 0, "connectWindowWeb must install the direct pointer ABI");
}

{
  const { canvas, events } = createRuntime({ pointerFlags: event => event.kind === 24 ? 5 : 3 });
  const down = canvas.dispatch("pointerdown", {
    clientX: 12.5,
    clientY: 18.25,
    button: 2,
    pointerId: 42,
    ctrlKey: true,
    altKey: true,
  });
  const up = canvas.dispatch("pointerup", { clientX: 12.5, clientY: 18.25, button: 2, pointerId: 42 });
  assert(down.defaultPrevented && up.defaultPrevented, "handled pointer input must prevent browser defaults");
  assert(canvas.capturedPointerId === 42 && canvas.releasedPointerId === 42, "wasm flags must drive real pointer capture");
  assert(
    JSON.stringify(events[0]) === JSON.stringify({ rawId: 7, kind: 23, x: 12.5, y: 18.25, deltaX: 0, deltaY: 0, button: 2, modifiers: 6 }),
    "pointer ABI must contain only runtime-consumed fields",
  );
}

{
  const imports = createWindowWebImports();
  let canvas;
  const pointerFocus = [];
  imports.set_dispatch_event(() => {});
  imports.set_dispatch_pointer_input((_rawId, kind) => {
    pointerFocus.push({ kind, focused: fakeDocument.activeElement === canvas });
    return 3;
  });
  canvas = imports.create_canvas("", 400, 300);
  imports.install_canvas_events(8, canvas);
  canvas.dispatch("pointerdown", { clientX: 10, clientY: 12 });
  assert(
    JSON.stringify(pointerFocus) === JSON.stringify([{ kind: 23, focused: true }]),
    "pointer down must establish canvas-host focus before calling wasm",
  );
}

{
  const imports = createWindowWebImports();
  const legacyEvents = [];
  imports.set_dispatch_event(kind => legacyEvents.push(kind));
  imports.set_dispatch_pointer_input(() => 3);
  const canvas = imports.create_canvas("", 400, 300);
  imports.install_canvas_events(10, canvas);
  const semanticsTarget = new FakeElement("a");
  canvas.parentElement.appendChild(semanticsTarget);
  canvas.dispatch("pointerdown", { clientX: 10, clientY: 12 });
  canvas.dispatch("blur", { relatedTarget: semanticsTarget });
  await Promise.resolve();
  assert(
    !legacyEvents.includes(12),
    "focus moving into the semantics layer must not cancel a canvas pointer",
  );
}

{
  const previousDpr = fakeWindow.devicePixelRatio;
  fakeWindow.devicePixelRatio = 2;
  try {
    const { canvas, events } = createRuntime();
    canvas.dispatch("pointerdown", { clientX: 120, clientY: 220 });
    canvas.dispatch("wheel", { clientX: 120, clientY: 220, deltaX: 2, deltaY: -3, deltaMode: 1 });
    assert(events[0].x === 240 && events[0].y === 440, "coordinates must use physical canvas pixels");
    assert(events[1].deltaX === 64 && events[1].deltaY === 96, "wheel deltas must normalize and scale once");
  } finally {
    fakeWindow.devicePixelRatio = previousDpr;
  }
}

{
  const previousDpr = fakeWindow.devicePixelRatio;
  fakeWindow.devicePixelRatio = 2;
  try {
    const { imports, canvas } = createRuntime();
    const resizeEvents = [];
    imports.set_dispatch_event((kind, rawId, width, height, scaleFactor) => {
      resizeEvents.push({ kind, rawId, width, height, scaleFactor });
    });
    const resize = windowListeners.get("resize").at(-1);
    resize?.();
    assert(
      JSON.stringify(resizeEvents) === JSON.stringify([
        { kind: 10, rawId: 7, width: 800, height: 600, scaleFactor: 2 },
      ]),
      "resize events must provide the DPR used to map physical pointer coordinates",
    );
    assert(canvas.width === 800 && canvas.height === 600, "resize must preserve physical canvas dimensions");
  } finally {
    fakeWindow.devicePixelRatio = previousDpr;
  }
}

{
  const { canvas, events } = createRuntime();
  canvas.dispatch("pointerdown", { pointerType: "touch", pointerId: 3, clientX: 120, clientY: 220 });
  const move = canvas.dispatch("pointermove", { pointerType: "touch", pointerId: 3, clientX: 112, clientY: 160 });
  canvas.dispatch("pointerup", { pointerType: "touch", pointerId: 3, clientX: 112, clientY: 160 });
  assert(events.map(event => event.kind).join(",") === "23,30,24", "touch drag must enter MoUI once per native pointer event");
  assert(events[1].deltaX === 8 && events[1].deltaY === 60 && move.defaultPrevented, "handled touch scroll must use direct physical deltas");
}

{
  const { imports, canvas, events } = createRuntime();
  const semanticsNode = {
    node_id: "12",
    role: "link",
    label: "Docs",
    value: "",
    description: "",
    url: "#docs",
    level: 0,
    checked: false,
    selected: false,
    expanded: false,
    invalid: false,
    required: false,
    disabled: false,
    focused: false,
    actions: ["focus", "activate"],
    frame: { origin: { x: 10, y: 10 }, size: { width: 100, height: 24 } },
    children: [],
  };
  const semantics = {
    kind: "full",
    generation: "1",
    root: "12",
    focused: null,
    nodes: [semanticsNode],
    removed: [],
  };
  imports.sync_semantics(7, imports.register_host_string(canvas.id), imports.register_host_string(JSON.stringify(semantics)));
  assert(
    globalThis.__mouiAccessibilitySemanticsEvidence.at(-1)?.generation === "1",
    "Web semantics commits must be observable by the browser L2 recorder",
  );
  const layer = canvas.parentElement.children.find(child => child.className === "moui-semantics-layer");
  const link = layer.children[0];
  link.dispatch("pointerdown", { clientX: 20, clientY: 20 });
  link.dispatch("pointerup", { clientX: 20, clientY: 20 });
  link.dispatch("click", { detail: 1, clientX: 20, clientY: 20 });
  const wheel = link.dispatch("wheel", { clientX: 20, clientY: 20, deltaY: 10 });
  assert(events.map(event => event.kind).join(",") === "23,24,30", "semantic overlay input must use the host router exactly once");
  assert(wheel.defaultPrevented, "handled semantic wheel must use the runtime default-action policy");
  assert(!layer.listeners.has("pointermove") && !layer.listeners.has("wheel"), "semantic layers must not forward synthetic input");
}

{
  const observed = [];
  const imports = createWindowWebImports({ onEvent: event => observed.push(event) });
  imports.record_semantics_action(7, imports.register_host_string(JSON.stringify({
    node_id: "12",
    request_generation: "41",
    action: "activate",
    status: "passed",
    before: "41",
    after: "42",
    pending_work: true,
    error: "",
  })));
  assert(
    observed.length === 1 &&
      observed[0].name === "accessibility_action" &&
      observed[0].source === "runtime-receipt" &&
      observed[0].rawId === 7 &&
      observed[0].before === "41" &&
      observed[0].after === "42",
    "Web semantics action evidence must preserve the exact runtime receipt",
  );
  assert(
    globalThis.__mouiAccessibilityActionEvidence.at(-1)?.node_id === "12",
    "Web semantics action receipts must be available to the browser L2 recorder",
  );
}

{
  const { canvas, events } = createRuntime();
  const nativeInput = new FakeElement("textarea");
  nativeInput.setAttribute("data-moui-native-input", "true");
  canvas.parentElement.appendChild(nativeInput);
  nativeInput.dispatch("pointerdown", { clientX: 8, clientY: 9 });
  nativeInput.dispatch("wheel", { deltaX: 1, deltaY: 1 });
  assert(events.length === 0, "marked native controls must bypass canvas routing");
}

{
  const { canvas, events } = createRuntime({ pointerFlags: 0 });
  const down = canvas.dispatch("pointerdown", { clientX: 20, clientY: 30 });
  const wheel = canvas.dispatch("wheel", { deltaX: 3, deltaY: -4 });
  const zoom = canvas.dispatch("wheel", { deltaX: 3, deltaY: -4, ctrlKey: true });
  canvas.dispatch("mousedown", { clientX: 20, clientY: 30 });
  assert(
    !down.defaultPrevented && !wheel.defaultPrevented && !zoom.defaultPrevented,
    `unhandled input and browser zoom must keep defaults: ${JSON.stringify({ down: down.defaultPrevented, wheel: wheel.defaultPrevented, zoom: zoom.defaultPrevented })}`,
  );
  assert(events.length === 2, "mouse fallback events must not form a second input path");
}

assert(
  JSON.stringify(normalizeCanvasWheelDelta({ deltaX: 1, deltaY: 2, deltaMode: 2 }, { pageHeight: 300 })) === JSON.stringify({ x: 300, y: -600 }),
  "page wheel normalization is incorrect",
);

const browserSource = readFileSync(new URL("../moui/backend/web/browser_runtime.js", import.meta.url), "utf8");
const rendererSource = readFileSync(new URL("../moui_web_renderer/runtime.js", import.meta.url), "utf8");
assert(!/dispatchEvent\(new (?:PointerEvent|MouseEvent|WheelEvent)/.test(browserSource), "browser input router must not synthesize DOM input");
assert(!/dispatchEvent\(new (?:PointerEvent|MouseEvent|WheelEvent)/.test(rendererSource), "renderer overlays must not synthesize DOM input");

console.log("browser runtime input router tests: ok");
