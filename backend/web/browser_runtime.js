// Browser host runtime for MoUI's canonical wasm-gc web backend.
//
// This file is the stable browser asset boundary for `backend/web`.
// It provides the `window_web` import object expected by the MoonBit
// `Milky2018/window/web` package without exposing the dependency checkout path
// such as `.local_repos/window/web/runtime.js` to the browser.

export function createWindowWebImports(options = {}) {
  const canvases = new Map();
  const listeners = new Map();
  const stringHandles = new Map();
  const eventTexts = new Map();
  let nextCanvasId = 1;
  let nextStringHandle = 1;
  let nextEventTextId = 1;
  let dispatchEvent = null;

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
      } finally {
        eventTexts.delete(textId);
      }
    }
  };

  const createStringHandle = value => {
    const handle = { value: `${value ?? ""}`, offset: 0 };
    const id = nextStringHandle++;
    stringHandles.set(id, handle);
    return id;
  };

  const stringValue = handle => {
    if (typeof handle === "number") {
      return stringHandles.get(handle)?.value ?? "";
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
    const scale = devicePixelRatio();
    return {
      x: Math.round((event.clientX - rect.left) * scale),
      y: Math.round((event.clientY - rect.top) * scale),
    };
  };

  const logicalCanvasWidth = canvas =>
    Math.max(1, Math.round(canvas?.clientWidth || canvas?.width || 1));

  const logicalCanvasHeight = canvas =>
    Math.max(1, Math.round(canvas?.clientHeight || canvas?.height || 1));

  const devicePixelRatio = () => globalThis.window?.devicePixelRatio || 1.0;

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
    set_canvas_cursor(handle, cursor) {
      const canvas = canvasValue(handle);
      if (canvas) {
        canvas.style.cursor = stringValue(cursor) || "default";
      }
    },
    set_document_title(title) {
      document.title = stringValue(title);
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
    schedule_microtask() {
      const microtask =
        globalThis.queueMicrotask ??
        (callback => Promise.resolve().then(callback));
      microtask(() => emit(3));
    },
    set_dispatch_event(fn) {
      dispatchEvent = fn;
    },
    install_canvas_events(rawId, handle) {
      const canvas = canvasValue(handle);
      if (!canvas) return;
      const handlers = [];
      let lastPointerEventAt = 0;
      let lastButtonEventAt = 0;
      const add = (target, type, handler, options) => {
        target.addEventListener(type, handler, options);
        handlers.push([target, type, handler, options]);
      };
      const markPointerEvent = () => {
        lastPointerEventAt = Date.now();
      };
      const markButtonEvent = () => {
        lastButtonEventAt = Date.now();
      };
      const shouldUseMouseFallback = () => Date.now() - lastPointerEventAt > 250;
      const shouldUseClickFallback = () => Date.now() - lastButtonEventAt > 250;
      add(canvas, "pointerenter", event => {
        markPointerEvent();
        const p = pointerPosition(canvas, event);
        emit(20, rawId, p.x, p.y);
      });
      add(canvas, "pointermove", event => {
        markPointerEvent();
        const p = pointerPosition(canvas, event);
        emit(21, rawId, p.x, p.y);
      });
      add(canvas, "pointerleave", event => {
        markPointerEvent();
        const p = pointerPosition(canvas, event);
        emit(22, rawId, p.x, p.y);
      });
      add(canvas, "pointerdown", event => {
        markPointerEvent();
        markButtonEvent();
        canvas.focus();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "pointerup", event => {
        markPointerEvent();
        markButtonEvent();
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
      });
      add(canvas, "mouseenter", event => {
        if (!shouldUseMouseFallback()) return;
        const p = pointerPosition(canvas, event);
        emit(20, rawId, p.x, p.y);
      });
      add(canvas, "mousemove", event => {
        if (!shouldUseMouseFallback()) return;
        const p = pointerPosition(canvas, event);
        emit(21, rawId, p.x, p.y);
      });
      add(canvas, "mouseleave", event => {
        if (!shouldUseMouseFallback()) return;
        const p = pointerPosition(canvas, event);
        emit(22, rawId, p.x, p.y);
      });
      add(canvas, "mousedown", event => {
        if (!shouldUseMouseFallback()) return;
        markButtonEvent();
        canvas.focus();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "mouseup", event => {
        if (!shouldUseMouseFallback()) return;
        markButtonEvent();
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
      });
      add(canvas, "click", event => {
        if (!shouldUseClickFallback()) return;
        markButtonEvent();
        canvas.focus();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
        emit(24, rawId, p.x, p.y, event.button);
      });
      add(canvas, "wheel", event => {
        event.preventDefault();
        emit(30, rawId, Math.round(event.deltaX), Math.round(event.deltaY));
      }, { passive: false });
      add(canvas, "focus", () => emit(11, rawId));
      add(canvas, "blur", () => emit(12, rawId));
      add(canvas, "keydown", event =>
        emit(40, rawId, 0, 0, 0, event.code || event.key || ""),
      );
      add(canvas, "keyup", event =>
        emit(41, rawId, 0, 0, 0, event.code || event.key || ""),
      );
      add(canvas, "input", event =>
        emit(42, rawId, 0, 0, 0, event.data || ""),
      );
      const emitResize = () => {
        resizeCanvasToHost(canvas);
        emit(10, rawId, physicalCanvasWidth(canvas), physicalCanvasHeight(canvas));
      };
      add(window, "resize", emitResize);
      const media = window.matchMedia?.("(prefers-color-scheme: dark)");
      if (media) {
        add(media, "change", event => emit(50, rawId, event.matches ? 1 : 0));
      }
      listeners.set(rawId, handlers);
    },
    remove_canvas_events(rawId) {
      const handlers = listeners.get(rawId) || [];
      for (const [target, type, handler, options] of handlers) {
        target.removeEventListener(type, handler, options);
      }
      listeners.delete(rawId);
    },
    system_theme() {
      return globalThis.window?.matchMedia?.("(prefers-color-scheme: dark)")
        .matches ? 1 : 0;
    },
  };
}

export function connectWindowWeb(instance, imports) {
  const dispatch = instance?.exports?.web_dispatch_event;
  if (typeof dispatch !== "function") {
    throw new Error("MoonBit wasm module must export web_dispatch_event");
  }
  imports.set_dispatch_event(dispatch);
  return instance;
}
