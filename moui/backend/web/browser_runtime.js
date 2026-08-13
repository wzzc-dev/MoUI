// Browser host runtime for MoUI's canonical wasm-gc web backend.
//
// This file is the stable browser asset boundary for `backend/web`.
// It provides the `window_web` import object expected by the MoonBit
// `wzzc-dev/window/web` package without exposing registry cache paths to the
// browser.

export const WEB_INPUT_FLAGS = Object.freeze({
  handled: 1,
  capturePointer: 2,
  releasePointer: 4,
});

export function normalizeCanvasWheelDelta(event, options = {}) {
  const deltaMode = Number(event?.deltaMode) || 0;
  const rawX = Number(event?.deltaX) || 0;
  const rawY = Number(event?.deltaY) || 0;
  const lineHeight = Math.max(1, Number(options.lineHeight) || 16);
  const pageHeight = Math.max(1, Number(options.pageHeight) || 1);
  const multiplier = deltaMode === 1 ? lineHeight : deltaMode === 2 ? pageHeight : 1;
  return { x: rawX * multiplier, y: -rawY * multiplier };
}

/// A single trusted DOM-to-wasm input boundary for one canvas host.
/// It deliberately routes the original browser event instead of dispatching a
/// synthetic `PointerEvent`/`WheelEvent` at the canvas.
export class CanvasInputRouter {
  constructor(options) {
    this.canvas = options.canvas;
    this.host = options.host ?? options.canvas;
    this.rawId = options.rawId;
    this.position = options.position;
    this.dispatchPointer = options.dispatchPointer;
    this.lineHeight = options.lineHeight ?? (() => 16);
    this.pageHeight = options.pageHeight ?? (() => this.host?.clientHeight || 1);
    this.scaleDelta = options.scaleDelta ?? ((_event, delta) => delta);
    this.touchPoints = new Map();
  }

  isNativeInputTarget(target) {
    for (let current = target; current; current = current.parentElement) {
      if (current.dataset?.mouiNativeInput === "true") return true;
      if (current.getAttribute?.("data-moui-native-input") != null) return true;
      if (current === this.host) break;
    }
    return false;
  }

  isWithinHost(target) {
    for (let current = target; current; current = current.parentElement) {
      if (current === this.host) return true;
    }
    return false;
  }

  isOwnedTarget(target) {
    if (target === this.canvas) return true;
    for (let current = target; current; current = current.parentElement) {
      if (current.dataset?.mouiWindowId === `${this.rawId}`) return true;
      if (current.dataset?.mouiCanvasId === `${this.canvas.id}`) return true;
      if (current === this.host) break;
    }
    return false;
  }

  shouldRoute(event) {
    return this.isOwnedTarget(event?.target) && !this.isNativeInputTarget(event.target);
  }

  modifiers(event) {
    return (event?.shiftKey ? 1 : 0)
      | (event?.ctrlKey ? 2 : 0)
      | (event?.altKey ? 4 : 0)
      | (event?.metaKey ? 8 : 0);
  }

  dispatch(kind, event, delta = { x: 0, y: 0 }, point = this.position(this.canvas, event)) {
    const pointerId = Number(event?.pointerId) || 1;
    const flags = Number(this.dispatchPointer(
      kind,
      point.x,
      point.y,
      Number(delta.x) || 0,
      Number(delta.y) || 0,
      Number(event?.button) || 0,
      this.modifiers(event),
    )) || 0;
    if ((flags & WEB_INPUT_FLAGS.capturePointer) !== 0) {
      try {
        this.canvas?.setPointerCapture?.(pointerId);
      } catch {
        // Browsers reject capture for inactive pointers; input dispatch stays valid.
      }
    }
    if ((flags & WEB_INPUT_FLAGS.releasePointer) !== 0) {
      try {
        this.canvas?.releasePointerCapture?.(pointerId);
      } catch {
        // Releasing an already-lost capture is harmless.
      }
    }
    return flags;
  }

  pointerDown(event) {
    if (!this.shouldRoute(event)) return 0;
    const point = this.position(this.canvas, event);
    if (event?.pointerType === "touch") {
      this.touchPoints.set(Number(event.pointerId) || 1, point);
    }
    return this.dispatch(23, event, undefined, point);
  }

  pointerMove(event) {
    if (!this.shouldRoute(event)) return 0;
    const point = this.position(this.canvas, event);
    const pointerId = Number(event?.pointerId) || 1;
    if (event?.pointerType === "touch") {
      const previous = this.touchPoints.get(pointerId);
      this.touchPoints.set(pointerId, point);
      if (!previous) return 0;
      const delta = { x: previous.x - point.x, y: previous.y - point.y };
      if (delta.x === 0 && delta.y === 0) return 0;
      return this.dispatch(30, event, delta, point);
    }
    return this.dispatch(21, event, undefined, point);
  }

  pointerUp(event, cancelled = false) {
    if (!this.shouldRoute(event)) return 0;
    const pointerId = Number(event?.pointerId) || 1;
    this.touchPoints.delete(pointerId);
    return this.dispatch(cancelled ? 25 : 24, event);
  }

  pointerExit(event) {
    if (!this.shouldRoute(event) || this.isOwnedTarget(event?.relatedTarget)) return 0;
    return this.dispatch(22, event);
  }

  wheel(event) {
    const delta = normalizeCanvasWheelDelta(event, {
      lineHeight: this.lineHeight(),
      pageHeight: this.pageHeight(),
    });
    return this.dispatch(
      30,
      event,
      this.scaleDelta(event, delta),
    );
  }
}

const SEMANTICS_ACTION_CODES = new Map([
  ["activate", 0],
  ["focus", 1],
  ["set-text", 2],
  ["submit", 3],
  ["scroll", 4],
  ["select", 5],
  ["expand", 6],
  ["collapse", 7],
  ["dismiss", 8],
  ["increment", 9],
  ["decrement", 10],
  ["set-numeric-value", 11],
  ["show-menu", 12],
  ["set-selection", 13],
]);

const semanticsTag = node => {
  switch (node.role) {
    case "link": return "a";
    case "heading": return `h${Math.min(6, Math.max(1, Number(node.level) || 1))}`;
    case "navigation": return "nav";
    case "main": return "main";
    case "button": return "button";
    case "textbox": return node.multiline || `${node.value ?? ""}`.includes("\n") ? "textarea" : "input";
    case "slider": return "input";
    default: return "div";
  }
};

const setOptionalAttribute = (element, name, value) => {
  if (value === undefined || value === null || value === "") {
    if (element.getAttribute(name) !== null) element.removeAttribute(name);
    return;
  }
  const next = `${value}`;
  if (element.getAttribute(name) !== next) element.setAttribute(name, next);
};

const setElementStyle = (element, name, value) => {
  if (element.style[name] !== value) element.style[name] = value;
};

const semanticsFocusable = actions => actions.some(action => [
  "focus", "activate", "set-text", "submit", "select", "expand", "collapse",
  "dismiss", "increment", "decrement", "set-numeric-value", "show-menu",
].includes(action));

const semanticsActivation = actions => {
  for (const action of ["activate", "submit", "select", "expand", "collapse", "dismiss"]) {
    if (actions.includes(action)) return action;
  }
  return undefined;
};

// Semantics is deliberately a DOM description, not a second input transport.
// Pointer and wheel events bubble through canvas-host and are handled by the
// CanvasInputRouter above; these handlers only support keyboard/AT actions.
export function createSemanticsDomManager(options = {}) {
  const documentRef = options.document ?? globalThis.document;
  const layers = new Map();
  let dispatch = typeof options.dispatch === "function" ? options.dispatch : () => {};

  const createLayer = (rawId, canvas) => {
    const layer = documentRef.createElement("div");
    layer.className = "moui-semantics-layer";
    layer.dataset.mouiWindowId = `${rawId}`;
    Object.assign(layer.style, {
      position: "absolute",
      inset: "0",
      pointerEvents: "none",
      overflow: "hidden",
      zIndex: "2",
    });
    const host = canvas.parentElement ?? documentRef.body;
    if (globalThis.getComputedStyle?.(host)?.position === "static") {
      host.style.position = "relative";
    }
    host.appendChild(layer);
    const state = {
      rawId,
      layer,
      elements: new Map(),
      nodes: new Map(),
      rootId: null,
      generation: "0",
    };
    layers.set(rawId, state);
    return state;
  };

  const dispatchAction = (state, node, action, value = "") => {
    const code = SEMANTICS_ACTION_CODES.get(action);
    if (code !== undefined) {
      dispatch(
        state.rawId,
        `${node.node_id ?? ""}`,
        state.generation,
        code,
        `${value ?? ""}`,
        0,
      );
    }
  };

  const installHandlers = (state, record) => {
    const { element } = record;
    element.addEventListener("focus", () => {
      const node = record.node;
      if (node?.actions?.includes("focus")) dispatchAction(state, node, "focus");
    });
    element.addEventListener("click", event => {
      // Pointer activation has already travelled through the trusted host
      // router. detail=0 is the browser/assistive-technology activation path.
      if (Number(event.detail) > 0) {
        event.preventDefault();
        return;
      }
      const node = record.node;
      const action = semanticsActivation(node?.actions ?? []);
      if (action) {
        event.preventDefault();
        dispatchAction(state, node, action);
      }
    });
    element.addEventListener("keydown", event => {
      const node = record.node;
      const actions = node?.actions ?? [];
      if (event.key === "Escape" && actions.includes("dismiss")) {
        event.preventDefault();
        dispatchAction(state, node, "dismiss");
        return;
      }
      const rangeAction = event.key === "ArrowRight" || event.key === "ArrowUp"
        ? "increment"
        : event.key === "ArrowLeft" || event.key === "ArrowDown"
          ? "decrement"
          : undefined;
      if (rangeAction && actions.includes(rangeAction)) {
        event.preventDefault();
        dispatchAction(state, node, rangeAction);
        return;
      }
      if (event.key !== "Enter" && event.key !== " ") return;
      const action = semanticsActivation(actions);
      if (action) {
        event.preventDefault();
        dispatchAction(state, node, action);
      }
    });
    element.addEventListener("input", event => {
      const node = record.node;
      if (node?.actions?.includes("set-text")) {
        dispatchAction(state, node, "set-text", event.currentTarget?.value ?? "");
      } else if (node?.actions?.includes("set-numeric-value")) {
        dispatchAction(state, node, "set-numeric-value", event.currentTarget?.value ?? "");
      }
    });
    const dispatchSelection = event => {
      const node = record.node;
      const target = event.currentTarget;
      if (!node?.actions?.includes("set-selection") || !target) return;
      const start = Number(target.selectionStart);
      const end = Number(target.selectionEnd);
      if (!Number.isInteger(start) || !Number.isInteger(end)) return;
      dispatchAction(state, node, "set-selection", `${start},${end}`);
    };
    element.addEventListener("select", dispatchSelection);
    element.addEventListener("keyup", event => {
      if (event.key === "ArrowLeft" || event.key === "ArrowRight" || event.key === "Home" || event.key === "End") {
        dispatchSelection(event);
      }
    });
  };

  const updateElement = (state, record, node, parentFrame) => {
    record.node = node;
    const { element } = record;
    const origin = node.frame?.origin ?? {};
    const size = node.frame?.size ?? {};
    const left = `${(Number(origin.x) || 0) - (Number(parentFrame?.x) || 0)}px`;
    const top = `${(Number(origin.y) || 0) - (Number(parentFrame?.y) || 0)}px`;
    const width = `${Math.max(0, Number(size.width) || 0)}px`;
    const height = `${Math.max(0, Number(size.height) || 0)}px`;
    const geometryKey = `${left}\u0000${top}\u0000${width}\u0000${height}`;
    if (record.geometryKey !== geometryKey) {
      setElementStyle(element, "position", "absolute");
      setElementStyle(element, "left", left);
      setElementStyle(element, "top", top);
      setElementStyle(element, "width", width);
      setElementStyle(element, "height", height);
      record.geometryKey = geometryKey;
    }
    const actions = node.actions ?? [];
    const pointerEvents = semanticsFocusable(actions) ? "auto" : "none";
    const tabIndex = node.disabled ? -1 : (semanticsFocusable(actions) ? 0 : -1);
    const textValue = node.label || node.value || "";
    const presentationKey = [
      pointerEvents, node.semantic_id, node.role, node.level, node.url, node.label, node.value,
      node.description, node.checked, node.selected, node.expanded, node.invalid,
      node.required, node.disabled, node.read_only, node.busy, node.multiline,
      node.password, node.modal, JSON.stringify(node.numeric ?? null), JSON.stringify(node.text ?? null), JSON.stringify(node.collection ?? null),
      JSON.stringify(node.labelled_by ?? []), JSON.stringify(node.described_by ?? []),
      JSON.stringify(node.controls ?? []), JSON.stringify(node.error_message ?? []),
      JSON.stringify(node.active_descendant ?? []), node.live, node.live_atomic, actions.join("\u0000"),
    ].join("\u0000");
    if (record.presentationKey !== presentationKey) {
      Object.assign(element.style, {
        opacity: "0.001",
        color: "transparent",
        background: "transparent",
        border: "0",
        padding: "0",
        margin: "0",
        pointerEvents,
      });
      setOptionalAttribute(element, "role", node.role === "presentation" || node.role === "" ? undefined : node.role);
      setOptionalAttribute(element, "data-moui-semantic-id", node.semantic_id);
      setOptionalAttribute(element, "aria-label", node.label);
      setOptionalAttribute(element, "aria-description", node.description);
      setOptionalAttribute(element, "aria-level", node.role === "heading" ? node.level : undefined);
      setOptionalAttribute(element, "href", node.role === "link" ? node.url : undefined);
      setOptionalAttribute(element, "aria-checked", node.checked);
      for (const name of ["selected", "expanded", "invalid", "required", "disabled", "busy", "multiline", "modal"]) {
        const value = node[name];
        const attribute = name === "disabled" ? "aria-disabled" : `aria-${name.replaceAll("_", "-")}`;
        setOptionalAttribute(element, attribute, value ? "true" : undefined);
      }
      setOptionalAttribute(element, "aria-readonly", node.read_only ? "true" : undefined);
      const live = `${node.live ?? ""}`.toLowerCase();
      setOptionalAttribute(element, "aria-live", live && live !== "off" ? live : undefined);
      setOptionalAttribute(element, "aria-atomic", node.live_atomic ? "true" : undefined);
      setOptionalAttribute(element, "aria-labelledby", relationIds(node.labelled_by));
      setOptionalAttribute(element, "aria-describedby", relationIds(node.described_by));
      setOptionalAttribute(element, "aria-controls", relationIds(node.controls));
      setOptionalAttribute(element, "aria-errormessage", relationIds(node.error_message));
      setOptionalAttribute(element, "aria-activedescendant", relationIds(node.active_descendant, true));
      if (node.numeric) {
        setOptionalAttribute(element, "aria-valuenow", numberAttribute(node.numeric.current));
        setOptionalAttribute(element, "aria-valuemin", numberAttribute(node.numeric.min));
        setOptionalAttribute(element, "aria-valuemax", numberAttribute(node.numeric.max));
        setOptionalAttribute(element, "aria-valuetext", node.numeric.value_text);
      } else {
        for (const name of ["aria-valuenow", "aria-valuemin", "aria-valuemax", "aria-valuetext"]) {
          setOptionalAttribute(element, name, undefined);
        }
      }
      if (node.collection) {
        for (const [key, value] of Object.entries({
          "aria-rowindex": node.collection.row_index,
          "aria-rowcount": node.collection.row_count,
          "aria-rowspan": node.collection.row_span,
          "aria-colindex": node.collection.column_index,
          "aria-colcount": node.collection.column_count,
          "aria-colspan": node.collection.column_span,
          "aria-setsize": node.collection.set_size,
          "aria-posinset": node.collection.set_position,
        })) setOptionalAttribute(element, key, numberAttribute(value));
      } else {
        for (const name of ["aria-rowindex", "aria-rowcount", "aria-rowspan", "aria-colindex", "aria-colcount", "aria-colspan", "aria-setsize", "aria-posinset"]) {
          setOptionalAttribute(element, name, undefined);
        }
      }
      if (element.tabIndex !== tabIndex) element.tabIndex = tabIndex;
      if (node.role === "textbox") {
        if (element.value !== `${node.value ?? ""}`) element.value = node.value ?? "";
        if (node.password) element.type = "password";
        if (node.text?.selection && documentRef.activeElement === element) {
          try { element.setSelectionRange(Number(node.text.selection.start), Number(node.text.selection.end)); } catch (_) { /* non-input fallback */ }
        }
        setOptionalAttribute(element, "autocomplete", "off");
      } else if (node.role === "slider") {
        element.type = "range";
        if (element.value !== `${node.numeric?.current ?? ""}`) {
          element.value = `${node.numeric?.current ?? ""}`;
        }
        setOptionalAttribute(element, "min", numberAttribute(node.numeric?.min));
        setOptionalAttribute(element, "max", numberAttribute(node.numeric?.max));
        setOptionalAttribute(element, "step", numberAttribute(node.numeric?.step));
      } else if (element.textContent !== textValue) {
        element.textContent = textValue;
      }
      record.presentationKey = presentationKey;
    }
    // Semantic commit must not steal browser input focus. Explicit Focus
    // actions are dispatched through the generation-checked bridge.
  };

  const numberAttribute = value => {
    if (value == null) return undefined;
    const number = Number(value);
    return Number.isFinite(number) ? `${number}` : undefined;
  };

  const relationIds = (ids, single = false) => {
    if (!Array.isArray(ids)) return undefined;
    const values = ids.map(value => `moui-a11y-${value ?? ""}`).filter(Boolean);
    if (single) return values[0] || undefined;
    return values.length ? values.join(" ") : undefined;
  };

  const visit = (state, nodeId, parent, parentFrame, seen) => {
    const id = `${nodeId ?? ""}`;
    if (!id || seen.has(id)) return;
    const node = state.nodes.get(id);
    if (!node) return;
    seen.add(id);
    let record = state.elements.get(id);
    const tag = semanticsTag(node);
    if (!record || record.element.tagName.toLowerCase() !== tag) {
      record?.element.remove();
      const element = documentRef.createElement(tag);
      element.dataset.mouiSemanticsNodeId = id;
      element.id = `moui-a11y-${id}`;
      record = { element, node, geometryKey: "", presentationKey: "" };
      state.elements.set(id, record);
      installHandlers(state, record);
    }
    if (record.element.parentElement !== parent) parent.appendChild(record.element);
    updateElement(state, record, node, parentFrame);
    const origin = node.frame?.origin ?? {};
    const frame = { x: Number(origin.x) || 0, y: Number(origin.y) || 0 };
    for (const child of node.children ?? []) {
      visit(state, child, record.element, frame, seen);
    }
  };

  return {
    setDispatch(next) {
      dispatch = typeof next === "function" ? next : () => {};
    },
    sync(rawId, canvas, update) {
      if (!documentRef || !canvas || !update) return;
      if (update.kind !== "full" && update.kind !== "delta") return;
      const state = layers.get(rawId) ?? createLayer(rawId, canvas);
      if (update.kind === "full") state.nodes.clear();
      for (const id of update.removed ?? []) state.nodes.delete(`${id}`);
      for (const node of update.nodes ?? []) {
        const id = `${node.node_id ?? ""}`;
        if (id) state.nodes.set(id, node);
      }
      state.rootId = update.root == null ? null : `${update.root}`;
      state.generation = `${update.generation ?? state.generation}`;
      state.layer.dataset.mouiSemanticsGeneration = state.generation;
      const seen = new Set();
      if (state.rootId) {
        visit(state, state.rootId, state.layer, { x: 0, y: 0 }, seen);
      }
      for (const [id, record] of state.elements) {
        if (!seen.has(id)) {
          record.element.remove();
          state.elements.delete(id);
        }
      }
    },
    remove(rawId) {
      const state = layers.get(rawId);
      state?.layer.remove();
      layers.delete(rawId);
    },
    layer(rawId) {
      return layers.get(rawId)?.layer;
    },
  };
}

export function updateDocumentMetadata(metadata, documentRef = globalThis.document) {
  if (!documentRef || !metadata) return;
  if (metadata.title) documentRef.title = metadata.title;
  const documentElement = documentRef.documentElement;
  if (documentElement?.setAttribute) {
    if (metadata.locale) documentElement.setAttribute("lang", `${metadata.locale}`);
    if (metadata.direction) documentElement.setAttribute("dir", `${metadata.direction}`);
  }
  const upsert = (selector, create, value) => {
    let element = documentRef.head?.querySelector?.(selector);
    if (!element && value) {
      element = create();
      documentRef.head?.appendChild?.(element);
    }
    if (element && value) element.setAttribute("content", value);
  };
  const meta = (name, value, property = false) => upsert(
    `meta[${property ? "property" : "name"}="${name}"]`,
    () => {
      const element = documentRef.createElement("meta");
      element.setAttribute(property ? "property" : "name", name);
      return element;
    },
    value,
  );
  meta("description", metadata.description);
  meta("og:title", metadata.title, true);
  meta("og:description", metadata.description, true);
  meta("og:url", metadata.canonical, true);
  meta("og:image", metadata.image, true);
  meta("twitter:card", metadata.image ? "summary_large_image" : "summary");
  meta("twitter:title", metadata.title);
  meta("twitter:description", metadata.description);
  meta("twitter:image", metadata.image);
  let canonical = documentRef.head?.querySelector?.('link[rel="canonical"]');
  if (!canonical && metadata.canonical) {
    canonical = documentRef.createElement("link");
    canonical.setAttribute("rel", "canonical");
    documentRef.head?.appendChild?.(canonical);
  }
  if (canonical && metadata.canonical) canonical.setAttribute("href", metadata.canonical);
}

export function normalizeWebRouteString(route) {
  const value = `${route ?? ""}`.trim();
  if (!value || value === "/" || value === ".") {
    return "overview";
  }
  const withoutHash = value.startsWith("#") ? value.slice(1) : value;
  return withoutHash.replace(/^\/+/, "").replace(/\/+$/, "") || "overview";
}

export function browserRouteFromLocation(location = globalThis.window?.location) {
  if (!location) {
    return "overview";
  }
  const params = new URLSearchParams(location.search || "");
  const explicitRoute = params.get("route");
  if (explicitRoute) {
    return normalizeWebRouteString(explicitRoute);
  }
  const section = params.get("section");
  if (section) {
    const query = new URLSearchParams();
    for (const [key, value] of params) {
      if (key !== "section" && key !== "debug") {
        query.append(key, value);
      }
    }
    const suffix = query.toString();
    return normalizeWebRouteString(`${section}${suffix ? `?${suffix}` : ""}`);
  }
  const hash = `${location.hash || ""}`.replace(/^#/, "");
  if (hash) {
    return normalizeWebRouteString(decodeURIComponent(hash));
  }
  return "overview";
}

export function browserRouteUrl(
  route,
  location = globalThis.window?.location,
) {
  const url = new URL(location?.href || "http://localhost/");
  const params = new URLSearchParams();
  const current = new URLSearchParams(url.search || "");
  if (current.get("debug") === "1") {
    params.set("debug", "1");
  }
  const normalized = normalizeWebRouteString(route);
  const question = normalized.indexOf("?");
  const section = question >= 0 ? normalized.slice(0, question) : normalized;
  const routeQuery = question >= 0 ? normalized.slice(question + 1) : "";
  params.set("section", section);
  for (const [key, value] of new URLSearchParams(routeQuery)) {
    if (key !== "section" && key !== "route" && key !== "debug") {
      params.append(key, value);
    }
  }
  url.search = params.toString();
  url.hash = "";
  return url;
}

export function createWindowWebImports(options = {}) {
  const canvases = new Map();
  const listeners = new Map();
  const platformCanvasListeners = new Map();
  const textInputs = new Map();
  const stringHandles = new Map();
  const eventTexts = new Map();
  const fileHandles = new Map();
  let nextCanvasId = 1;
  let nextStringHandle = 1;
  let nextEventTextId = 1;
  let dispatchEvent = null;
  let dispatchPointerInput = null;
  let dispatchRoute = null;
  let wasmExports = null;
  let routeListenerInstalled = false;
  const semantics = createSemanticsDomManager();
  const eventObserver =
    typeof options.onEvent === "function"
      ? options.onEvent
      : globalThis.__mouiWebRuntimeObservation?.recordEvent?.bind(
          globalThis.__mouiWebRuntimeObservation,
        );
  const routeObserver =
    typeof options.onRoute === "function"
      ? options.onRoute
      : globalThis.__mouiWebRuntimeObservation?.recordRoute?.bind(
          globalThis.__mouiWebRuntimeObservation,
        );

  const eventName = kind => {
    switch (kind | 0) {
      case 1: return "animation_frame";
      case 2: return "timeout";
      case 3: return "proxy_wake";
      case 10: return "resize";
      case 11: return "focus";
      case 12: return "blur";
      case 20: return "pointer_enter";
      case 21: return "pointer_move";
      case 22: return "pointer_leave";
      case 23: return "pointer_down";
      case 24: return "pointer_up";
      case 25: return "pointer_cancel";
      case 30: return "wheel";
      case 40: return "key_down";
      case 41: return "key_up";
      case 42: return "ime_commit";
      case 43: return "ime_start";
      case 44: return "ime_preedit";
      case 45: return "ime_delete_surrounding";
      case 50: return "theme";
      case 60: return "drag_enter";
      case 61: return "drag_move";
      case 62: return "drag_drop";
      case 63: return "drag_leave";
      default: return "unknown";
    }
  };

  const observeEvent = event => {
    if (!eventObserver) return;
    try {
      eventObserver(event);
    } catch (error) {
      globalThis.console?.error?.("MoUI Web runtime observation observer failed", error);
    }
  };

  const observeRoute = event => {
    if (!routeObserver) return;
    try {
      routeObserver(event);
    } catch (error) {
      globalThis.console?.error?.("MoUI Web route observation observer failed", error);
    }
  };

  const routeSourceName = source => {
    switch (source | 0) {
      case 0: return "initial";
      case 1: return "popstate";
      case 2: return "pushstate";
      case 3: return "replacestate";
      default: return "route";
    }
  };

  const normalizeRouteString = normalizeWebRouteString;

  const currentBrowserRoute = () => browserRouteFromLocation();

  const routeUrl = route => browserRouteUrl(route);

  const resolveCanvasHost = () => {
    const host = options.canvasHost;
    if (host instanceof HTMLElement) {
      return host;
    }
    if (typeof host === "string") {
      return document.querySelector(host) ?? document.body;
    }
    return document.getElementById("canvas-host") ?? document.body;
  };

  const emit = (kind, rawId = 0, arg0 = 0, arg1 = 0, argd = 0.0, text = "") => {
    if (dispatchEvent) {
      const textId = nextEventTextId++;
      eventTexts.set(textId, `${text ?? ""}`);
      try {
        dispatchEvent(kind, rawId, arg0, arg1, argd, textId);
        observeEvent({
          kind: kind | 0,
          name: eventName(kind),
          rawId: rawId | 0,
          arg0: arg0 | 0,
          arg1: arg1 | 0,
          argd: Number(argd) || 0,
          text: `${text ?? ""}`,
          at: Number(globalThis.performance?.now?.() ?? Date.now()),
        });
      } finally {
        eventTexts.delete(textId);
      }
    }
  };

  const emitPlatformView = (
    rawId,
    id,
    name,
    value = "",
    detail = "",
    flag = false,
  ) => {
    const dispatch = wasmExports?.web_dispatch_platform_view_event;
    if (typeof dispatch !== "function") return;
    const ids = [id, name, value, detail].map(text => {
      const textId = nextEventTextId++;
      eventTexts.set(textId, `${text ?? ""}`);
      return textId;
    });
    try {
      dispatch(rawId | 0, ids[0], ids[1], ids[2], ids[3], !!flag);
    } finally {
      for (const textId of ids) eventTexts.delete(textId);
    }
  };

  const emitPointerInput = (
    rawId,
    kind,
    xPx,
    yPx,
    deltaXPx,
    deltaYPx,
    button,
    modifiers,
  ) => {
    if (!dispatchPointerInput) return 0;
    const flags = Number(dispatchPointerInput(
      rawId,
      kind,
      xPx,
      yPx,
      deltaXPx,
      deltaYPx,
      button,
      modifiers,
    )) || 0;
    observeEvent({
      kind: kind | 0,
      name: eventName(kind),
      rawId: rawId | 0,
      x: Number(xPx) || 0,
      y: Number(yPx) || 0,
      deltaX: Number(deltaXPx) || 0,
      deltaY: Number(deltaYPx) || 0,
      button: button | 0,
      modifiers: modifiers | 0,
      flags,
      at: Number(globalThis.performance?.now?.() ?? Date.now()),
    });
    return flags;
  };

  const emitRoute = (source, route = currentBrowserRoute()) => {
    const normalized = normalizeRouteString(route);
    if (dispatchRoute) {
      const textId = nextEventTextId++;
      eventTexts.set(textId, normalized);
      try {
        dispatchRoute(source | 0, textId);
      } finally {
        eventTexts.delete(textId);
      }
    }
    observeRoute({
      source: routeSourceName(source),
      route: normalized,
      href: `${globalThis.window?.location?.href ?? ""}`,
      at: Number(globalThis.performance?.now?.() ?? Date.now()),
    });
  };

  const installRouteListener = () => {
    if (routeListenerInstalled || !globalThis.window?.addEventListener) {
      return;
    }
    globalThis.window.addEventListener("popstate", () => emitRoute(1));
    routeListenerInstalled = true;
  };

  const completeAsyncText = (exportName, requestId, ok, text = "") => {
    const complete = wasmExports?.[exportName];
    if (typeof complete !== "function") {
      return;
    }
    const textId = nextEventTextId++;
    eventTexts.set(textId, `${text ?? ""}`);
    try {
      complete(requestId | 0, !!ok, textId);
    } finally {
      eventTexts.delete(textId);
    }
    emit(3);
  };

  const completeAsyncFileOpenText = (requestId, ok, path = "", text = "") => {
    const complete = wasmExports?.web_complete_async_file_open_text;
    if (typeof complete !== "function") {
      completeAsyncText(
        "web_complete_async_file_dialog",
        requestId,
        ok,
        ok ? path : text || path,
      );
      return;
    }
    const pathId = nextEventTextId++;
    const textId = nextEventTextId++;
    eventTexts.set(pathId, `${path ?? ""}`);
    eventTexts.set(textId, `${text ?? ""}`);
    try {
      complete(requestId | 0, !!ok, pathId, textId);
    } finally {
      eventTexts.delete(pathId);
      eventTexts.delete(textId);
    }
    emit(3);
  };

  const createStringHandle = value => {
    const handle = { value: `${value ?? ""}`, offset: 0 };
    const id = nextStringHandle++;
    stringHandles.set(id, handle);
    return id;
  };

  const stringValue = handle => {
    if (typeof handle === "number") {
      const value = stringHandles.get(handle)?.value ?? "";
      stringHandles.delete(handle);
      return value;
    }
    if (typeof handle === "string") {
      return handle;
    }
    return handle?.value ?? "";
  };

  const ensureCanvasId = canvas => {
    if (!canvas.id) {
      canvas.id = `moonbit-window-web-${nextCanvasId++}`;
    }
    return canvas.id;
  };

  const canvasValue = canvas =>
    canvas instanceof HTMLCanvasElement ? canvas : canvases.get(canvas) ?? null;

  const canvasHostSize = canvas => {
    const host = canvas?.parentElement;
    const rect = host?.getBoundingClientRect?.();
    return {
      width: Math.max(1, Math.round(rect?.width || globalThis.window?.innerWidth || 1)),
      height: Math.max(1, Math.round(rect?.height || globalThis.window?.innerHeight || 1)),
    };
  };

  const resizeCanvasToHost = canvas => {
    if (!canvas) return;
    const size = canvasHostSize(canvas);
    const scale = devicePixelRatio();
    canvas.width = Math.max(1, Math.round(size.width * scale));
    canvas.height = Math.max(1, Math.round(size.height * scale));
    canvas.style.width = `${size.width}px`;
    canvas.style.height = `${size.height}px`;
  };

  const pointerPosition = (canvas, event) => {
    const rect = canvas.getBoundingClientRect();
    // DOM events are in CSS pixels, while the Web window adapter accepts
    // physical pixels and divides them by its current DPR before hit-testing.
    // Map through the canvas backing store so CSS resizing remains correct.
    const scaleX = rect.width > 0 ? canvas.width / rect.width : devicePixelRatio();
    const scaleY = rect.height > 0 ? canvas.height / rect.height : devicePixelRatio();
    return {
      x: ((Number(event.clientX) || 0) - rect.left) * scaleX,
      y: ((Number(event.clientY) || 0) - rect.top) * scaleY,
    };
  };

  const draggedFileNames = event =>
    Array.from(event.dataTransfer?.files ?? [])
      .map(file => file.webkitRelativePath || file.name)
      .filter(Boolean)
      .join("\n");

  const fileListNames = files =>
    Array.from(files ?? [])
      .map(file => file.webkitRelativePath || file.name)
      .filter(Boolean)
      .join("\n");

  const filterListToAccept = filters =>
    `${filters ?? ""}`
      .split(/[\n,]+/)
      .map(part => part.trim())
      .filter(Boolean)
      .map(part =>
        part.startsWith(".") || part.includes("/")
          ? part
          : `.${part.replace(/^\.+/, "")}`
      )
      .join(",");

  const filePickerTypes = accept => {
    const extensions = `${accept ?? ""}`
      .split(",")
      .map(part => part.trim())
      .filter(part => part.startsWith("."));
    if (extensions.length === 0) {
      return undefined;
    }
    return [{ description: "Markdown files", accept: { "text/markdown": extensions } }];
  };

  const registerFileHandle = (handle, fallbackName = "") => {
    const path = handle?.name || fallbackName || "untitled.md";
    if (handle) {
      fileHandles.set(path, handle);
    }
    return path;
  };

  const asyncFailureMessage = (error, fallback) => {
    if (error?.name === "AbortError") {
      return "";
    }
    return `${error?.message || error || fallback}`;
  };

  const base64ToUint8Array = value => {
    try {
      const binary = atob(`${value ?? ""}`);
      const out = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i);
      return out;
    } catch {
      return undefined;
    }
  };

  const logicalCanvasWidth = canvas =>
    Math.max(1, Math.round(canvas?.clientWidth || canvas?.width || 1));

  const logicalCanvasHeight = canvas =>
    Math.max(1, Math.round(canvas?.clientHeight || canvas?.height || 1));

  const devicePixelRatio = () => globalThis.window?.devicePixelRatio || 1.0;

  const createHiddenTextInput = canvas => {
    const input = document.createElement("textarea");
    input.setAttribute("aria-label", "Text input");
    input.dataset.mouiTextInput = "true";
    input.dataset.mouiNativeInput = "true";
    input.setAttribute("data-moui-native-input", "true");
    input.autocomplete = "off";
    input.autocapitalize = "off";
    input.spellcheck = false;
    input.tabIndex = -1;
    input.wrap = "off";
    input.value = "";
    input.style.position = "fixed";
    input.style.left = "-10000px";
    input.style.top = "0";
    input.style.width = "1px";
    input.style.height = "1px";
    input.style.opacity = "0";
    input.style.pointerEvents = "none";
    input.style.zIndex = "0";
    (canvas.parentElement ?? document.body).appendChild(input);
    return input;
  };

  const focusWithoutScroll = element => {
    try {
      element?.focus?.({ preventScroll: true });
    } catch {
      element?.focus?.();
    }
  };

  const preventDefaultIfCancelable = event => {
    if (event.cancelable) {
      event.preventDefault();
    }
  };

  const textInputHostHasFocus = state =>
    document.activeElement === state.canvas ||
    document.activeElement === state.input;

  const focusTextInputIfHostActive = state => {
    if (state.imeAllowed && textInputHostHasFocus(state)) {
      focusWithoutScroll(state.input);
    }
  };

  const scheduleTextInputFocus = state => {
    focusWithoutScroll(state.input);
    setTimeout(() => focusTextInputIfHostActive(state), 0);
    setTimeout(() => focusTextInputIfHostActive(state), 16);
  };

  const shouldForwardTextInputKey = event =>
    event.key === "Enter" ||
    event.key === "Tab" ||
    event.key === "ArrowLeft" ||
    event.key === "ArrowRight" ||
    event.key === "ArrowUp" ||
    event.key === "ArrowDown" ||
    event.key === "Home" ||
    event.key === "End" ||
    event.key === "PageUp" ||
    event.key === "PageDown" ||
    event.key === "Escape";

  const isModifierKey = event =>
    event.key === "Shift" ||
    event.key === "Control" ||
    event.key === "Alt" ||
    event.key === "Meta";

  const isClipboardWriteShortcut = event => {
    const key = `${event.key || ""}`.toLowerCase();
    return (
      (event.ctrlKey || event.metaKey) &&
      !event.altKey &&
      !event.shiftKey &&
      (key === "c" || key === "x")
    );
  };

  const shouldForwardRuntimeKey = event =>
    shouldForwardTextInputKey(event) ||
    isModifierKey(event) ||
    isClipboardWriteShortcut(event);

  const isPlainTextKey = event =>
    event.key &&
    event.key.length === 1 &&
    !event.ctrlKey &&
    !event.metaKey &&
    !event.altKey;

  const inputEventData = event => {
    if (event.data) return event.data;
    const value = event.target?.value ?? "";
    return value;
  };

  const physicalCanvasWidth = canvas =>
    Math.max(1, Math.round(logicalCanvasWidth(canvas) * devicePixelRatio()));

  const physicalCanvasHeight = canvas =>
    Math.max(1, Math.round(logicalCanvasHeight(canvas) * devicePixelRatio()));

  return {
    begin_create_string() {
      return createStringHandle("");
    },
    string_append_char(handle, ch) {
      const entry = stringHandles.get(handle);
      if (entry) {
        entry.value += String.fromCodePoint(Number(ch));
      }
    },
    finish_create_string(handle) {
      return handle;
    },
    begin_read_string(id) {
      return createStringHandle(
        eventTexts.get(id) ?? stringHandles.get(id)?.value ?? "",
      );
    },
    string_read_char(handle) {
      const entry = stringHandles.get(handle);
      if (!entry || entry.offset >= entry.value.length) {
        return -1;
      }
      const codePoint = entry.value.codePointAt(entry.offset);
      entry.offset += codePoint > 0xffff ? 2 : 1;
      return codePoint;
    },
    finish_read_string(handle) {
      stringHandles.delete(handle);
    },
    register_host_string(value) {
      return createStringHandle(stringValue(value));
    },
    create_canvas(id, width, height) {
      const canvas = document.createElement("canvas");
      canvas.id = stringValue(id) || `moonbit-window-web-${nextCanvasId++}`;
      canvas.width = Math.max(1, width | 0);
      canvas.height = Math.max(1, height | 0);
      canvas.tabIndex = 0;
      canvas.style.display = "block";
      resolveCanvasHost().appendChild(canvas);
      resizeCanvasToHost(canvas);
      canvases.set(canvas.id, canvas);
      return canvas;
    },
    get_canvas_by_id(id) {
      const canvas = document.getElementById(stringValue(id));
      if (canvas instanceof HTMLCanvasElement) {
        canvases.set(canvas.id, canvas);
        return canvas;
      }
      return null;
    },
    canvas_is_valid(handle) {
      return canvasValue(handle) instanceof HTMLCanvasElement;
    },
    canvas_id(handle) {
      const canvas = canvasValue(handle);
      return canvas ? ensureCanvasId(canvas) : "";
    },
    canvas_width(handle) {
      const canvas = canvasValue(handle);
      return canvas?.width ?? 0;
    },
    canvas_height(handle) {
      const canvas = canvasValue(handle);
      return canvas?.height ?? 0;
    },
    canvas_client_width(handle) {
      const canvas = canvasValue(handle);
      return logicalCanvasWidth(canvas);
    },
    canvas_client_height(handle) {
      const canvas = canvasValue(handle);
      return logicalCanvasHeight(canvas);
    },
    canvas_offset_left(handle) {
      const canvas = canvasValue(handle);
      return Math.round(canvas?.getBoundingClientRect().left ?? 0);
    },
    canvas_offset_top(handle) {
      const canvas = canvasValue(handle);
      return Math.round(canvas?.getBoundingClientRect().top ?? 0);
    },
    set_canvas_size(handle, width, height) {
      const canvas = canvasValue(handle);
      if (canvas) {
        let logicalWidth = Math.max(1, Math.round(width / devicePixelRatio()));
        let logicalHeight = Math.max(1, Math.round(height / devicePixelRatio()));
        const host = canvasHostSize(canvas);
        if (host.width > 1 || host.height > 1) {
          logicalWidth = host.width;
          logicalHeight = host.height;
        }
        const scale = devicePixelRatio();
        canvas.width = Math.max(1, Math.round(logicalWidth * scale));
        canvas.height = Math.max(1, Math.round(logicalHeight * scale));
        canvas.style.width = `${logicalWidth}px`;
        canvas.style.height = `${logicalHeight}px`;
      }
    },
    set_canvas_visible(handle, visible) {
      const canvas = canvasValue(handle);
      if (canvas) {
        canvas.style.display = visible ? "block" : "none";
      }
    },
    set_canvas_position(handle, x, y, width, height, zIndex = 3) {
      const canvas = canvasValue(handle);
      if (!canvas) return;
      canvas.style.position = "absolute";
      canvas.style.left = `${Number(x) || 0}px`;
      canvas.style.top = `${Number(y) || 0}px`;
      canvas.style.width = `${Math.max(1, Number(width) || 1)}px`;
      canvas.style.height = `${Math.max(1, Number(height) || 1)}px`;
      const layer = Number(zIndex);
      canvas.style.zIndex = `${Number.isFinite(layer) ? layer : 3}`;
    },
    set_canvas_layer(handle, zIndex) {
      const canvas = canvasValue(handle);
      if (!canvas) return;
      if (!canvas.style.position || canvas.style.position === "static") {
        canvas.style.position = "relative";
      }
      canvas.style.zIndex = `${Number(zIndex) || 0}`;
    },
    canvas_scale_factor(handle) {
      return canvasValue(handle) ? devicePixelRatio() : 1.0;
    },
    destroy_canvas(handle) {
      const canvas = canvasValue(handle);
      if (!canvas) return;
      const handlers = platformCanvasListeners.get(canvas) || [];
      for (const [target, type, handler, options] of handlers) {
        target.removeEventListener(type, handler, options);
      }
      platformCanvasListeners.delete(canvas);
      canvases.delete(canvas.id);
      canvas.remove();
    },
    set_canvas_cursor(handle, cursor) {
      const canvas = canvasValue(handle);
      if (canvas) {
        canvas.style.cursor = stringValue(cursor) || "default";
      }
    },
    set_document_title(title) {
      document.title = stringValue(title);
    },
    clipboard_write_text(text) {
      const value = stringValue(text);
      const previousActive = document.activeElement;
      const input = document.createElement("textarea");
      input.value = value;
      input.setAttribute("readonly", "");
      input.style.position = "fixed";
      input.style.left = "-10000px";
      input.style.top = "0";
      input.style.width = "1px";
      input.style.height = "1px";
      input.style.opacity = "0";
      input.style.pointerEvents = "none";
      document.body.appendChild(input);
      focusWithoutScroll(input);
      input.select();
      let copied = false;
      try {
        copied = document.execCommand?.("copy") === true;
      } catch {
        copied = false;
      }
      input.remove();
      focusWithoutScroll(previousActive);
      return copied;
    },
    clipboard_read_text_async(requestId) {
      if (!navigator.clipboard?.readText) {
        completeAsyncText(
          "web_complete_async_clipboard_read",
          requestId,
          false,
          "clipboard read requires navigator.clipboard.readText",
        );
        return;
      }
      navigator.clipboard
        .readText()
        .then(text => {
          completeAsyncText(
            "web_complete_async_clipboard_read",
            requestId,
            true,
            text,
          );
        })
        .catch(error => {
          completeAsyncText(
            "web_complete_async_clipboard_read",
            requestId,
            false,
            asyncFailureMessage(error, "clipboard read failed"),
          );
        });
    },
    clipboard_read_image_async(requestId) {
      if (!navigator.clipboard?.read) {
        completeAsyncText(
          "web_complete_async_clipboard_read_image",
          requestId,
          false,
          "clipboard image read requires navigator.clipboard.read",
        );
        return;
      }
      navigator.clipboard
        .read()
        .then(items => {
          if (!items || items.length === 0) {
            completeAsyncText(
              "web_complete_async_clipboard_read_image",
              requestId,
              false,
              "clipboard contains no items",
            );
            return;
          }
          const item = items[0];
          const pngType = "image/png";
          if (!item.types.includes(pngType)) {
            completeAsyncText(
              "web_complete_async_clipboard_read_image",
              requestId,
              false,
              "clipboard item does not contain PNG image",
            );
            return;
          }
          item
            .getType(pngType)
            .then(blob => {
              const reader = new FileReader();
              reader.onload = () => {
                const result = reader.result;
                const base64 = result.split(",")[1] || "";
                completeAsyncText(
                  "web_complete_async_clipboard_read_image",
                  requestId,
                  true,
                  base64,
                );
              };
              reader.onerror = () => {
                completeAsyncText(
                  "web_complete_async_clipboard_read_image",
                  requestId,
                  false,
                  "failed to read image blob",
                );
              };
              reader.readAsDataURL(blob);
            })
            .catch(error => {
              completeAsyncText(
                "web_complete_async_clipboard_read_image",
                requestId,
                false,
                asyncFailureMessage(error, "failed to read clipboard image"),
              );
            });
        })
        .catch(error => {
          completeAsyncText(
            "web_complete_async_clipboard_read_image",
            requestId,
            false,
            asyncFailureMessage(error, "clipboard image read failed"),
          );
        });
    },
    clipboard_write_image(data) {
      const base64 = stringValue(data);
      if (!base64) {
        return false;
      }
      if (!navigator.clipboard?.write) {
        return false;
      }
      const binary = base64ToUint8Array(base64);
      if (!binary) {
        return false;
      }
      const blob = new Blob([binary], { type: "image/png" });
      navigator.clipboard
        .write([new ClipboardItem({ "image/png": blob })])
        .then(() => {})
        .catch(() => {});
      return true;
    },
    file_dialog_open_async(requestId, kind, title, filters, defaultName) {
      const complete = (ok, value) =>
        completeAsyncText(
          "web_complete_async_file_dialog",
          requestId,
          ok,
          value,
        );
      const dialogKind = kind | 0;
      const accept = filterListToAccept(stringValue(filters));
      const suggestedName = stringValue(defaultName);
      if (dialogKind === 0 && globalThis.showOpenFilePicker) {
        const options = { multiple: false };
        const types = filePickerTypes(accept);
        if (types) {
          options.types = types;
        }
        globalThis
          .showOpenFilePicker(options)
          .then(handles => {
            const handle = handles?.[0];
            if (!handle) {
              complete(true, "");
              return;
            }
            const path = registerFileHandle(handle, handle.name || suggestedName);
            return handle
              .getFile()
              .then(file => file.text())
              .then(text => completeAsyncFileOpenText(requestId, true, path, text));
          })
          .catch(error => {
            if (error?.name === "AbortError") {
              complete(true, "");
            } else {
              completeAsyncFileOpenText(
                requestId,
                false,
                "",
                asyncFailureMessage(error, "file dialog failed"),
              );
            }
          });
        return;
      }
      if (dialogKind === 1 && globalThis.showSaveFilePicker) {
        const options = { suggestedName: suggestedName || undefined };
        const types = filePickerTypes(accept);
        if (types) {
          options.types = types;
        }
        globalThis
          .showSaveFilePicker(options)
          .then(handle => {
            const path = registerFileHandle(handle, suggestedName);
            complete(true, path);
          })
          .catch(error => {
            if (error?.name === "AbortError") {
              complete(true, "");
            } else {
              complete(false, asyncFailureMessage(error, "file dialog failed"));
            }
          });
        return;
      }
      if (dialogKind === 1) {
        complete(false, "save file dialog is unavailable on this browser");
        return;
      }
      const input = document.createElement("input");
      input.type = "file";
      input.style.position = "fixed";
      input.style.left = "-10000px";
      input.style.top = "0";
      input.style.width = "1px";
      input.style.height = "1px";
      input.style.opacity = "0";
      input.style.pointerEvents = "none";
      if (accept) {
        input.accept = accept;
      }
      if (dialogKind === 2) {
        input.webkitdirectory = true;
        input.directory = true;
      }
      document.body.appendChild(input);
      let completed = false;
      const finish = (ok, value) => {
        if (completed) return;
        completed = true;
        input.remove();
        complete(ok, value);
      };
      const finishOpenFile = file => {
        if (completed) return;
        if (!file) {
          finish(true, "");
          return;
        }
        completed = true;
        input.remove();
        const path = file.webkitRelativePath || file.name || suggestedName || "untitled.md";
        file.text()
          .then(text => completeAsyncFileOpenText(requestId, true, path, text))
          .catch(error => {
            completeAsyncFileOpenText(
              requestId,
              false,
              path,
              asyncFailureMessage(error, "file read failed"),
            );
          });
      };
      input.addEventListener("change", () => {
        if (dialogKind === 0) {
          finishOpenFile(input.files?.[0] ?? null);
        } else {
          finish(true, fileListNames(input.files));
        }
      }, { once: true });
      globalThis.window?.addEventListener?.("focus", () => {
        setTimeout(() => {
          if (!completed && (!input.files || input.files.length === 0)) {
            finish(true, "");
          }
        }, 0);
      }, { once: true });
      try {
        input.click();
      } catch (error) {
        finish(false, asyncFailureMessage(error, "file dialog failed"));
      }
    },
    text_file_write_async(requestId, path, text) {
      const targetPath = stringValue(path);
      const value = stringValue(text);
      const handle = fileHandles.get(targetPath);
      if (!handle?.createWritable) {
        completeAsyncText(
          "web_complete_async_text_file_write",
          requestId,
          false,
          "no writable browser file handle for " + (targetPath || "selected file"),
        );
        return;
      }
      handle
        .createWritable()
        .then(writable =>
          writable
            .write(value)
            .then(() => writable.close())
        )
        .then(() => {
          completeAsyncText(
            "web_complete_async_text_file_write",
            requestId,
            true,
            targetPath,
          );
        })
        .catch(error => {
          completeAsyncText(
            "web_complete_async_text_file_write",
            requestId,
            false,
            asyncFailureMessage(error, "text file write failed"),
          );
        });
    },
    text_file_read_async(requestId, path) {
      const targetPath = stringValue(path);
      if (!targetPath) {
        completeAsyncText(
          "web_complete_async_text_file_read",
          requestId,
          false,
          "text file path is empty",
        );
        return;
      }
      let url;
      try {
        url = new URL(
          targetPath,
          document?.baseURI || globalThis.location?.href || "http://localhost/",
        );
      } catch (error) {
        completeAsyncText(
          "web_complete_async_text_file_read",
          requestId,
          false,
          asyncFailureMessage(error, "invalid text file URL"),
        );
        return;
      }
      if (globalThis.location?.origin && url.origin !== globalThis.location.origin) {
        completeAsyncText(
          "web_complete_async_text_file_read",
          requestId,
          false,
          "text file fetch must stay on the current origin",
        );
        return;
      }
      fetch(url, { credentials: "same-origin" })
        .then(response => {
          if (!response.ok) {
            throw new Error(
              `failed to fetch text file ${targetPath}: ${response.status} ${response.statusText}`,
            );
          }
          return response.text();
        })
        .then(text => {
          completeAsyncText(
            "web_complete_async_text_file_read",
            requestId,
            true,
            text,
          );
        })
        .catch(error => {
          completeAsyncText(
            "web_complete_async_text_file_read",
            requestId,
            false,
            asyncFailureMessage(error, "text file fetch failed"),
          );
        });
    },
    open_url(url) {
      const href = stringValue(url);
      if (!href || !globalThis.window?.open) {
        return false;
      }
      const opened = globalThis.window.open(href, "_blank", "noopener,noreferrer");
      if (opened) {
        try {
          opened.opener = null;
        } catch {
          // Some browsers expose a read-only opener for noopener windows.
        }
        return true;
      }
      return false;
    },
    settings_read(key) {
      try {
        const value = globalThis.localStorage?.getItem(
          `wzzc-dev.moui.${stringValue(key)}`,
        );
        return createStringHandle(value ?? "");
      } catch {
        return createStringHandle("");
      }
    },
    settings_has_value(key) {
      try {
        return globalThis.localStorage?.getItem(
          `wzzc-dev.moui.${stringValue(key)}`,
        ) != null;
      } catch {
        return false;
      }
    },
    settings_write(key, value) {
      try {
        globalThis.localStorage?.setItem(
          `wzzc-dev.moui.${stringValue(key)}`,
          stringValue(value),
        );
        return globalThis.localStorage != null;
      } catch {
        return false;
      }
    },
    settings_remove(key) {
      try {
        globalThis.localStorage?.removeItem(`wzzc-dev.moui.${stringValue(key)}`);
        return globalThis.localStorage != null;
      } catch {
        return false;
      }
    },
    device_pixel_ratio() {
      return globalThis.window?.devicePixelRatio || 1.0;
    },
    now_ms() {
      return BigInt(Math.round(globalThis.performance?.now?.() ?? Date.now()));
    },
    schedule_animation_frame() {
      const raf =
        globalThis.requestAnimationFrame ??
        globalThis.window?.requestAnimationFrame ??
        (callback => setTimeout(callback, 16));
      raf(() => emit(1));
    },
    schedule_timeout(delayMs) {
      setTimeout(() => emit(2), Math.max(0, delayMs | 0));
    },
    wall_clock_year() {
      return new Date().getFullYear();
    },
    wall_clock_month() {
      return new Date().getMonth() + 1;
    },
    wall_clock_day() {
      return new Date().getDate();
    },
    wall_clock_weekday() {
      return new Date().getDay();
    },
    wall_clock_hour() {
      return new Date().getHours();
    },
    wall_clock_minute() {
      return new Date().getMinutes();
    },
    wall_clock_second() {
      return new Date().getSeconds();
    },
    schedule_microtask() {
      const microtask =
        globalThis.queueMicrotask ??
        (callback => Promise.resolve().then(callback));
      microtask(() => emit(3));
    },
    set_dispatch_event(fn) {
      dispatchEvent = fn;
    },
    set_dispatch_pointer_input(fn) {
      dispatchPointerInput = typeof fn === "function" ? fn : null;
    },
    set_route_dispatch(fn) {
      dispatchRoute = typeof fn === "function" ? fn : null;
      if (dispatchRoute) {
        installRouteListener();
      }
    },
    set_wasm_exports(exports) {
      wasmExports = exports;
      semantics.setDispatch((rawId, nodeId, generation, actionCode, value, directionCode) => {
        const dispatch = wasmExports?.web_dispatch_semantics_action;
        if (typeof dispatch !== "function") return;
        const nodeIdTextId = nextEventTextId++;
        const generationTextId = nextEventTextId++;
        const valueId = value ? nextEventTextId++ : 0;
        eventTexts.set(nodeIdTextId, `${nodeId}`);
        eventTexts.set(generationTextId, `${generation}`);
        if (valueId) eventTexts.set(valueId, value);
        try {
          dispatch(
            rawId,
            nodeIdTextId,
            generationTextId,
            actionCode,
            valueId,
            directionCode | 0,
          );
        } finally {
          eventTexts.delete(nodeIdTextId);
          eventTexts.delete(generationTextId);
          if (valueId) eventTexts.delete(valueId);
        }
      });
    },
    sync_semantics(rawId, canvasId, json) {
      const canvas = globalThis.document?.getElementById?.(stringValue(canvasId));
      if (!(canvas instanceof globalThis.HTMLCanvasElement)) return;
      try {
        const update = JSON.parse(stringValue(json));
        globalThis.__mouiAccessibilitySemanticsEvidence ??= [];
        globalThis.__mouiAccessibilitySemanticsEvidence.push({
          rawId,
          kind: update.kind,
          generation: `${update.generation ?? ""}`,
          root: `${update.root ?? ""}`,
          focused: `${update.focused ?? ""}`,
          semanticFocused: `${update.semantic_focused ?? ""}`,
          nodes: (update.nodes ?? []).map(node => ({
            node_id: `${node.node_id ?? ""}`,
            semantic_id: node.semantic_id ?? "",
            role: node.role ?? "",
          })),
          removed: (update.removed ?? []).map(id => `${id}`),
        });
        semantics.sync(rawId, canvas, update);
      } catch (error) {
        globalThis.console?.error?.("MoUI semantics synchronization failed", error);
      }
    },
    remove_semantics(rawId) {
      semantics.remove(rawId);
    },
    record_semantics_action(rawId, json) {
      try {
        const evidence = JSON.parse(stringValue(json));
        const event = {
          name: "accessibility_action",
          source: "runtime-receipt",
          rawId,
          ...evidence,
        };
        globalThis.__mouiAccessibilityActionEvidence ??= [];
        globalThis.__mouiAccessibilityActionEvidence.push(event);
        observeEvent(event);
      } catch (error) {
        globalThis.console?.error?.("MoUI semantics action evidence failed", error);
      }
    },
    update_document_metadata(json) {
      try {
        updateDocumentMetadata(JSON.parse(stringValue(json)));
      } catch (error) {
        globalThis.console?.error?.("MoUI document metadata update failed", error);
      }
    },
    history_current_route() {
      return createStringHandle(currentBrowserRoute());
    },
    history_push_route(route) {
      const normalized = normalizeRouteString(stringValue(route));
      globalThis.window?.history?.pushState?.({ mouiRoute: normalized }, "", routeUrl(normalized));
      emitRoute(2, normalized);
    },
    history_replace_route(route) {
      const normalized = normalizeRouteString(stringValue(route));
      globalThis.window?.history?.replaceState?.({ mouiRoute: normalized }, "", routeUrl(normalized));
      emitRoute(3, normalized);
    },
    history_back() {
      globalThis.window?.history?.back?.();
    },
    history_forward() {
      globalThis.window?.history?.forward?.();
    },
    history_dispatch_current(source = 0) {
      emitRoute(source | 0);
    },
    install_canvas_events(rawId, handle) {
      const canvas = canvasValue(handle);
      if (!canvas) return;
      const handlers = [];
      const textInput = createHiddenTextInput(canvas);
      const textState = {
        input: textInput,
        canvas,
        imeAllowed: false,
        surroundingText: "",
        surroundingCursor: 0,
        surroundingAnchor: 0,
      };
      textInputs.set(rawId, textState);
      let composing = false;
      let compositionText = "";
      let suppressNextInputText = "";
      let suppressNextInputUntil = 0;
      const inputTarget = canvas.parentElement ?? canvas;
      const hostOwnsFocus = target =>
        target === canvas ||
        target === textInput ||
        (typeof Node !== "undefined" &&
          target instanceof Node &&
          inputTarget.contains(target));
      const add = (target, type, handler, options) => {
        target.addEventListener(type, handler, options);
        handlers.push([target, type, handler, options]);
      };
      const hostHasFocus = () => hostOwnsFocus(document.activeElement);
      const acceptFileDrag = event => {
        preventDefaultIfCancelable(event);
        if (event.dataTransfer) {
          event.dataTransfer.dropEffect = "copy";
        }
      };
      const emitFileDrag = (kind, event, includeFiles = false) => {
        acceptFileDrag(event);
        const p = pointerPosition(canvas, event);
        emit(kind, rawId, Math.round(p.x), Math.round(p.y), 0, includeFiles ? draggedFileNames(event) : "");
      };
      const blurTargetIsHost = event => hostOwnsFocus(event.relatedTarget);
      const emitBlurIfOutsideHost = event => {
        if (blurTargetIsHost(event)) return;
        queueMicrotask(() => {
          if (!hostHasFocus()) {
            emit(12, rawId);
          }
        });
      };
      const focusInputTarget = () => {
        if (textState.imeAllowed) {
          scheduleTextInputFocus(textState);
        } else {
          focusWithoutScroll(canvas);
        }
      };
      const inputRouter = new CanvasInputRouter({
        canvas,
        host: inputTarget,
        rawId,
        position: pointerPosition,
        dispatchPointer: (
          kind,
          xPx,
          yPx,
          deltaXPx,
          deltaYPx,
          button,
          modifiers,
        ) => emitPointerInput(
          rawId,
          kind,
          xPx,
          yPx,
          deltaXPx,
          deltaYPx,
          button,
          modifiers,
        ),
        lineHeight: () => {
          const lineHeight = Number.parseFloat(
            globalThis.getComputedStyle?.(inputTarget)?.lineHeight ?? "",
          );
          return Number.isFinite(lineHeight) ? lineHeight : 16;
        },
        pageHeight: () => inputTarget.getBoundingClientRect?.().height || inputTarget.clientHeight || 1,
        scaleDelta: (_event, delta) => {
          const rect = canvas.getBoundingClientRect();
          return {
            x: delta.x * (rect.width > 0 ? canvas.width / rect.width : devicePixelRatio()),
            y: delta.y * (rect.height > 0 ? canvas.height / rect.height : devicePixelRatio()),
          };
        },
      });
      const addInput = (type, handler, options = {}) => {
        add(inputTarget, type, handler, { ...options, capture: true });
      };
      const handled = flags => (flags & WEB_INPUT_FLAGS.handled) !== 0;
      addInput("pointermove", event => {
        const flags = inputRouter.pointerMove(event);
        if (event.pointerType === "touch" && handled(flags)) {
          preventDefaultIfCancelable(event);
        }
      });
      addInput("pointerdown", event => {
        // Establish host focus before Down. A browser may synchronously move
        // focus into the semantics layer while handling the native click;
        // that transition must not cancel the capture that Down creates.
        if (!inputRouter.shouldRoute(event)) return;
        focusInputTarget();
        const flags = inputRouter.pointerDown(event);
        if (handled(flags)) {
          preventDefaultIfCancelable(event);
        }
      });
      addInput("pointerup", event => {
        const flags = inputRouter.pointerUp(event);
        if (handled(flags)) {
          preventDefaultIfCancelable(event);
          focusInputTarget();
        }
      });
      addInput("pointercancel", event => {
        const flags = inputRouter.pointerUp(event, true);
        if (handled(flags)) preventDefaultIfCancelable(event);
      });
      addInput("pointerout", event => {
        inputRouter.pointerExit(event);
      });
      addInput("wheel", event => {
        if (!inputRouter.shouldRoute(event)) return;
        // Ctrl/Meta wheel belongs to browser zoom, even when a canvas view
        // would otherwise consume the delta.
        if (event.ctrlKey || event.metaKey) return;
        if (handled(inputRouter.wheel(event))) preventDefaultIfCancelable(event);
      }, { passive: false });
      addInput("dragenter", event => emitFileDrag(60, event, true));
      addInput("dragover", event => emitFileDrag(61, event));
      addInput("drop", event => emitFileDrag(62, event, true));
      addInput("dragleave", event => emitFileDrag(63, event));
      add(canvas, "focus", () => emit(11, rawId));
      add(canvas, "blur", emitBlurIfOutsideHost);
      add(canvas, "keydown", event => {
        if (textState.imeAllowed) {
          if (document.activeElement !== textInput) {
            scheduleTextInputFocus(textState);
            if (!event.isComposing && isPlainTextKey(event)) {
              event.preventDefault();
              emit(42, rawId, 0, 0, 0, event.key);
              return;
            }
          }
          if (event.isComposing || !shouldForwardRuntimeKey(event)) {
            return;
          }
          event.preventDefault();
        }
        emit(40, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(canvas, "keyup", event => {
        if (
          textState.imeAllowed &&
          (event.isComposing || !shouldForwardRuntimeKey(event))
        ) {
          return;
        }
        emit(41, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "keydown", event => {
        if (event.isComposing || !shouldForwardRuntimeKey(event)) {
          return;
        }
        event.preventDefault();
        emit(40, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "keyup", event => {
        if (event.isComposing || !shouldForwardRuntimeKey(event)) {
          return;
        }
        emit(41, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "focus", () => emit(11, rawId));
      add(textInput, "blur", emitBlurIfOutsideHost);
      add(textInput, "compositionstart", () => {
        composing = true;
        compositionText = "";
        suppressNextInputText = "";
        suppressNextInputUntil = 0;
        emit(43, rawId);
      });
      add(textInput, "compositionupdate", event => {
        const text = event.data || "";
        compositionText = text;
        emit(44, rawId, 0, text.length, 0, text);
      });
      add(textInput, "compositionend", event => {
        composing = false;
        const text = event.data || "";
        compositionText = text;
        suppressNextInputText = text;
        suppressNextInputUntil = text ? Date.now() + 250 : 0;
        emit(42, rawId, 0, 0, 0, text);
        textInput.value = "";
      });
      add(textInput, "beforeinput", event => {
        if (event.isComposing || composing) {
          return;
        }
        if (event.inputType === "deleteContentBackward") {
          event.preventDefault();
          emit(45, rawId, 1, 0);
        } else if (event.inputType === "deleteContentForward") {
          event.preventDefault();
          emit(45, rawId, 0, 1);
        }
      });
      add(textInput, "input", event => {
        const now = Date.now();
        if (!composing && now > suppressNextInputUntil) {
          compositionText = "";
          suppressNextInputText = "";
          suppressNextInputUntil = 0;
        }
        const data = inputEventData(event);
        const inputType = event.inputType || "";
        const composingInput =
          event.isComposing ||
          composing ||
          inputType === "insertCompositionText" ||
          inputType === "deleteCompositionText";
        if (composingInput) {
          return;
        }
        const suppressingCompositionInput =
          inputType === "insertFromComposition" && suppressNextInputText;
        const suppressingCompositionFragment =
          compositionText &&
          (composing || now <= suppressNextInputUntil) &&
          (data === compositionText || compositionText.endsWith(data));
        const suppressingDuplicateCommit =
          suppressNextInputText &&
          now <= suppressNextInputUntil &&
          (data === suppressNextInputText || suppressNextInputText.endsWith(data));
        if (
          !composing &&
          data &&
          !suppressingCompositionInput &&
          !suppressingCompositionFragment &&
          !suppressingDuplicateCommit
        ) {
          emit(42, rawId, 0, 0, 0, data);
        }
        if (suppressingDuplicateCommit || now > suppressNextInputUntil) {
          suppressNextInputText = "";
          suppressNextInputUntil = 0;
        }
        if (!composing && now > suppressNextInputUntil) {
          compositionText = "";
        }
        textInput.value = "";
      });
      const emitResize = () => {
        resizeCanvasToHost(canvas);
        emit(
          10,
          rawId,
          physicalCanvasWidth(canvas),
          physicalCanvasHeight(canvas),
          devicePixelRatio(),
        );
      };
      add(window, "resize", emitResize);
      const media = window.matchMedia?.("(prefers-color-scheme: dark)");
      if (media) {
        add(media, "change", event => emit(50, rawId, event.matches ? 1 : 0));
      }
      listeners.set(rawId, handlers);
    },
    install_platform_canvas_events(rawId, handle, platformViewId) {
      const canvas = canvasValue(handle);
      if (!canvas || platformCanvasListeners.has(canvas)) return;
      const id = stringValue(platformViewId);
      const inputTarget = canvas.parentElement ?? canvas;
      const handlers = [];
      const activePointers = new Set();
      let focused = false;
      const add = (type, handler, options = {}) => {
        const listenerOptions = { ...options, capture: true };
        inputTarget.addEventListener(type, handler, listenerOptions);
        handlers.push([inputTarget, type, handler, listenerOptions]);
      };
      const point = event => {
        const rect = canvas.getBoundingClientRect();
        return {
          x: (Number(event.clientX) || 0) - rect.left,
          y: (Number(event.clientY) || 0) - rect.top,
          inside:
            (Number(event.clientX) || 0) >= rect.left &&
            (Number(event.clientX) || 0) <= rect.right &&
            (Number(event.clientY) || 0) >= rect.top &&
            (Number(event.clientY) || 0) <= rect.bottom,
        };
      };
      const pointerValue = current => `${current.x.toFixed(3)},${current.y.toFixed(3)}`;
      add("pointerdown", event => {
        const current = point(event);
        if (!current.inside || event.defaultPrevented) {
          if (focused && !current.inside) {
            focused = false;
            emitPlatformView(rawId, id, "focus", "", "", false);
          }
          return;
        }
        activePointers.add(Number(event.pointerId) || 1);
        if (!focused) {
          focused = true;
          emitPlatformView(rawId, id, "focus", "", "", true);
        }
        emitPlatformView(rawId, id, "pointer_down", pointerValue(current));
        preventDefaultIfCancelable(event);
      });
      add("pointermove", event => {
        const current = point(event);
        const pointerId = Number(event.pointerId) || 1;
        if (!activePointers.has(pointerId) && (!current.inside || event.defaultPrevented)) {
          return;
        }
        emitPlatformView(rawId, id, "pointer_move", pointerValue(current));
        if (activePointers.has(pointerId)) preventDefaultIfCancelable(event);
      });
      const finishPointer = event => {
        const pointerId = Number(event.pointerId) || 1;
        if (!activePointers.has(pointerId)) return;
        activePointers.delete(pointerId);
        emitPlatformView(rawId, id, "pointer_up", pointerValue(point(event)));
        preventDefaultIfCancelable(event);
      };
      add("pointerup", finishPointer);
      add("pointercancel", finishPointer);
      add("wheel", event => {
        const current = point(event);
        if (!current.inside || event.defaultPrevented || event.ctrlKey || event.metaKey) {
          return;
        }
        emitPlatformView(rawId, id, "wheel", `${Number(event.deltaY) || 0}`);
        preventDefaultIfCancelable(event);
      }, { passive: false });
      canvas.style.pointerEvents = "none";
      platformCanvasListeners.set(canvas, handlers);
    },
    remove_platform_canvas_events(_rawId, handle) {
      const canvas = canvasValue(handle);
      const handlers = platformCanvasListeners.get(canvas) || [];
      for (const [target, type, handler, options] of handlers) {
        target.removeEventListener(type, handler, options);
      }
      platformCanvasListeners.delete(canvas);
    },
    remove_canvas_events(rawId) {
      const handlers = listeners.get(rawId) || [];
      for (const [target, type, handler, options] of handlers) {
        target.removeEventListener(type, handler, options);
      }
      listeners.delete(rawId);
      textInputs.get(rawId)?.input?.remove?.();
      textInputs.delete(rawId);
    },
    set_ime_allowed(rawId, allowed) {
      const state = textInputs.get(rawId);
      if (!state) return;
      state.imeAllowed = !!allowed;
      if (state.imeAllowed) {
        scheduleTextInputFocus(state);
      } else {
        state.input.value = "";
        state.input.style.left = "-10000px";
        state.input.style.top = "0";
        if (document.activeElement === state.input) {
          focusWithoutScroll(state.canvas);
        }
      }
    },
    set_ime_cursor_area(rawId, x, y, width, height) {
      const state = textInputs.get(rawId);
      if (!state) return;
      const left = Number.isFinite(x) ? x : 0;
      const top = Number.isFinite(y) ? y : 0;
      const resolvedWidth = Math.max(1, Math.round(width || 1));
      const resolvedHeight = Math.max(1, Math.round(height || 1));
      state.input.style.left = `${left}px`;
      state.input.style.top = `${top}px`;
      state.input.style.width = `${resolvedWidth}px`;
      state.input.style.height = `${resolvedHeight}px`;
      observeEvent({
        kind: 46,
        name: "ime_candidate_anchor",
        rawId: rawId | 0,
        x: left,
        y: top,
        width: resolvedWidth,
        height: resolvedHeight,
        at: Number(globalThis.performance?.now?.() ?? Date.now()),
      });
    },
    set_ime_surrounding_text(rawId, text, cursor, anchor) {
      const state = textInputs.get(rawId);
      if (!state) return;
      state.surroundingText = stringValue(text);
      state.surroundingCursor = cursor | 0;
      state.surroundingAnchor = anchor | 0;
      observeEvent({
        kind: 47,
        name: "ime_surrounding_text",
        rawId: rawId | 0,
        text: state.surroundingText,
        cursor: state.surroundingCursor,
        anchor: state.surroundingAnchor,
        at: Number(globalThis.performance?.now?.() ?? Date.now()),
      });
    },
    focus_canvas(rawId) {
      const state = textInputs.get(rawId);
      const canvas = state?.canvas ?? null;
      if (canvas && typeof canvas.focus === "function") {
        try {
          canvas.focus({ preventScroll: true });
        } catch (_) {
          canvas.focus();
        }
      }
    },
    set_canvas_fullscreen(rawId, fullscreen) {
      const state = textInputs.get(rawId);
      const canvas = state?.canvas ?? null;
      if (!canvas) return;
      if (fullscreen) {
        if (document.fullscreenElement !== canvas && canvas.requestFullscreen) {
          const promise = canvas.requestFullscreen();
          if (promise && typeof promise.catch === "function") promise.catch(() => {});
        }
      } else if (document.fullscreenElement && document.exitFullscreen) {
        const promise = document.exitFullscreen();
        if (promise && typeof promise.catch === "function") promise.catch(() => {});
      }
    },
    system_theme() {
      return globalThis.window?.matchMedia?.("(prefers-color-scheme: dark)")
        .matches ? 1 : 0;
    },
    accessibility_settings() {
      const root = globalThis.document?.documentElement;
      const contrast = globalThis.window?.matchMedia?.("(prefers-contrast: more)")?.matches;
      const reducedMotion = globalThis.window?.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
      const scale = Number.parseFloat(root?.style?.fontSize || "") || 1;
      return { contrast: contrast ? 1 : 0, reducedMotion: reducedMotion ? 1 : 0, textScale: scale };
    },
    accessibility_contrast() {
      return globalThis.window?.matchMedia?.("(prefers-contrast: more)")?.matches ? 1 : 0;
    },
    reduced_motion() {
      return globalThis.window?.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ? 1 : 0;
    },
    text_scale() {
      const root = globalThis.document?.documentElement;
      const size = Number.parseFloat(globalThis.window?.getComputedStyle?.(root)?.fontSize || "16");
      return Number.isFinite(size) && size > 0 ? size / 16 : 1;
    },
  };
}

export function connectWindowWeb(instance, imports) {
  const dispatch = instance?.exports?.web_dispatch_event;
  if (typeof dispatch !== "function") {
    throw new Error("MoonBit wasm module must export web_dispatch_event");
  }
  imports.set_dispatch_event(dispatch);
  const dispatchPointerInput = instance?.exports?.web_dispatch_pointer_input;
  if (typeof dispatchPointerInput !== "function") {
    throw new Error("MoonBit wasm module must export web_dispatch_pointer_input");
  }
  imports.set_dispatch_pointer_input?.(dispatchPointerInput);
  const routeDispatch = instance?.exports?.web_dispatch_route;
  if (typeof routeDispatch === "function") {
    imports.set_route_dispatch?.(routeDispatch);
  }
  imports.set_wasm_exports?.(instance.exports);
  return instance;
}
