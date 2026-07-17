// Browser host runtime for MoUI's canonical wasm-gc web backend.
//
// This file is the stable browser asset boundary for `backend/web`.
// It provides the `window_web` import object expected by the MoonBit
// `wzzc-dev/window/web` package without exposing registry cache paths to the
// browser.

import {
  createSemanticsDomManager,
  updateDocumentMetadata,
} from "./semantics_dom.js";

export function createWindowWebImports(options = {}) {
  const canvases = new Map();
  const listeners = new Map();
  const textInputs = new Map();
  const stringHandles = new Map();
  const eventTexts = new Map();
  const fileHandles = new Map();
  let nextCanvasId = 1;
  let nextStringHandle = 1;
  let nextEventTextId = 1;
  let dispatchEvent = null;
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

  const normalizeRouteString = route => {
    const value = `${route ?? ""}`.trim();
    if (!value || value === "/" || value === ".") {
      return "overview";
    }
    const withoutHash = value.startsWith("#") ? value.slice(1) : value;
    return withoutHash.replace(/^\/+/, "").replace(/\/+$/, "") || "overview";
  };

  const currentBrowserRoute = () => {
    const location = globalThis.window?.location;
    if (!location) {
      return "overview";
    }
    const params = new URLSearchParams(location.search || "");
    const explicitRoute = params.get("route");
    if (explicitRoute) {
      return normalizeRouteString(explicitRoute);
    }
    const section = params.get("section");
    if (section) {
      return normalizeRouteString(section);
    }
    const hash = `${location.hash || ""}`.replace(/^#/, "");
    if (hash) {
      return normalizeRouteString(decodeURIComponent(hash));
    }
    return "overview";
  };

  const routeUrl = route => {
    const location = globalThis.window?.location;
    const url = new URL(location?.href || "http://localhost/");
    const params = new URLSearchParams();
    const current = new URLSearchParams(url.search || "");
    if (current.get("debug") === "1") {
      params.set("debug", "1");
    }
    const normalized = normalizeRouteString(route);
    if (normalized.includes("?")) {
      params.set("route", normalized);
    } else {
      params.set("section", normalized);
    }
    url.search = params.toString();
    url.hash = "";
    return url;
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
      x: Math.round((event.clientX - rect.left) * scaleX),
      y: Math.round((event.clientY - rect.top) * scaleY),
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
    set_route_dispatch(fn) {
      dispatchRoute = typeof fn === "function" ? fn : null;
      if (dispatchRoute) {
        installRouteListener();
      }
    },
    set_wasm_exports(exports) {
      wasmExports = exports;
      semantics.setDispatch((rawId, elementId, actionCode, value) => {
        const dispatch = wasmExports?.web_dispatch_semantics_action;
        if (typeof dispatch !== "function") return;
        const valueId = value ? nextEventTextId++ : 0;
        if (valueId) eventTexts.set(valueId, value);
        try {
          dispatch(rawId, elementId, actionCode, valueId);
        } finally {
          if (valueId) eventTexts.delete(valueId);
        }
      });
    },
    sync_semantics(rawId, canvasId, json) {
      const canvas = globalThis.document?.getElementById?.(stringValue(canvasId));
      if (!(canvas instanceof globalThis.HTMLCanvasElement)) return;
      try {
        semantics.sync(rawId, canvas, JSON.parse(stringValue(json)));
      } catch (error) {
        globalThis.console?.error?.("MoUI semantics synchronization failed", error);
      }
    },
    remove_semantics(rawId) {
      semantics.remove(rawId);
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
      let lastPointerEventAt = 0;
      let lastButtonEventAt = 0;
      let suppressMouseFallback = null;
      let suppressClickFallback = null;
      let activeScrollTouch = null;
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
      const pointerEventIsStale = () =>
        Date.now() - lastPointerEventAt > fallbackDedupWindowMs;
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
      const firstTouch = list => Array.from(list ?? [])[0] ?? null;
      const touchByIdentifier = (list, identifier) =>
        Array.from(list ?? []).find(touch => touch.identifier === identifier) ?? null;
      const eventTouch = event => {
        if (activeScrollTouch) {
          return (
            touchByIdentifier(event.touches, activeScrollTouch.identifier) ??
            touchByIdentifier(event.changedTouches, activeScrollTouch.identifier)
          );
        }
        return firstTouch(event.touches) ?? firstTouch(event.changedTouches);
      };
      const touchSignature = touch => ({
        identifier: touch?.identifier ?? 0,
        clientX: Number(touch?.clientX) || 0,
        clientY: Number(touch?.clientY) || 0,
      });
      const emitTouchPointer = (kind, touch, pointerType = "") => {
        if (pointerType) {
          markPointerEvent({ type: pointerType });
        }
        const p = pointerPosition(canvas, touch);
        emit(kind, rawId, p.x, p.y, 0);
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
        emit(30, rawId, Math.round(event.deltaX), -Math.round(event.deltaY));
      }, { passive: false });
      add(canvas, "touchstart", event => {
        const touch = firstTouch(event.changedTouches) ?? firstTouch(event.touches);
        if (!touch) return;
        preventDefaultIfCancelable(event);
        activeScrollTouch = touchSignature(touch);
        focusInputTarget();
        if (!pointerEventsSupported) {
          markButtonEvent({ type: "pointerdown" });
          emitTouchPointer(23, touch, "pointerdown");
        }
      }, { passive: false });
      add(canvas, "touchmove", event => {
        const touch = eventTouch(event);
        if (!touch || !activeScrollTouch) return;
        preventDefaultIfCancelable(event);
        if (!pointerEventsSupported || pointerEventIsStale()) {
          emitTouchPointer(21, touch, "pointermove");
        }
        const dx = activeScrollTouch.clientX - Number(touch.clientX || 0);
        const dy = activeScrollTouch.clientY - Number(touch.clientY || 0);
        activeScrollTouch = touchSignature(touch);
        const roundedX = Math.round(dx);
        const roundedY = Math.round(dy);
        if (roundedX !== 0 || roundedY !== 0) {
          emit(30, rawId, roundedX, roundedY);
        }
      }, { passive: false });
      add(canvas, "touchend", event => {
        const touch = eventTouch(event);
        if (!touch) return;
        preventDefaultIfCancelable(event);
        if (!pointerEventsSupported) {
          markButtonEvent({ type: "pointerup" });
          emitTouchPointer(24, touch, "pointerup");
        }
        activeScrollTouch = null;
      }, { passive: false });
      add(canvas, "touchcancel", event => {
        const touch = eventTouch(event);
        if (touch) {
          preventDefaultIfCancelable(event);
        }
        activeScrollTouch = null;
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
  const routeDispatch = instance?.exports?.web_dispatch_route;
  if (typeof routeDispatch === "function") {
    imports.set_route_dispatch?.(routeDispatch);
  }
  imports.set_wasm_exports?.(instance.exports);
  return instance;
}
