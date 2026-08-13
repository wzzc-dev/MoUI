#!/usr/bin/env node

import {
  createSemanticsDomManager,
  updateDocumentMetadata,
} from "../moui/backend/web/browser_runtime.js";

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

class FakeElement {
  constructor(tagName, ownerDocument) {
    this.tagName = tagName.toUpperCase();
    this.ownerDocument = ownerDocument;
    this.styleWrites = 0;
    this.style = new Proxy({}, {
      set: (target, name, value) => {
        this.styleWrites += 1;
        target[name] = value;
        return true;
      },
    });
    this.dataset = {};
    this.attributes = new Map();
    this.children = [];
    this.parentElement = null;
    this.listeners = new Map();
    this.textWrites = 0;
    let textContent = "";
    Object.defineProperty(this, "textContent", {
      get: () => textContent,
      set: value => {
        this.textWrites += 1;
        textContent = `${value ?? ""}`;
      },
    });
    this.value = "";
    this.tabIndex = -1;
  }
  appendChild(child) {
    child.remove();
    this.children.push(child);
    child.parentElement = this;
    return child;
  }
  remove() {
    if (!this.parentElement) return;
    this.parentElement.children = this.parentElement.children.filter(child => child !== this);
    this.parentElement = null;
  }
  setAttribute(name, value) { this.attributes.set(name, `${value}`); }
  removeAttribute(name) { this.attributes.delete(name); }
  getAttribute(name) { return this.attributes.get(name) ?? null; }
  addEventListener(name, handler) {
    const handlers = this.listeners.get(name) ?? [];
    handlers.push(handler);
    this.listeners.set(name, handlers);
  }
  dispatch(name, extra = {}) {
    const event = {
      key: "",
      currentTarget: this,
      preventDefault() {},
      stopPropagation() {},
      ...extra,
    };
    for (const handler of this.listeners.get(name) ?? []) handler(event);
  }
  dispatchEvent(event) {
    this.dispatch(event.type, event);
    return true;
  }
  focus() {
    this.ownerDocument.activeElement = this;
    this.dispatch("focus");
  }
}

class FakeHead extends FakeElement {
  querySelector(selector) {
    const match = selector.match(/^(meta|link)\[(name|property|rel)="([^"]+)"\]$/);
    if (!match) return null;
    return this.children.find(child =>
      child.tagName.toLowerCase() === match[1] && child.getAttribute(match[2]) === match[3]) ?? null;
  }
}

class FakeDocument {
  constructor() {
    this.body = new FakeElement("body", this);
    this.head = new FakeHead("head", this);
    this.activeElement = null;
    this.title = "";
  }
  createElement(tag) { return new FakeElement(tag, this); }
}

const node = (id, role, frame, children = [], extra = {}) => ({
  node_id: `${id}`,
  semantic_id: null,
  role,
  level: null,
  url: "",
  label: "",
  value: "",
  description: "",
  checked: null,
  selected: false,
  expanded: false,
  invalid: false,
  required: false,
  focused: false,
  disabled: false,
  actions: [],
  frame: { origin: { x: frame[0], y: frame[1] }, size: { width: frame[2], height: frame[3] } },
  children,
  ...extra,
});

const flattenedNodes = root => {
  const result = [];
  const visit = current => {
    const children = current.children ?? [];
    result.push({ ...current, children: children.map(child => child.node_id) });
    for (const child of children) visit(child);
  };
  visit(root);
  return result;
};

const fullUpdate = (generation, root) => ({
  kind: "full",
  generation: `${generation}`,
  root: root.node_id,
  focused: null,
  nodes: flattenedNodes(root),
  removed: [],
});

const deltaUpdate = (generation, root, removed = []) => ({
  kind: "delta",
  generation: `${generation}`,
  root: root.node_id,
  focused: null,
  nodes: flattenedNodes(root),
  removed: removed.map(id => `${id}`),
});

const documentRef = new FakeDocument();
const hostOne = documentRef.createElement("div");
const hostTwo = documentRef.createElement("div");
documentRef.body.appendChild(hostOne);
documentRef.body.appendChild(hostTwo);
const canvasOne = documentRef.createElement("canvas");
const canvasTwo = documentRef.createElement("canvas");
hostOne.appendChild(canvasOne);
hostTwo.appendChild(canvasTwo);
const actions = [];
const manager = createSemanticsDomManager({
  document: documentRef,
  dispatch: (...args) => actions.push(args),
});

const first = node(1, "main", [0, 0, 400, 300], [
  node(2, "heading", [20, 30, 200, 40], [], { label: "Docs", level: 2 }),
  node(3, "link", [20, 80, 140, 30], [], {
    semantic_id: "a11y.link",
    label: "Android",
    url: "https://example.test/android",
    actions: ["focus", "activate"],
  }),
]);
manager.sync(11, canvasOne, fullUpdate(1, first));
const layerOne = manager.layer(11);
assert(layerOne.children.length === 1, "main root should be projected once");
const main = layerOne.children[0];
assert(main.tagName === "MAIN", "main landmark should use a main element");
const heading = main.children[0];
const link = main.children[1];
assert(heading.tagName === "H2", "heading level should select h2");
assert(heading.style.left === "20px" && heading.style.top === "30px", "child frame should be parent-relative");
assert(link.tagName === "A" && link.getAttribute("href") === "https://example.test/android", "link url should map to href");
assert(link.getAttribute("data-moui-semantic-id") === "a11y.link", "stable semantic ids must be queryable by native browser clients");
assert(link.style.pointerEvents === "auto", "actionable semantics elements must receive pointer input");
link.dispatch("pointerdown", { detail: 1, clientX: 42, clientY: 96 });
link.dispatch("click", { detail: 1, clientX: 42, clientY: 96 });
assert(actions.length === 0, "pointer clicks must not bypass canvas hit testing");
assert(
  !layerOne.listeners.has("pointermove") && !layerOne.listeners.has("wheel"),
  "semantic layers must not install a second pointer or wheel transport",
);
link.dispatch("click");
assert(actions.length === 1 && actions[0][0] === 11 && actions[0][1] === "3" && actions[0][2] === "1" && actions[0][3] === 0, "link click should dispatch activate with node and generation");
link.dispatch("keydown", { key: "Enter" });
assert(actions.length === 2 && actions[1][0] === 11 && actions[1][1] === "3" && actions[1][2] === "1" && actions[1][3] === 0, "link Enter should dispatch activate with node and generation");

const updated = node(1, "main", [0, 0, 400, 300], [
  node(2, "heading", [24, 36, 220, 40], [], { label: "Guides", level: 2, focused: true }),
]);
manager.sync(11, canvasOne, deltaUpdate(2, updated, [3]));
assert(main.children.length === 1, "removed semantic nodes should leave the DOM");
assert(main.children[0] === heading, "keyed semantic node should be reused");
assert(heading.textContent === "Guides" && heading.style.left === "24px", "reused nodes should update attributes and geometry");
const styleWritesBeforeStableSync = heading.styleWrites;
const textWritesBeforeStableSync = heading.textWrites;
manager.sync(11, canvasOne, deltaUpdate(2, updated, [3]));
assert(heading.styleWrites === styleWritesBeforeStableSync, "unchanged semantics must not rewrite inline styles");
assert(heading.textWrites === textWritesBeforeStableSync, "unchanged semantics must not rewrite text content");

const hiddenTextInput = documentRef.createElement("textarea");
hiddenTextInput.dataset.mouiTextInput = "true";
documentRef.activeElement = hiddenTextInput;
manager.sync(11, canvasOne, fullUpdate(3, node(4, "textbox", [20, 90, 260, 80], [], {
  label: "Source",
  value: "line one\nline two",
  focused: true,
  actions: ["focus", "set-text"],
})));
const multiline = manager.layer(11).children[0];
assert(multiline.tagName === "TEXTAREA", "multiline textboxes should preserve newlines");
assert(multiline.value === "line one\nline two", "multiline textbox value should retain line breaks");
assert(documentRef.activeElement === hiddenTextInput, "semantics sync must not steal focus from the canvas text input");
multiline.dispatch("pointerdown", { detail: 1, clientX: 42, clientY: 96 });
multiline.dispatch("click", { detail: 1, clientX: 42, clientY: 96 });
assert(
  actions.length === 2,
  "pointer clicks on semantic textboxes must not bypass the canvas hit tree",
);

manager.sync(11, canvasOne, fullUpdate(4, node(5, "slider", [20, 180, 260, 32], [], {
  semantic_id: "a11y.slider",
  label: "Coverage",
  numeric: { current: 0.5, min: 0, max: 1, step: 0.1, value_text: "50 percent" },
  actions: ["focus", "increment", "decrement", "set-numeric-value"],
})));
const slider = manager.layer(11).children[0];
assert(slider.tagName === "INPUT" && slider.type === "range", "slider semantics should use a native range input");
assert(slider.tabIndex === 0, "range semantics must be keyboard focusable");
slider.dispatch("keydown", { key: "ArrowRight" });
slider.dispatch("keydown", { key: "ArrowLeft" });
assert(actions.at(-2)[3] === 9 && actions.at(-1)[3] === 10, "slider arrows must dispatch increment and decrement");
slider.value = "0.7";
slider.dispatch("input");
assert(actions.at(-1)[3] === 11 && actions.at(-1)[4] === "0.7", "native range input must dispatch set numeric value");

manager.sync(11, canvasOne, fullUpdate(5, node(6, "dialog", [20, 220, 260, 120], [], {
  semantic_id: "a11y.dialog",
  label: "Probe dialog",
  modal: true,
  read_only: true,
  password: true,
  actions: ["dismiss"],
})));
const dialog = manager.layer(11).children[0];
assert(dialog.getAttribute("aria-modal") === "true", "dialog modal state must use aria-modal");
assert(dialog.getAttribute("aria-readonly") === "true", "read-only state must use legal aria-readonly spelling");
assert(dialog.getAttribute("aria-read-only") === null, "invalid aria-read-only must not be generated");
assert(dialog.getAttribute("aria-password") === null, "invalid aria-password must not be generated");
dialog.dispatch("keydown", { key: "Escape" });
assert(actions.at(-1)[3] === 8, "Escape must dispatch dismiss");

manager.sync(11, canvasOne, fullUpdate(6, node(7, "status", [20, 220, 260, 40], [], {
  semantic_id: "a11y.status",
  label: "Ready",
  live: "Polite",
  live_atomic: true,
})));
const status = manager.layer(11).children[0];
assert(status.getAttribute("aria-live") === "polite", "ARIA live tokens must use lowercase values");

manager.sync(22, canvasTwo, fullUpdate(1, node(9, "navigation", [0, 0, 200, 50])));
assert(manager.layer(22) !== layerOne, "each canvas should own an isolated semantics layer");
manager.remove(11);
assert(manager.layer(11) === undefined && manager.layer(22), "removing one window must preserve other layers");

updateDocumentMetadata({
  title: "MoUI Docs",
  description: "MoonBit GUI documentation",
  canonical: "https://example.test/docs",
  image: "https://example.test/og.webp",
}, documentRef);
assert(documentRef.title === "MoUI Docs", "metadata should update document title");
assert(documentRef.head.querySelector('meta[name="description"]').getAttribute("content") === "MoonBit GUI documentation", "metadata should update description");
assert(documentRef.head.querySelector('link[rel="canonical"]').getAttribute("href") === "https://example.test/docs", "metadata should update canonical link");

documentRef.documentElement = documentRef.createElement("html");
updateDocumentMetadata({
  title: "MoUI 文档",
  locale: "zh-Hans",
  direction: "ltr",
}, documentRef);
assert(documentRef.documentElement.getAttribute("lang") === "zh-Hans", "metadata should update document language");
assert(documentRef.documentElement.getAttribute("dir") === "ltr", "metadata should update document direction");

console.log("web semantics DOM tests: ok");
