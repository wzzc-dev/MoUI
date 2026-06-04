#!/usr/bin/env node

import { createWindowWebImports } from "../moui/backend/web/browser_runtime.js";

const elementsById = new Map();

class FakeElement {
  constructor(tagName = "div") {
    this.tagName = tagName.toUpperCase();
    this.children = [];
    this.parentElement = null;
    this.style = {};
    this.listeners = new Map();
    this.attributes = new Map();
    this.id = "";
    this.width = 400;
    this.height = 300;
    this.clientWidth = 400;
    this.clientHeight = 300;
    this.value = "";
  }

  appendChild(child) {
    child.parentElement = this;
    this.children.push(child);
    if (child.id) {
      elementsById.set(child.id, child);
    }
    return child;
  }

  remove() {
    if (!this.parentElement) return;
    this.parentElement.children = this.parentElement.children.filter(
      child => child !== this,
    );
    if (this.id) {
      elementsById.delete(this.id);
    }
    this.parentElement = null;
  }

  setAttribute(name, value) {
    this.attributes.set(name, `${value}`);
  }

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
      preventDefault() {
        this.defaultPrevented = true;
      },
      ...init,
    };
    for (const { handler } of this.listeners.get(type) ?? []) {
      handler(event);
    }
    return event;
  }

  focus() {
    fakeDocument.activeElement = this;
  }

  select() {}

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
  constructor() {
    super("canvas");
  }
}

class FakeTextAreaElement extends FakeElement {
  constructor() {
    super("textarea");
  }
}

const fakeDocument = {
  body: new FakeElement("body"),
  activeElement: null,
  title: "",
  createElement(tagName) {
    return tagName === "canvas"
      ? new FakeCanvasElement()
      : new FakeTextAreaElement();
  },
  getElementById(id) {
    return elementsById.get(id) ?? null;
  },
  querySelector() {
    return null;
  },
  execCommand() {
    return true;
  },
};

globalThis.HTMLElement = FakeElement;
globalThis.HTMLCanvasElement = FakeCanvasElement;
globalThis.document = fakeDocument;
globalThis.window = {
  devicePixelRatio: 1,
  innerWidth: 400,
  innerHeight: 300,
  addEventListener() {},
  removeEventListener() {},
  matchMedia() {
    return { matches: false, addEventListener() {}, removeEventListener() {} };
  },
};

const withMockClock = callback => {
  const originalNow = Date.now;
  let now = 1000;
  Date.now = () => now;
  try {
    callback(delta => {
      now += delta;
    });
  } finally {
    Date.now = originalNow;
  }
};

const withPointerEventSupport = (supported, callback) => {
  const hadPointerEvent = Object.hasOwn(globalThis, "PointerEvent");
  const originalPointerEvent = globalThis.PointerEvent;
  if (supported) {
    globalThis.PointerEvent = function PointerEvent() {};
  } else {
    delete globalThis.PointerEvent;
  }
  try {
    callback();
  } finally {
    if (hadPointerEvent) {
      globalThis.PointerEvent = originalPointerEvent;
    } else {
      delete globalThis.PointerEvent;
    }
  }
};

const createRuntime = () => {
  const imports = createWindowWebImports();
  const events = [];
  imports.set_dispatch_event((kind, rawId, arg0, arg1, argd) => {
    events.push({ kind, rawId, arg0, arg1, argd });
  });
  const canvas = imports.create_canvas("", 400, 300);
  imports.install_canvas_events(7, canvas);
  return { canvas, events };
};

const expectKinds = (label, events, expected) => {
  const actual = events.map(event => event.kind);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    console.error(`${label}: expected event kinds ${expected.join(", ")}`);
    console.error(`actual: ${actual.join(", ")}`);
    process.exit(1);
  }
};

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const { canvas, events } = createRuntime();
    canvas.dispatch("mousedown", { clientX: 12, clientY: 18 });
    canvas.dispatch("mouseup", { clientX: 12, clientY: 18 });
    canvas.dispatch("click", { clientX: 12, clientY: 18 });
    expectKinds(
      "pointer-capable browsers ignore mouse/click fallback activation",
      events,
      [],
    );
  });
});

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const { canvas, events } = createRuntime();
    canvas.dispatch("pointerdown", { clientX: 24, clientY: 30 });
    canvas.dispatch("mousedown", { clientX: 24, clientY: 30 });
    canvas.dispatch("pointerup", { clientX: 24, clientY: 30 });
    canvas.dispatch("mouseup", { clientX: 24, clientY: 30 });
    canvas.dispatch("click", { clientX: 24, clientY: 30 });
    expectKinds(
      "pointer-capable browsers keep pointer events authoritative",
      events,
      [23, 24],
    );
  });
});

withMockClock(tick => {
  const { canvas, events } = createRuntime();
  canvas.dispatch("pointerdown", { clientX: 32, clientY: 44 });
  tick(400);
  canvas.dispatch("mousedown", { clientX: 32, clientY: 44 });
  canvas.dispatch("pointerup", { clientX: 32, clientY: 44 });
  tick(400);
  canvas.dispatch("mouseup", { clientX: 32, clientY: 44 });
  canvas.dispatch("click", { clientX: 32, clientY: 44 });
  expectKinds(
    "pointer events suppress delayed mouse/click fallbacks",
    events,
    [23, 24],
  );
});

withMockClock(tick => {
  const { canvas, events } = createRuntime();
  canvas.dispatch("pointerdown", { clientX: 34, clientY: 46 });
  canvas.dispatch("pointerup", { clientX: 34, clientY: 46 });
  tick(1200);
  canvas.dispatch("click", { clientX: 36, clientY: 48 });
  expectKinds(
    "pointer release suppresses delayed drifted click fallback",
    events,
    [23, 24],
  );
});

withMockClock(tick => {
  const { canvas, events } = createRuntime();
  canvas.dispatch("pointermove", { clientX: 12, clientY: 18 });
  tick(1200);
  canvas.dispatch("mousemove", { clientX: 13, clientY: 19 });
  expectKinds(
    "pointer movement suppresses delayed drifted mouse fallback",
    events,
    [21],
  );
});

withMockClock(tick => {
  const { canvas, events } = createRuntime();
  canvas.dispatch("mousedown", { clientX: 52, clientY: 64 });
  canvas.dispatch("mouseup", { clientX: 52, clientY: 64 });
  tick(400);
  canvas.dispatch("click", { clientX: 52, clientY: 64 });
  expectKinds("mouse events suppress delayed click fallback", events, [23, 24]);
});

withMockClock(() => {
  const { canvas, events } = createRuntime();
  canvas.dispatch("click", { clientX: 72, clientY: 84 });
  expectKinds(
    "click fallback still emits without prior button events",
    events,
    [23, 24],
  );
});

console.log("browser runtime event fallback tests: ok");
