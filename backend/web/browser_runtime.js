// Browser host runtime for MoUI's canonical wasm-gc web backend.
//
// This file is the stable browser asset boundary for `backend/web`.
// It provides the `window_web` import object expected by the MoonBit
// `Milky2018/window/web` package without exposing the dependency checkout path
// such as `.local_repos/window/web/runtime.js` to the browser.

export function createWindowWebImports(options = {}) {
  const canvases = new Map();
  const listeners = new Map();
  const textInputs = new Map();
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

  const createHiddenTextInput = canvas => {
    const input = document.createElement("textarea");
    input.setAttribute("aria-label", "Text input");
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
    set_canvas_cursor(handle, cursor) {
      const canvas = canvasValue(handle);
      if (canvas) {
        canvas.style.cursor = stringValue(cursor) || "default";
      }
    },
    set_document_title(title) {
      document.title = stringValue(title);
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
      const hostHasFocus = () => textInputHostHasFocus(textState);
      const blurTargetIsHost = event =>
        event.relatedTarget === canvas || event.relatedTarget === textInput;
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
        preventDefaultIfCancelable(event);
        focusInputTarget();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "pointerup", event => {
        markPointerEvent();
        markButtonEvent();
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
        focusInputTarget();
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
        preventDefaultIfCancelable(event);
        if (!shouldUseMouseFallback()) return;
        markButtonEvent();
        focusInputTarget();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "mouseup", event => {
        if (!shouldUseMouseFallback()) return;
        markButtonEvent();
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
        focusInputTarget();
      });
      add(canvas, "click", event => {
        preventDefaultIfCancelable(event);
        focusInputTarget();
        if (!shouldUseClickFallback()) return;
        markButtonEvent();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
        emit(24, rawId, p.x, p.y, event.button);
      });
      add(canvas, "wheel", event => {
        event.preventDefault();
        emit(30, rawId, Math.round(event.deltaX), Math.round(event.deltaY));
      }, { passive: false });
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
          if (event.isComposing || !shouldForwardTextInputKey(event)) {
            return;
          }
          event.preventDefault();
        }
        emit(40, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(canvas, "keyup", event => {
        if (
          textState.imeAllowed &&
          (event.isComposing || !shouldForwardTextInputKey(event))
        ) {
          return;
        }
        emit(41, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "keydown", event => {
        if (event.isComposing || !shouldForwardTextInputKey(event)) {
          return;
        }
        event.preventDefault();
        emit(40, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "keyup", event => {
        if (event.isComposing || !shouldForwardTextInputKey(event)) {
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
      state.input.style.left = `${Number.isFinite(x) ? x : 0}px`;
      state.input.style.top = `${Number.isFinite(y) ? y : 0}px`;
      state.input.style.width = `${Math.max(1, Math.round(width || 1))}px`;
      state.input.style.height = `${Math.max(1, Math.round(height || 1))}px`;
    },
    set_ime_surrounding_text(rawId, text, cursor, anchor) {
      const state = textInputs.get(rawId);
      if (!state) return;
      state.surroundingText = stringValue(text);
      state.surroundingCursor = cursor | 0;
      state.surroundingAnchor = anchor | 0;
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
