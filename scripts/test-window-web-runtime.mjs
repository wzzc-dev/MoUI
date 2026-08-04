#!/usr/bin/env node

import { createWindowWebImports } from "../window/modules/window/web/runtime.js";

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

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
    return child;
  }

  remove() {
    if (!this.parentElement) return;
    this.parentElement.children = this.parentElement.children.filter(
      child => child !== this,
    );
    this.parentElement = null;
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
    this.listeners.set(
      type,
      handlers.filter(entry => entry.handler !== handler),
    );
  }

  dispatch(type, init = {}) {
    const event = {
      type,
      button: 0,
      clientX: 0,
      clientY: 0,
      cancelable: true,
      defaultPrevented: false,
      preventDefault() { this.defaultPrevented = true; },
      ...init,
    };
    if (!event.target) event.target = this;
    const path = [];
    for (let current = this; current; current = current.parentElement) {
      path.push(current);
    }
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

  getBoundingClientRect() {
    return {
      left: 0,
      top: 0,
      width: this.clientWidth || 1,
      height: this.clientHeight || 1,
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
  getElementById() { return null; },
};

const fakeWindow = {
  devicePixelRatio: 1,
  addEventListener() {},
  removeEventListener() {},
  matchMedia() { return { matches: false, addEventListener() {}, removeEventListener() {} }; },
};

let computedLineHeight = "16px";
globalThis.HTMLElement = FakeElement;
globalThis.HTMLCanvasElement = FakeCanvasElement;
globalThis.document = fakeDocument;
globalThis.window = fakeWindow;
globalThis.getComputedStyle = () => ({ lineHeight: computedLineHeight });

const createRuntime = () => {
  const imports = createWindowWebImports();
  const events = [];
  imports.set_dispatch_event((kind, rawId, arg0, arg1) => {
    events.push({ kind, rawId, arg0, arg1 });
  });
  const canvas = imports.create_canvas("", 400, 300);
  imports.install_canvas_events(7, canvas);
  return { imports, canvas, events };
};

// DOM reports positive deltaY for downward scroll; the window library
// convention is positive for upward scroll, so the runtime must invert Y.
{
  const { canvas, events } = createRuntime();
  canvas.dispatch("wheel", { deltaX: 2, deltaY: 3 });
  assert(events.length === 1, "wheel event must be emitted");
  assert(
    JSON.stringify(events[0]) === JSON.stringify({ kind: 30, rawId: 7, arg0: 2, arg1: -3 }),
    `wheel deltaY must be inverted for the library convention: ${JSON.stringify(events[0])}`,
  );
}

{
  const { canvas, events } = createRuntime();
  canvas.dispatch("wheel", { deltaX: 0, deltaY: -120 });
  assert(events[0].arg1 === 120, "wheel up (negative DOM deltaY) must become positive");
  assert(events[0].arg0 === 0, "wheel X must stay unchanged");
}

// deltaMode=1 (line) must expand by line height, matching the MoUI web backend.
{
  const previousLineHeight = computedLineHeight;
  computedLineHeight = "16px";
  try {
    const { canvas, events } = createRuntime();
    canvas.dispatch("wheel", { deltaX: 0, deltaY: -2, deltaMode: 1 });
    assert(events[0].arg1 === 32, "line-mode wheel delta must scale by line height");
  } finally {
    computedLineHeight = previousLineHeight;
  }
}

// deltaMode=2 (page) must expand by the host page height.
{
  const previousPageHeight = fakeDocument.body.clientHeight;
  fakeDocument.body.clientHeight = 300;
  try {
    const { canvas, events } = createRuntime();
    canvas.dispatch("wheel", { deltaX: 0, deltaY: 1, deltaMode: 2 });
    assert(events[0].arg1 === -300, "page-mode wheel delta must scale by page height");
  } finally {
    fakeDocument.body.clientHeight = previousPageHeight;
  }
}

// Horizontal deltas must not be inverted (DOM and library conventions agree).
{
  const { canvas, events } = createRuntime();
  canvas.dispatch("wheel", { deltaX: 5, deltaY: 0 });
  assert(events[0].arg0 === 5 && events[0].arg1 === 0, "horizontal wheel delta must stay positive");
}

console.log("window web runtime wheel tests: ok");
