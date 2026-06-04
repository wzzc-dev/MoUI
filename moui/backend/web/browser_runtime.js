// Browser host runtime for MoUI's canonical wasm-gc web backend.
//
// This file is the stable browser asset boundary for `backend/web`.
// It provides the `window_web` import object expected by the MoonBit
// `wzzc-dev/window/web` package without exposing the dependency checkout path
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
  let wasmExports = null;
  const eventObserver =
    typeof options.onEvent === "function"
      ? options.onEvent
      : globalThis.__mouiWebRuntimeEvidence?.recordEvent?.bind(
          globalThis.__mouiWebRuntimeEvidence,
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
      globalThis.console?.error?.("MoUI Web runtime evidence observer failed", error);
    }
  };

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
      .filter(part => part.startsWith(".") || part.includes("/"))
      .join(",");

  const asyncFailureMessage = (error, fallback) => {
    if (error?.name === "AbortError") {
      return "";
    }
    return `${error?.message || error || fallback}`;
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
      if (dialogKind === 1 && globalThis.showSaveFilePicker) {
        globalThis
          .showSaveFilePicker({
            suggestedName: suggestedName || undefined,
          })
          .then(handle => complete(true, handle?.name || suggestedName || ""))
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
      input.addEventListener("change", () => {
        finish(true, fileListNames(input.files));
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
    set_wasm_exports(exports) {
      wasmExports = exports;
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
      let suppressMouseFallback = null;
      let suppressClickFallback = null;
      const fallbackDedupWindowMs = 250;
      const pointerEventsSupported = typeof globalThis.PointerEvent === "function";
      const add = (target, type, handler, options) => {
        target.addEventListener(type, handler, options);
        handlers.push([target, type, handler, options]);
      };
      const sameEventType = (event, signature) =>
        !!signature && event.type === signature.type;
      const compatibilityMouseType = type => {
        switch (type) {
          case "pointerenter": return "mouseenter";
          case "pointermove": return "mousemove";
          case "pointerleave": return "mouseleave";
          case "pointerdown": return "mousedown";
          case "pointerup": return "mouseup";
          default: return "";
        }
      };
      const markPointerEvent = event => {
        lastPointerEventAt = Date.now();
        const mouseType = compatibilityMouseType(event.type);
        suppressMouseFallback = mouseType
          ? { type: mouseType }
          : null;
      };
      const markButtonEvent = event => {
        lastButtonEventAt = Date.now();
        if (event.type === "pointerup" || event.type === "mouseup") {
          suppressClickFallback = { type: "click" };
        } else if (event.type === "pointerdown" || event.type === "mousedown") {
          suppressClickFallback = null;
        }
      };
      const shouldUseMouseFallback = event => {
        if (sameEventType(event, suppressMouseFallback)) {
          suppressMouseFallback = null;
          return false;
        }
        return Date.now() - lastPointerEventAt > fallbackDedupWindowMs;
      };
      const shouldUseClickFallback = event => {
        if (sameEventType(event, suppressClickFallback)) {
          suppressClickFallback = null;
          return false;
        }
        suppressClickFallback = null;
        return Date.now() - lastButtonEventAt > fallbackDedupWindowMs;
      };
      const hostHasFocus = () => textInputHostHasFocus(textState);
      const acceptFileDrag = event => {
        preventDefaultIfCancelable(event);
        if (event.dataTransfer) {
          event.dataTransfer.dropEffect = "copy";
        }
      };
      const emitFileDrag = (kind, event, includeFiles = false) => {
        acceptFileDrag(event);
        const p = pointerPosition(canvas, event);
        emit(kind, rawId, p.x, p.y, 0, includeFiles ? draggedFileNames(event) : "");
      };
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
        markPointerEvent(event);
        const p = pointerPosition(canvas, event);
        emit(20, rawId, p.x, p.y);
      });
      add(canvas, "pointermove", event => {
        markPointerEvent(event);
        const p = pointerPosition(canvas, event);
        emit(21, rawId, p.x, p.y);
      });
      add(canvas, "pointerleave", event => {
        markPointerEvent(event);
        const p = pointerPosition(canvas, event);
        emit(22, rawId, p.x, p.y);
      });
      add(canvas, "pointerdown", event => {
        markPointerEvent(event);
        markButtonEvent(event);
        preventDefaultIfCancelable(event);
        focusInputTarget();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "pointerup", event => {
        markPointerEvent(event);
        markButtonEvent(event);
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
        focusInputTarget();
      });
      add(canvas, "mouseenter", event => {
        if (pointerEventsSupported) return;
        if (!shouldUseMouseFallback(event)) return;
        const p = pointerPosition(canvas, event);
        emit(20, rawId, p.x, p.y);
      });
      add(canvas, "mousemove", event => {
        if (pointerEventsSupported) return;
        if (!shouldUseMouseFallback(event)) return;
        const p = pointerPosition(canvas, event);
        emit(21, rawId, p.x, p.y);
      });
      add(canvas, "mouseleave", event => {
        if (pointerEventsSupported) return;
        if (!shouldUseMouseFallback(event)) return;
        const p = pointerPosition(canvas, event);
        emit(22, rawId, p.x, p.y);
      });
      add(canvas, "mousedown", event => {
        preventDefaultIfCancelable(event);
        if (pointerEventsSupported) return;
        if (!shouldUseMouseFallback(event)) return;
        markButtonEvent(event);
        focusInputTarget();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "mouseup", event => {
        if (pointerEventsSupported) return;
        if (!shouldUseMouseFallback(event)) return;
        markButtonEvent(event);
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
        focusInputTarget();
      });
      add(canvas, "click", event => {
        preventDefaultIfCancelable(event);
        focusInputTarget();
        if (pointerEventsSupported) return;
        if (!shouldUseClickFallback(event)) return;
        markButtonEvent(event);
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
        emit(24, rawId, p.x, p.y, event.button);
      });
      add(canvas, "wheel", event => {
        event.preventDefault();
        emit(30, rawId, Math.round(event.deltaX), Math.round(event.deltaY));
      }, { passive: false });
      add(canvas, "dragenter", event => emitFileDrag(60, event, true));
      add(canvas, "dragover", event => emitFileDrag(61, event));
      add(canvas, "drop", event => emitFileDrag(62, event, true));
      add(canvas, "dragleave", event => emitFileDrag(63, event));
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
  imports.set_wasm_exports?.(instance.exports);
  return instance;
}
