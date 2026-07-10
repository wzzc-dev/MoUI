const ACTION_CODES = new Map([
  ["activate", 0],
  ["focus", 1],
  ["set-text", 2],
  ["submit", 3],
  ["scroll", 4],
  ["select", 5],
  ["expand", 6],
  ["collapse", 7],
  ["dismiss", 8],
]);

const BOOLEAN_ARIA = ["selected", "expanded", "invalid", "required", "disabled"];

const semanticTag = node => {
  switch (node.role) {
    case "link": return "a";
    case "heading": return `h${Math.min(6, Math.max(1, Number(node.level) || 1))}`;
    case "navigation": return "nav";
    case "main": return "main";
    case "button": return "button";
    case "textbox": return "input";
    default: return "div";
  }
};

const setOptionalAttribute = (element, name, value) => {
  if (value === undefined || value === null || value === "") {
    element.removeAttribute(name);
  } else {
    element.setAttribute(name, `${value}`);
  }
};

const focusableActions = actions =>
  actions.includes("focus") || actions.includes("activate") || actions.includes("set-text");

const actionForActivation = actions => {
  for (const action of ["activate", "submit", "select", "expand", "collapse", "dismiss"]) {
    if (actions.includes(action)) return action;
  }
  return undefined;
};

export function createSemanticsDomManager(options = {}) {
  const documentRef = options.document ?? globalThis.document;
  const layers = new Map();
  let dispatch = typeof options.dispatch === "function" ? options.dispatch : () => {};

  const createLayer = (rawId, canvas) => {
    const layer = documentRef.createElement("div");
    layer.className = "moui-semantics-layer";
    layer.dataset.mouiWindowId = `${rawId}`;
    layer.style.position = "absolute";
    layer.style.inset = "0";
    layer.style.pointerEvents = "none";
    layer.style.overflow = "hidden";
    layer.style.zIndex = "2";
    const host = canvas.parentElement ?? documentRef.body;
    if (globalThis.getComputedStyle?.(host)?.position === "static") {
      host.style.position = "relative";
    }
    host.appendChild(layer);
    const state = { rawId, canvas, layer, elements: new Map() };
    layers.set(rawId, state);
    return state;
  };

  const dispatchAction = (state, node, action, value = "") => {
    const code = ACTION_CODES.get(action);
    if (code === undefined) return;
    dispatch(state.rawId, Number(node.element_id?.value ?? node.element_id ?? 0), code, `${value ?? ""}`);
  };

  const installHandlers = (state, record) => {
    const { element } = record;
    element.addEventListener("focus", () => {
      const node = record.node;
      if (node?.actions?.includes("focus")) dispatchAction(state, node, "focus");
    });
    element.addEventListener("click", event => {
      const node = record.node;
      const action = actionForActivation(node?.actions ?? []);
      if (action) {
        event.preventDefault();
        dispatchAction(state, node, action);
      }
    });
    element.addEventListener("keydown", event => {
      if (event.key !== "Enter" && event.key !== " ") return;
      const node = record.node;
      const action = actionForActivation(node?.actions ?? []);
      if (action) {
        event.preventDefault();
        dispatchAction(state, node, action);
      }
    });
    element.addEventListener("input", event => {
      const node = record.node;
      if (node?.actions?.includes("set-text")) {
        dispatchAction(state, node, "set-text", event.currentTarget?.value ?? "");
      }
    });
  };

  const updateElement = (state, record, node, parentFrame) => {
    record.node = node;
    const { element } = record;
    const frame = node.frame ?? {};
    const origin = frame.origin ?? {};
    const size = frame.size ?? {};
    element.style.position = "absolute";
    element.style.left = `${(Number(origin.x) || 0) - (Number(parentFrame?.x) || 0)}px`;
    element.style.top = `${(Number(origin.y) || 0) - (Number(parentFrame?.y) || 0)}px`;
    element.style.width = `${Math.max(0, Number(size.width) || 0)}px`;
    element.style.height = `${Math.max(0, Number(size.height) || 0)}px`;
    element.style.opacity = "0.001";
    element.style.color = "transparent";
    element.style.background = "transparent";
    element.style.border = "0";
    element.style.padding = "0";
    element.style.margin = "0";
    element.style.pointerEvents = "none";
    setOptionalAttribute(element, "role", node.role === "presentation" ? "none" : node.role);
    setOptionalAttribute(element, "aria-label", node.label);
    setOptionalAttribute(element, "aria-description", node.description);
    setOptionalAttribute(element, "aria-level", node.role === "heading" ? node.level : undefined);
    setOptionalAttribute(element, "href", node.role === "link" ? node.url : undefined);
    setOptionalAttribute(element, "aria-checked", node.checked);
    for (const name of BOOLEAN_ARIA) {
      const value = node[name];
      setOptionalAttribute(element, name === "disabled" ? "aria-disabled" : `aria-${name}`, value ? "true" : undefined);
    }
    const tabIndex = node.disabled ? -1 : (focusableActions(node.actions ?? []) ? 0 : -1);
    element.tabIndex = tabIndex;
    if (node.role === "textbox") {
      element.value = node.value ?? "";
      element.setAttribute("autocomplete", "off");
    } else {
      element.textContent = node.label || node.value || "";
    }
    if (node.focused && documentRef.activeElement !== element) {
      element.focus({ preventScroll: true });
    }
  };

  const visit = (state, node, parent, parentFrame, seen) => {
    const id = `${node.element_id?.value ?? node.element_id ?? 0}`;
    seen.add(id);
    let record = state.elements.get(id);
    const tag = semanticTag(node);
    if (!record || record.element.tagName.toLowerCase() !== tag) {
      record?.element.remove();
      const element = documentRef.createElement(tag);
      element.dataset.mouiElementId = id;
      record = { element, node };
      state.elements.set(id, record);
      installHandlers(state, record);
    }
    if (record.element.parentElement !== parent) parent.appendChild(record.element);
    updateElement(state, record, node, parentFrame);
    const origin = node.frame?.origin ?? {};
    const nodeFrame = { x: Number(origin.x) || 0, y: Number(origin.y) || 0 };
    for (const child of node.children ?? []) {
      visit(state, child, record.element, nodeFrame, seen);
    }
  };

  return {
    setDispatch(next) {
      dispatch = typeof next === "function" ? next : () => {};
    },
    sync(rawId, canvas, root) {
      if (!documentRef || !canvas || !root) return;
      const state = layers.get(rawId) ?? createLayer(rawId, canvas);
      const seen = new Set();
      visit(state, root, state.layer, { x: 0, y: 0 }, seen);
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
