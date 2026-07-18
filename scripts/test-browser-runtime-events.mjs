#!/usr/bin/env node

import {
  connectWindowWeb,
  createWindowWebImports,
} from "../moui/backend/web/browser_runtime.js";

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

  getAttribute(name) {
    return this.attributes.get(name) ?? null;
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
    if (!event.target) event.target = this;
    const path = [];
    for (let current = this; current; current = current.parentElement) {
      path.push(current);
    }
    for (const current of [...path].reverse()) {
      for (const { handler, options } of current.listeners.get(type) ?? []) {
        if (options?.capture) handler(event);
      }
    }
    for (const current of path) {
      for (const { handler, options } of current.listeners.get(type) ?? []) {
        if (!options?.capture) handler(event);
      }
    }
    return event;
  }

  focus() {
    fakeDocument.activeElement = this;
  }

  select() {}

  setPointerCapture(pointerId) {
    this.capturedPointerId = pointerId;
  }

  releasePointerCapture(pointerId) {
    this.releasedPointerId = pointerId;
  }

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

const windowListeners = new Map();
let historyStack = [];
let historyIndex = 0;

const fakeWindowLocation = href => {
  const url = new URL(href, "http://example.test/showcase/");
  return {
    href: url.href,
    search: url.search,
    hash: url.hash,
    pathname: url.pathname,
  };
};

const setWindowHref = href => {
  fakeWindow.location = fakeWindowLocation(href);
};

const dispatchWindowEvent = (type, init = {}) => {
  const event = { type, ...init };
  for (const handler of windowListeners.get(type) ?? []) {
    handler(event);
  }
};

const resetHistory = (href = "http://example.test/showcase/?debug=1&section=advanced-rendering") => {
  historyStack = [href];
  historyIndex = 0;
  setWindowHref(href);
};

const fakeWindow = {
  devicePixelRatio: 1,
  innerWidth: 400,
  innerHeight: 300,
  location: fakeWindowLocation(
    "http://example.test/showcase/?debug=1&section=advanced-rendering",
  ),
  history: {
    pushState(_state, _title, url) {
      historyStack = historyStack.slice(0, historyIndex + 1);
      historyStack.push(url.href ?? `${url}`);
      historyIndex = historyStack.length - 1;
      setWindowHref(historyStack[historyIndex]);
    },
    replaceState(_state, _title, url) {
      historyStack[historyIndex] = url.href ?? `${url}`;
      setWindowHref(historyStack[historyIndex]);
    },
    back() {
      if (historyIndex <= 0) return;
      historyIndex -= 1;
      setWindowHref(historyStack[historyIndex]);
      dispatchWindowEvent("popstate");
    },
    forward() {
      if (historyIndex + 1 >= historyStack.length) return;
      historyIndex += 1;
      setWindowHref(historyStack[historyIndex]);
      dispatchWindowEvent("popstate");
    },
  },
  addEventListener(type, handler) {
    const handlers = windowListeners.get(type) ?? [];
    handlers.push(handler);
    windowListeners.set(type, handlers);
  },
  removeEventListener(type, handler) {
    const handlers = windowListeners.get(type) ?? [];
    windowListeners.set(
      type,
      handlers.filter(current => current !== handler),
    );
  },
  matchMedia() {
    return { matches: false, addEventListener() {}, removeEventListener() {} };
  },
};

globalThis.HTMLElement = FakeElement;
globalThis.HTMLCanvasElement = FakeCanvasElement;
globalThis.document = fakeDocument;
globalThis.window = fakeWindow;
resetHistory();

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

const createRuntime = ({ pointerFlags = 1 } = {}) => {
  const imports = createWindowWebImports();
  const events = [];
  imports.set_dispatch_event((kind, rawId, arg0, arg1, argd) => {
    events.push({ kind, rawId, arg0, arg1, argd });
  });
  imports.set_dispatch_pointer_input((
    rawId,
    kind,
    x,
    y,
    deltaX,
    deltaY,
    button,
    buttons,
    pointerId,
    pointerKind,
    modifiers,
  ) => {
    events.push({
      kind,
      rawId,
      arg0: kind === 30 ? deltaX : x,
      arg1: kind === 30 ? deltaY : y,
      argd: button,
      buttons,
      pointerId,
      pointerKind,
      modifiers,
    });
    return typeof pointerFlags === "function"
      ? pointerFlags({ kind, rawId, x, y, deltaX, deltaY, button, buttons, pointerId, pointerKind, modifiers })
      : pointerFlags;
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
    const imports = createWindowWebImports();
    let legacyCalls = 0;
    let pointerCalls = 0;
    connectWindowWeb({
      exports: {
        web_dispatch_event() {
          legacyCalls += 1;
        },
        web_dispatch_pointer_input() {
          pointerCalls += 1;
          return 1;
        },
      },
    }, imports);
    const canvas = imports.create_canvas("", 400, 300);
    imports.install_canvas_events(9, canvas);
    canvas.dispatch("pointerdown", { clientX: 6, clientY: 7 });
    if (pointerCalls !== 1 || legacyCalls !== 0) {
      throw new Error("connectWindowWeb must install the direct pointer ABI");
    }
  });
});

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
    const { canvas, events } = createRuntime({ pointerFlags: 5 });
    canvas.dispatch("pointerdown", { clientX: 9, clientY: 10, pointerId: 7 });
    const cancel = canvas.dispatch("pointercancel", { clientX: 9, clientY: 10, pointerId: 7 });
    if (!cancel.defaultPrevented || canvas.releasedPointerId !== 7) {
      throw new Error("handled pointer cancellation must prevent default and release capture");
    }
    expectKinds("pointer cancellation uses the direct pointer ABI", events, [23, 25]);
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

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const previousDpr = fakeWindow.devicePixelRatio;
    fakeWindow.devicePixelRatio = 2;
    try {
      const { canvas, events } = createRuntime();
      canvas.dispatch("pointerdown", { clientX: 120, clientY: 220 });
      canvas.dispatch("pointerup", { clientX: 120, clientY: 220 });
      expectKinds("high-DPI pointer activation", events, [23, 24]);
      if (events[0].arg0 !== 240 || events[0].arg1 !== 440) {
        console.error("high-DPI pointer coordinates must be emitted in physical canvas pixels");
        console.error(JSON.stringify(events, null, 2));
        process.exit(1);
      }
    } finally {
      fakeWindow.devicePixelRatio = previousDpr;
    }
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

const touch = (identifier, clientX, clientY) => ({
  identifier,
  clientX,
  clientY,
});

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const { canvas, events } = createRuntime();
    const start = touch(1, 120, 220);
    const move = touch(1, 112, 160);
    canvas.dispatch("touchstart", {
      touches: [start],
      changedTouches: [start],
    });
    const touchMove = canvas.dispatch("touchmove", {
      touches: [move],
      changedTouches: [move],
    });
    canvas.dispatch("touchend", {
      touches: [],
      changedTouches: [move],
    });
    expectKinds(
      "touch drag synthesizes pointer position and wheel scrolling",
      events,
      [21, 30],
    );
    if (events[1].arg0 !== 8 || events[1].arg1 !== 60) {
      console.error("touch scroll delta should match browser wheel direction");
      console.error(JSON.stringify(events, null, 2));
      process.exit(1);
    }
    if (!touchMove.defaultPrevented) {
      console.error("touch scroll should prevent the browser fallback pan");
      process.exit(1);
    }
  });
});

withMockClock(() => {
  withPointerEventSupport(false, () => {
    const { canvas, events } = createRuntime();
    const start = touch(2, 80, 120);
    const move = touch(2, 80, 90);
    canvas.dispatch("touchstart", {
      touches: [start],
      changedTouches: [start],
    });
    canvas.dispatch("touchmove", {
      touches: [move],
      changedTouches: [move],
    });
    canvas.dispatch("touchend", {
      touches: [],
      changedTouches: [move],
    });
    canvas.dispatch("mousedown", { clientX: 80, clientY: 120 });
    canvas.dispatch("mouseup", { clientX: 80, clientY: 90 });
    canvas.dispatch("click", { clientX: 80, clientY: 90 });
    expectKinds(
      "touch fallback keeps pointer activation and scroll without PointerEvent",
      events,
      [23, 21, 30, 24],
    );
  });
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

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const { canvas, events } = createRuntime({
      pointerFlags: event => event.kind === 24 ? 5 : 3,
    });
    const down = canvas.dispatch("pointerdown", {
      clientX: 12.5,
      clientY: 18.25,
      button: 2,
      buttons: 2,
      pointerId: 42,
      pointerType: "pen",
      ctrlKey: true,
      altKey: true,
    });
    const up = canvas.dispatch("pointerup", {
      clientX: 12.5,
      clientY: 18.25,
      button: 2,
      pointerId: 42,
      pointerType: "pen",
    });
    if (!down.defaultPrevented || !up.defaultPrevented) {
      throw new Error("handled pointer events must prevent browser defaults");
    }
    if (canvas.capturedPointerId !== 42 || canvas.releasedPointerId !== 42) {
      throw new Error("wasm pointer capture flags must control native capture");
    }
    const pointer = events[0];
    if (
      pointer.arg0 !== 12.5 || pointer.arg1 !== 18.25 || pointer.argd !== 2 ||
      pointer.buttons !== 2 ||
      pointer.pointerId !== 42 || pointer.pointerKind !== 2 || pointer.modifiers !== 6
    ) {
      throw new Error(`pointer ABI lost physical coordinates or metadata: ${JSON.stringify(pointer)}`);
    }
  });
});

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const { canvas, events } = createRuntime({ pointerFlags: 0 });
    const down = canvas.dispatch("pointerdown", { clientX: 20, clientY: 30 });
    const wheel = canvas.dispatch("wheel", { deltaX: 3, deltaY: -4 });
    const zoom = canvas.dispatch("wheel", { deltaX: 3, deltaY: -4, ctrlKey: true });
    if (down.defaultPrevented || wheel.defaultPrevented) {
      throw new Error("unhandled canvas input must retain native browser behavior");
    }
    if (events.length !== 2 || zoom.defaultPrevented) {
      throw new Error("Ctrl/Meta wheel must remain available to browser zoom");
    }
  });
});

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const previousDpr = fakeWindow.devicePixelRatio;
    fakeWindow.devicePixelRatio = 2;
    try {
      const { canvas, events } = createRuntime();
      canvas.dispatch("wheel", { deltaX: 2, deltaY: -3, deltaMode: 1 });
      canvas.dispatch("wheel", { deltaX: 0, deltaY: -1, deltaMode: 2 });
      if (
        events[0].arg0 !== 64 || events[0].arg1 !== 96 ||
        events[1].arg0 !== 0 || events[1].arg1 !== 600
      ) {
        throw new Error(`line wheel deltas must be normalized and scaled: ${JSON.stringify(events[0])}`);
      }
    } finally {
      fakeWindow.devicePixelRatio = previousDpr;
    }
  });
});

withMockClock(() => {
  withPointerEventSupport(true, () => {
    const { canvas, events } = createRuntime();
    const nativeInput = new FakeTextAreaElement();
    nativeInput.setAttribute("data-moui-native-input", "true");
    canvas.parentElement.appendChild(nativeInput);
    nativeInput.dispatch("pointerdown", { clientX: 8, clientY: 9 });
    nativeInput.dispatch("wheel", { deltaX: 1, deltaY: 1 });
    if (events.length !== 0) {
      throw new Error("native input descendants must bypass the canvas input router");
    }
  });
});

const readEventString = (imports, id) => {
  const handle = imports.begin_read_string(id);
  let value = "";
  while (true) {
    const codePoint = imports.string_read_char(handle);
    if (codePoint === -1) break;
    value += String.fromCodePoint(codePoint);
  }
  imports.finish_read_string(handle);
  return value;
};

resetHistory();
const routeImports = createWindowWebImports();
const routeEvents = [];
routeImports.set_route_dispatch((source, textId) => {
  routeEvents.push({
    source,
    route: readEventString(routeImports, textId),
    href: window.location.href,
  });
});
routeImports.history_dispatch_current(0);
routeImports.history_push_route(
  routeImports.register_host_string("navigation?panel=history"),
);
routeImports.history_replace_route(routeImports.register_host_string("forms"));
routeImports.history_back();

const expectedRouteEvents = [
  { source: 0, route: "advanced-rendering" },
  { source: 2, route: "navigation?panel=history" },
  { source: 3, route: "forms" },
  { source: 1, route: "advanced-rendering" },
];
for (let index = 0; index < expectedRouteEvents.length; index += 1) {
  const expected = expectedRouteEvents[index];
  const actual = routeEvents[index];
  if (!actual || actual.source !== expected.source || actual.route !== expected.route) {
    console.error("browser history route bridge emitted unexpected events");
    console.error(JSON.stringify(routeEvents, null, 2));
    process.exit(1);
  }
}
if (!routeEvents[2].href.includes("debug=1") || !routeEvents[2].href.includes("section=forms")) {
  console.error("browser history route bridge should preserve debug and section URL state");
  console.error(JSON.stringify(routeEvents, null, 2));
  process.exit(1);
}

const stringImports = createWindowWebImports();
const titleHandle = stringImports.begin_create_string();
for (const ch of "Transient title") {
  stringImports.string_append_char(titleHandle, ch.codePointAt(0));
}
const finishedTitleHandle = stringImports.finish_create_string(titleHandle);
stringImports.set_document_title(finishedTitleHandle);
if (fakeDocument.title !== "Transient title") {
  console.error("browser runtime should resolve outbound string handles");
  process.exit(1);
}
stringImports.set_document_title(finishedTitleHandle);
if (fakeDocument.title !== "") {
  console.error("browser runtime should consume outbound string handles once");
  process.exit(1);
}

console.log("browser runtime event fallback tests: ok");
