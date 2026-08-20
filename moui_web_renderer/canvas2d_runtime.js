// Canvas2D fallback renderer for MoUI's wasm-gc WebGPU adapter.
//
// This file provides the same `webgpu` host import interface expected by the
// MoonBit adapter, but renders through the HTML Canvas2D API instead of
// WebGPU. It is used when navigator.gpu is unavailable (e.g. WebKitGTK).
//
// IMPORTANT: MoonBit sends coordinates in its OWN logical coordinate space.
// The Canvas2D API uses physical pixel coordinates (canvas.width × canvas.height).
// All draw commands MUST scale coordinates by scaleX/scaleY computed from
// (canvas physical size) / (MoonBit logical size).

export function createCanvas2dImports(options = {}) {
  const WEB_FONT_STACK = "system-ui";
  const strings = new Map();
  const surfaces = new Map();
  const renderers = new Map();
  let nextStringHandle = 1;
  let nextSurfaceHandle = 1;
  let nextRendererHandle = 1;

  const createStringHandle = value => {
    const handle = nextStringHandle++;
    strings.set(handle, { value: `${value ?? ""}` });
    return handle;
  };

  const stringValue = handle => {
    const value = strings.get(handle)?.value ?? "";
    strings.delete(handle);
    return value;
  };
  const ok = () => 0;
  const invalidResource = () => 6;

  const cssColor = color => {
    const r = Math.round(Math.max(0, Math.min(1, Number(color.r) || 0)) * 255);
    const g = Math.round(Math.max(0, Math.min(1, Number(color.g) || 0)) * 255);
    const b = Math.round(Math.max(0, Math.min(1, Number(color.b) || 0)) * 255);
    const a = Math.max(0, Math.min(1, Number(color.a) || 0));
    if (a >= 1) return `rgb(${r}, ${g}, ${b})`;
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  };

  const cssColorAlpha = (color, alpha) => {
    const r = Math.round(Math.max(0, Math.min(1, Number(color.r) || 0)) * 255);
    const g = Math.round(Math.max(0, Math.min(1, Number(color.g) || 0)) * 255);
    const b = Math.round(Math.max(0, Math.min(1, Number(color.b) || 0)) * 255);
    const a = Math.max(0, Math.min(1, (color.a || 1) * alpha));
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  };

  const clampOpacity = value => Math.max(0, Math.min(1, Number(value)));

  // ---- Coordinate scaling helpers ----
  // MoonBit sends logical coordinates. We scale by:
  //   scaleX = canvasPhysicalWidth / moonbitLogicalWidth
  //   scaleY = canvasPhysicalHeight / moonbitLogicalHeight
  // After the resize event, moonbitLogicalWidth=canvasCSSWidth, so
  // scaleX = canvasCSSWidth * dpr / canvasCSSWidth = dpr.
  // Before resize, MoonBit's logical size may differ from CSS viewport size,
  // and the scale accounts for that difference.

  const getRendererScaleX = renderer => renderer.scaleX || 1;
  const getRendererScaleY = renderer => renderer.scaleY || 1;

  const scx = (renderer, v) => Number(v) * getRendererScaleX(renderer);
  const scy = (renderer, v) => Number(v) * getRendererScaleY(renderer);

  const getCanvas = id => {
    const canvas = document.getElementById(id);
    return canvas instanceof HTMLCanvasElement ? canvas : undefined;
  };

  const canvasHostSize = canvas => {
    const host = canvas?.parentElement;
    const rect = host?.getBoundingClientRect?.();
    return {
      width: Math.max(1, Math.round(rect?.width || globalThis.window?.innerWidth || 1)),
      height: Math.max(1, Math.round(rect?.height || globalThis.window?.innerHeight || 1)),
    };
  };

  const resizeCanvas = (canvas, width, height, scaleFactor) => {
    // Use the host container size when available (fills browser viewport)
    // instead of the MoonBit-requested size (which may be smaller).
    const host = canvasHostSize(canvas);
    let logicalWidth = Number(width) || host.width;
    let logicalHeight = Number(height) || host.height;
    if (host.width > 1 && host.height > 1) {
      logicalWidth = host.width;
      logicalHeight = host.height;
    }
    const dpr = Number(scaleFactor) || window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.round(logicalWidth * dpr));
    canvas.height = Math.max(1, Math.round(logicalHeight * dpr));
    canvas.style.width = `${logicalWidth}px`;
    canvas.style.height = `${logicalHeight}px`;
  };

  const cssFont = (family, style, size, weight) => {
    const f = family || WEB_FONT_STACK;
    const s = style || "normal";
    const sz = Math.max(1, Number(size) || 14);
    const w = Number(weight) || 400;
    return `${s} ${w} ${sz}px ${f}`;
  };

  // Measure text width using a temporary canvas context
  const measureCanvas = document.createElement("canvas");
  const measureCtx = measureCanvas.getContext("2d");

  const measureTextWidth = (text, family, style, size, weight) => {
    const value = `${text ?? ""}`;
    if (measureCtx) {
      measureCtx.font = cssFont(family, style, size, weight);
      const metrics = measureCtx.measureText(value);
      if (metrics.width > 0 || value.length === 0) return metrics.width;
    }
    return value.length * Math.max(1, Number(size) || 14) * 0.55;
  };

  // Build a Path2D for a rounded rectangle
  const roundedRectPath = (x, y, width, height, radius) => {
    const r = Math.max(0, Math.min(Number(radius) || 0, Math.min(width, height) / 2));
    const path = new Path2D();
    if (r <= 0) {
      path.rect(x, y, width, height);
    } else {
      path.moveTo(x + r, y);
      path.lineTo(x + width - r, y);
      path.arcTo(x + width, y, x + width, y + r, r);
      path.lineTo(x + width, y + height - r);
      path.arcTo(x + width, y + height, x + width - r, y + height, r);
      path.lineTo(x + r, y + height);
      path.arcTo(x, y + height, x, y + height - r, r);
      path.lineTo(x, y + r);
      path.arcTo(x, y, x + r, y, r);
      path.closePath();
    }
    return path;
  };

  // Parse a double list from comma-separated string
  const parseDoubleList = value => `${value ?? ""}`
    .split(",")
    .map(part => Number(part.trim()))
    .filter(v => Number.isFinite(v));

  // Canvas2D has no built-in color-matrix filter. Reuse one hidden inline SVG
  // feColorMatrix per renderer and return a CSS `url(#...)` filter reference.
  // The values are the Skia-compatible 5x4 row-major 20 doubles.
  const colorMatrixFilters = new Map();
  const colorMatrixFilter = (rendererHandle, matrixValues) => {
    const svgId = `moui-color-matrix-${rendererHandle}`;
    const filterId = `${svgId}-filter`;
    let entry = colorMatrixFilters.get(rendererHandle);
    if (!entry) {
      const svg = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "svg",
      );
      svg.id = svgId;
      svg.setAttribute("width", "0");
      svg.setAttribute("height", "0");
      svg.setAttribute("aria-hidden", "true");
      svg.style.position = "absolute";
      const filter = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "filter",
      );
      filter.id = filterId;
      filter.setAttribute("color-interpolation-filters", "sRGB");
      const fe = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "feColorMatrix",
      );
      fe.setAttribute("type", "matrix");
      filter.appendChild(fe);
      svg.appendChild(filter);
      (document.body ?? document.documentElement).appendChild(svg);
      entry = { fe, svg };
      colorMatrixFilters.set(rendererHandle, entry);
    }
    const values = parseDoubleList(matrixValues);
    const padded = [];
    for (let i = 0; i < 20; i += 1) {
      padded.push(i < values.length ? values[i] : i % 5 === 4 ? 0 : i % 6 === 0 ? 1 : 0);
    }
    entry.fe.setAttribute("values", padded.join(" "));
    return `url(#${filterId})`;
  };

  // ---- Text selection overlay (DOM) ----
  //
  // Mirrors the WebGPU host's selectable-text overlay: every DrawText run is
  // also exposed as a transparent, absolutely-positioned <span> inside a
  // `.moui-text-selection-layer` div so the browser can select/copy text that
  // was rasterized into the canvas. Geometry is computed in MoonBit logical
  // space from a renderer-side transform/clip state stack (Canvas2D's own
  // ctx matrix is physical-space and not exposed here).

  const identityTransform = () => ({ a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 });

  const multiplyTransform = (left, right) => ({
    a: left.a * right.a + left.c * right.b,
    b: left.b * right.a + left.d * right.b,
    c: left.a * right.c + left.c * right.d,
    d: left.b * right.c + left.d * right.d,
    tx: left.a * right.tx + left.c * right.ty + left.tx,
    ty: left.b * right.tx + left.d * right.ty + left.ty,
  });

  const transformPoint = (transform, x, y) => ({
    x: transform.a * x + transform.c * y + transform.tx,
    y: transform.b * x + transform.d * y + transform.ty,
  });

  const transformRect = (transform, rect) => {
    const p0 = transformPoint(transform, rect.x, rect.y);
    const p1 = transformPoint(transform, rect.x + rect.width, rect.y);
    const p2 = transformPoint(transform, rect.x, rect.y + rect.height);
    const p3 = transformPoint(transform, rect.x + rect.width, rect.y + rect.height);
    const minX = Math.min(p0.x, p1.x, p2.x, p3.x);
    const maxX = Math.max(p0.x, p1.x, p2.x, p3.x);
    const minY = Math.min(p0.y, p1.y, p2.y, p3.y);
    const maxY = Math.max(p0.y, p1.y, p2.y, p3.y);
    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
  };

  const intersectRects = (left, right) => {
    if (!left) return right;
    if (!right) return left;
    const x = Math.max(left.x, right.x);
    const y = Math.max(left.y, right.y);
    const maxX = Math.min(left.x + left.width, right.x + right.width);
    const maxY = Math.min(left.y + left.height, right.y + right.height);
    if (maxX <= x || maxY <= y) return null;
    return { x, y, width: maxX - x, height: maxY - y };
  };

  const cssPixels = value => `${Math.round(Number(value) * 100) / 100}px`;
  const cssTextAlign = align => (Number(align) === 1 ? "center" : Number(align) === 2 ? "right" : "left");

  const textSelectionOptions = options.textSelection ?? {};
  const textSelectionEnabled = textSelectionOptions.enabled === true;
  const textSelectionClassName =
    `${textSelectionOptions.className || "moui-text-selection-layer"}`;

  const canvasCursorValue = canvas => {
    try {
      const explicit = `${canvas?.style?.cursor ?? ""}`.trim();
      const computed = explicit || `${globalThis.getComputedStyle?.(canvas)?.cursor ?? ""}`.trim();
      return !computed || computed === "auto" ? "default" : computed;
    } catch {
      return "default";
    }
  };

  const syncTextSelectionLayerGeometry = state => {
    const canvas = state?.canvas;
    const layer = state?.layer;
    if (!canvas || !layer) return;
    const host = layer.parentElement ?? canvas.parentElement;
    const canvasRect = canvas.getBoundingClientRect?.() ?? {
      left: 0,
      top: 0,
      width: canvas.clientWidth || canvas.width || 1,
      height: canvas.clientHeight || canvas.height || 1,
    };
    const hostRect = host?.getBoundingClientRect?.() ?? { left: 0, top: 0 };
    layer.style.left = `${canvasRect.left - hostRect.left + (host?.scrollLeft || 0)}px`;
    layer.style.top = `${canvasRect.top - hostRect.top + (host?.scrollTop || 0)}px`;
    layer.style.width = `${Math.max(1, canvasRect.width || canvas.clientWidth || 1)}px`;
    layer.style.height = `${Math.max(1, canvasRect.height || canvas.clientHeight || 1)}px`;
  };

  const createTextSelectionLayer = canvas => {
    if (!textSelectionEnabled || typeof document === "undefined" || !canvas) {
      return null;
    }
    const host = canvas.parentElement ?? document.body;
    if (!host) return null;
    try {
      if (globalThis.getComputedStyle?.(host)?.position === "static") {
        host.style.position = "relative";
      }
    } catch {
      // If style inspection is unavailable, the configured page CSS can own it.
    }
    const layer = document.createElement("div");
    layer.className = textSelectionClassName;
    layer.setAttribute("aria-hidden", "true");
    layer.dataset.mouiCanvasId = canvas.id;
    Object.assign(layer.style, {
      position: "absolute",
      left: "0px",
      top: "0px",
      width: "1px",
      height: "1px",
      overflow: "hidden",
      pointerEvents: "none",
      cursor: canvasCursorValue(canvas),
      userSelect: "text",
      WebkitUserSelect: "text",
      zIndex: `${textSelectionOptions.zIndex ?? 1}`,
      contain: "layout style paint",
    });
    host.appendChild(layer);
    const state = { canvas, layer, runs: [], nodes: [] };
    syncTextSelectionLayerGeometry(state);
    return state;
  };

  const disposeTextSelectionLayer = state => {
    if (!state) return;
    state.runs = [];
    state.nodes = [];
    state.layer?.remove?.();
  };

  const textSelectionClipPath = run => {
    const frame = run.frame;
    const visible = run.visible;
    if (!visible) return "";
    const left = Math.max(0, visible.x - frame.x);
    const top = Math.max(0, visible.y - frame.y);
    const right = Math.max(0, frame.x + frame.width - (visible.x + visible.width));
    const bottom = Math.max(0, frame.y + frame.height - (visible.y + visible.height));
    if (left <= 0 && top <= 0 && right <= 0 && bottom <= 0) return "";
    return `inset(${top}px ${right}px ${bottom}px ${left}px)`;
  };

  const pushSelectableRun = (selection, renderer, text, frame, font, align) => {
    if (!text) return;
    const state = renderer.renderState[renderer.renderState.length - 1] ?? {
      transform: identityTransform(),
      clip: null,
    };
    const transformed = transformRect(state.transform, frame);
    const canvasClip = {
      x: 0,
      y: 0,
      width: Math.max(1, Number(renderer.moonbitWidth || renderer.width || 1)),
      height: Math.max(1, Number(renderer.moonbitHeight || renderer.height || 1)),
    };
    const clipped = intersectRects(transformed, state.clip);
    const visible = intersectRects(clipped, canvasClip);
    if (!visible || visible.width <= 0 || visible.height <= 0) return;
    selection.runs.push({
      text,
      frame: transformed,
      visible,
      font: {
        family: font.family || WEB_FONT_STACK,
        style: font.style || "normal",
        size: Math.max(1, Number(font.size) || 14),
        weight: Number(font.weight) || 400,
      },
      align: Number(align) || 0,
    });
  };

  const recordSelectableTextRun = (renderer, text, frame, font, align, alpha) => {
    const selection = renderer.textSelection;
    if (!selection || !text || alpha <= 0.01) return;
    const logicalFrame = {
      x: Number(frame.x) || 0,
      y: Number(frame.y) || 0,
      width: Math.max(0, Number(frame.width) || 0),
      height: Math.max(0, Number(frame.height) || 0),
    };
    if (logicalFrame.width <= 0 || logicalFrame.height <= 0) return;
    pushSelectableRun(selection, renderer, text, logicalFrame, font, align);
  };

  const applySelectableTextStyle = (span, run) => {
    Object.assign(span.style, {
      position: "absolute",
      display: "block",
      left: cssPixels(run.frame.x),
      top: cssPixels(run.frame.y),
      width: cssPixels(run.frame.width),
      height: cssPixels(run.frame.height),
      margin: "0",
      padding: "0",
      border: "0",
      overflow: "hidden",
      whiteSpace: "pre",
      pointerEvents: "auto",
      cursor: "inherit",
      userSelect: "text",
      WebkitUserSelect: "text",
      color: "transparent",
      WebkitTextFillColor: "transparent",
      background: "transparent",
      fontFamily: run.font.family,
      fontStyle: run.font.style,
      fontSize: cssPixels(run.font.size),
      fontWeight: `${run.font.weight}`,
      fontKerning: "none",
      fontVariantLigatures: "none",
      fontFeatureSettings: '"kern" 0, "liga" 0, "clig" 0, "calt" 0',
      textRendering: "geometricPrecision",
      lineHeight: cssPixels(Math.max(run.font.size, run.frame.height)),
      textAlign: cssTextAlign(run.align),
      letterSpacing: "0",
    });
    const clipPath = textSelectionClipPath(run);
    span.style.clipPath = clipPath;
    span.style.webkitClipPath = clipPath;
  };

  const selectableRunSignature = run => [
    run.text,
    run.frame.x,
    run.frame.y,
    run.frame.width,
    run.frame.height,
    run.visible.x,
    run.visible.y,
    run.visible.width,
    run.visible.height,
    run.font.family,
    run.font.style,
    run.font.size,
    run.font.weight,
    run.align,
  ].join("\u0000");

  const updateSelectableTextSpan = (record, run) => {
    const signature = selectableRunSignature(run);
    if (record.signature === signature && !record.hidden) return;
    if (record.span.textContent !== run.text) record.span.textContent = run.text;
    applySelectableTextStyle(record.span, run);
    record.signature = signature;
    record.hidden = false;
  };

  const syncTextSelectionLayer = renderer => {
    const selection = renderer.textSelection;
    if (!selection || typeof document === "undefined") return;
    syncTextSelectionLayerGeometry(selection);
    const runs = selection.runs ?? [];
    const common = Math.min(selection.nodes.length, runs.length);
    for (let index = 0; index < common; index += 1) {
      updateSelectableTextSpan(selection.nodes[index], runs[index]);
    }
    for (let index = common; index < runs.length; index += 1) {
      const span = document.createElement("span");
      span.draggable = false;
      const record = { span, signature: "", hidden: false };
      updateSelectableTextSpan(record, runs[index]);
      selection.layer.appendChild(span);
      selection.nodes.push(record);
    }
    for (let index = runs.length; index < selection.nodes.length; index += 1) {
      const record = selection.nodes[index];
      if (!record.hidden) {
        record.hidden = true;
        record.span.textContent = "";
        record.span.style.display = "none";
      }
    }
    selection.runs = [];
  };

  // ---- Renderer state helpers ----

  const rendererCtx = renderer => renderer.ctx;

  const saveAndSetClip = (renderer, x, y, width, height) => {
    const ctx = rendererCtx(renderer);
    ctx.save();
    ctx.beginPath();
    ctx.rect(x, y, width, height);
    ctx.clip();
  };

  const saveAndSetTransform = (renderer, a, b, c, d, tx, ty) => {
    const ctx = rendererCtx(renderer);
    ctx.save();
    // Accumulate (multiply) instead of replacing the current matrix so nested
    // PushTransform scopes compose exactly like the WebGPU host's
    // multiplyTransform. Coordinates arrive in physical pixels (already scaled
    // by scx/scy), so the incoming logical-space matrix is conjugated with the
    // logical→physical scale (S·T·S⁻¹).
    const sx = getRendererScaleX(renderer);
    const sy = getRendererScaleY(renderer);
    ctx.transform(a, (Number(b) * sx) / sy, (Number(c) * sy) / sx, d, tx, ty);
  };

  const saveAndSetOpacity = (renderer, opacity) => {
    const ctx = rendererCtx(renderer);
    const current = ctx.globalAlpha;
    ctx.save();
    ctx.globalAlpha = current * clampOpacity(opacity);
  };

  // Create offscreen canvas for layer rendering
  const createOffscreenCanvas = renderer => {
    const canvas = renderer.surface?.canvas;
    const w = canvas ? canvas.width : 1;
    const h = canvas ? canvas.height : 1;
    const offscreen = document.createElement("canvas");
    offscreen.width = w;
    offscreen.height = h;
    return offscreen;
  };

  // Blend mode mapping to Canvas2D globalCompositeOperation
  const blendModeOp = mode => {
    switch (Number(mode) || 0) {
      case 1: return "multiply";
      case 2: return "screen";
      case 3: return "overlay";
      case 4: return "darken";
      case 5: return "lighten";
      default: return "source-over";
    }
  };

  // ---- Image cache ----

  const ensureImage = (renderer, source) => {
    const key = `${source ?? ""}`;
    if (!key) return undefined;
    const cached = renderer.images.get(key);
    if (cached) {
      if (cached.complete) return cached;
      return undefined;
    }
    const img = new Image();
    if (!key.startsWith("data:") && !key.startsWith("blob:")) {
      img.crossOrigin = "anonymous";
    }
    renderer.images.set(key, img);
    img.onload = () => { renderer.loadedImages.set(key, img); };
    img.onerror = () => { renderer.failedImages.set(key, true); };
    img.src = key;
    return undefined;
  };

  const loadedImage = (renderer, source) => {
    const key = `${source ?? ""}`;
    const img = renderer.loadedImages.get(key);
    if (img) return img;
    const cached = renderer.images.get(key);
    if (cached && cached.complete && cached.naturalWidth > 0) {
      renderer.loadedImages.set(key, cached);
      return cached;
    }
    return undefined;
  };

  const imagePlacement = (rect, imageWidth, imageHeight, fit) => {
    const frameRatio = rect.width / Math.max(rect.height, 0.0001);
    const imgRatio = imageWidth / Math.max(imageHeight, 0.0001);
    const contain = () => {
      if (imgRatio > frameRatio) {
        const height = rect.width / imgRatio;
        return {
          dx: rect.x, dy: rect.y + (rect.height - height) * 0.5,
          dw: rect.width, dh: height,
          sx: 0, sy: 0, sw: imageWidth, sh: imageHeight,
        };
      }
      const width = rect.height * imgRatio;
      return {
        dx: rect.x + (rect.width - width) * 0.5,
        dy: rect.y,
        dw: width, dh: rect.height,
        sx: 0, sy: 0, sw: imageWidth, sh: imageHeight,
      };
    };
    if (Number(fit) === 2) {
      return { dx: rect.x, dy: rect.y, dw: rect.width, dh: rect.height };
    }
    if (Number(fit) === 1) {
      if (imgRatio > frameRatio) {
        const visible = frameRatio / imgRatio;
        const inset = (1 - visible) * 0.5;
        return {
          dx: rect.x, dy: rect.y,
          dw: rect.width, dh: rect.height,
          sx: 0, sy: inset * imageHeight,
          sw: imageWidth, sh: imageHeight * visible,
        };
      }
      const visible = imgRatio / frameRatio;
      const inset = (1 - visible) * 0.5;
      return {
        dx: rect.x, dy: rect.y,
        dw: rect.width, dh: rect.height,
        sx: inset * imageWidth, sy: 0,
        sw: imageWidth * visible, sh: imageHeight,
      };
    }
    // ScaleDown: natural size (centered) when the image fits, else contain.
    if (Number(fit) === 3) {
      if (imageWidth <= rect.width && imageHeight <= rect.height) {
        return {
          dx: rect.x + (rect.width - imageWidth) * 0.5,
          dy: rect.y + (rect.height - imageHeight) * 0.5,
          dw: imageWidth, dh: imageHeight,
          sx: 0, sy: 0, sw: imageWidth, sh: imageHeight,
        };
      }
      return contain();
    }
    // FitWidth: fill the frame width; crop vertically when the scaled image
    // is taller than the frame, else letterbox vertically.
    if (Number(fit) === 4) {
      const height = rect.width / imgRatio;
      if (height <= rect.height) {
        return {
          dx: rect.x, dy: rect.y + (rect.height - height) * 0.5,
          dw: rect.width, dh: height,
          sx: 0, sy: 0, sw: imageWidth, sh: imageHeight,
        };
      }
      const visible = rect.height / height;
      const inset = (1 - visible) * 0.5;
      return {
        dx: rect.x, dy: rect.y,
        dw: rect.width, dh: rect.height,
        sx: 0, sy: inset * imageHeight,
        sw: imageWidth, sh: imageHeight * visible,
      };
    }
    // FitHeight: fill the frame height; crop horizontally when the scaled
    // image is wider than the frame, else letterbox horizontally.
    if (Number(fit) === 5) {
      const width = rect.height * imgRatio;
      if (width <= rect.width) {
        return {
          dx: rect.x + (rect.width - width) * 0.5,
          dy: rect.y,
          dw: width, dh: rect.height,
          sx: 0, sy: 0, sw: imageWidth, sh: imageHeight,
        };
      }
      const visible = rect.width / width;
      const inset = (1 - visible) * 0.5;
      return {
        dx: rect.x, dy: rect.y,
        dw: rect.width, dh: rect.height,
        sx: inset * imageWidth, sy: 0,
        sw: imageWidth * visible, sh: imageHeight,
      };
    }
    return contain();
  };

  // ---- Return the import object ----

  return {
    begin_create_string() {
      return createStringHandle("");
    },
    string_append_char(handle, ch) {
      const entry = strings.get(handle);
      if (entry) entry.value += String.fromCodePoint(Number(ch));
    },
    finish_create_string(handle) {
      return handle;
    },

    // Report true so the MoonBit adapter's capability check passes.
    webgpu_available() { return true; },
    three_d_available() { return false; },
    create_3d_surface() { return 0; },
    create_3d_renderer() { return 0; },
    three_d_surface_resize() { return invalidResource(); },
    three_d_draw_mesh() { return invalidResource(); },
    three_d_renderer_dispose() {},
    three_d_surface_dispose() {},
    adapter_ready() { return true; },
    can_render() { return true; },

    measure_text_width(text, family, style, size, weight) {
      return measureTextWidth(stringValue(text), stringValue(family), stringValue(style), size, weight);
    },

    register_font_data(family, base64Data) {
      if (typeof FontFace !== "function" || !document.fonts) return invalidResource();
      const data = (() => {
        try {
          const binary = atob(`${stringValue(base64Data) ?? ""}`);
          const out = new Uint8Array(binary.length);
          for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
          return out;
        } catch { return undefined; }
      })();
      if (!data || data.length === 0) return invalidResource();
      const cssFam = `${stringValue(family) || ""}`.replace(/^"|"$/g, "");
      if (!cssFam) return invalidResource();
      try {
        const blob = new Blob([data], { type: "font/ttf" });
        const url = URL.createObjectURL(blob);
        const face = new FontFace(cssFam, `url(${url})`);
        document.fonts.add(face);
        face.load().catch(() => URL.revokeObjectURL(url));
        return ok();
      } catch { return invalidResource(); }
    },

    create_surface(canvasId, width, height, scaleFactor) {
      const canvas = getCanvas(stringValue(canvasId));
      if (!canvas) return 0;
      resizeCanvas(canvas, width, height, scaleFactor);
      const ctx = canvas.getContext("2d");
      if (!ctx) return 0;
      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = "high";
      const handle = nextSurfaceHandle++;
      surfaces.set(handle, { canvas, ctx, scaleFactor, width, height });
      return handle;
    },
    surface_is_valid(surfaceHandle) { return surfaces.has(surfaceHandle); },
    surface_resize(surfaceHandle, width, height, scaleFactor) {
      const surface = surfaces.get(surfaceHandle);
      if (!surface) return invalidResource();
      resizeCanvas(surface.canvas, width, height, scaleFactor);
      surface.width = width;
      surface.height = height;
      surface.scaleFactor = scaleFactor;
      return ok();
    },
    surface_dispose(surfaceHandle) { surfaces.delete(surfaceHandle); },

    create_renderer(surfaceHandle) {
      const surface = surfaces.get(surfaceHandle);
      if (!surface) return 0;
      const renderer = {
        surface,
        ctx: surface.ctx,
        width: surface.width,
        height: surface.height,
        scaleFactor: surface.scaleFactor,
        scaleX: 1,
        scaleY: 1,
        moonbitWidth: Number(surface.width) || 1,
        moonbitHeight: Number(surface.height) || 1,
        images: new Map(),
        loadedImages: new Map(),
        failedImages: new Map(),
        presentCount: 0,
        layerCanvas: null,
        renderState: [{
          transform: identityTransform(),
          clip: null,
        }],
        textSelection: createTextSelectionLayer(surface.canvas),
      };
      const handle = nextRendererHandle++;
      renderers.set(handle, renderer);
      return handle;
    },
    renderer_is_valid(rendererHandle) { return renderers.has(rendererHandle); },
    renderer_resize(rendererHandle, width, height, scaleFactor) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      resizeCanvas(renderer.surface.canvas, width, height, scaleFactor);
      renderer.moonbitWidth = Number(width) || 1;
      renderer.moonbitHeight = Number(height) || 1;
      renderer.width = Number(width);
      renderer.height = Number(height);
      renderer.scaleFactor = Number(scaleFactor);
      // Recompute scales since MoonBit logical size changed
      const canvas = renderer.surface?.canvas;
      const cw = canvas ? canvas.width : 1;
      const ch = canvas ? canvas.height : 1;
      renderer.scaleX = cw / renderer.moonbitWidth;
      renderer.scaleY = ch / renderer.moonbitHeight;
      return ok();
    },

    begin_frame(rendererHandle, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      renderer.renderState = [{
        transform: identityTransform(),
        clip: null,
      }];
      // A previous frame may have ended with unbalanced layer/filter scopes
      // (host bugs or adapter edge cases). Reset the scope stack and restore
      // the surface context so an unmatched push cannot leak into this frame
      // (with accumulate-transform semantics a stale matrix would compound).
      renderer.layerStack = [];
      renderer.ctx = renderer.surface?.ctx;
      const surfaceCtx = renderer.surface?.ctx;
      if (surfaceCtx && renderer.ctx === surfaceCtx) {
        // push_transform/push_clip/push_opacity save onto the surface ctx
        // without swapping it, so their stale state (matrix, clip, alpha,
        // filter, shadow) would leak into this frame too. Reset it to a
        // clean identity state.
        surfaceCtx.setTransform(1, 0, 0, 1, 0, 0);
        surfaceCtx.globalAlpha = 1;
        surfaceCtx.filter = "none";
        surfaceCtx.shadowBlur = 0;
        surfaceCtx.shadowOffsetX = 0;
        surfaceCtx.shadowOffsetY = 0;
        surfaceCtx.lineWidth = 1;
        surfaceCtx.textAlign = "start";
        surfaceCtx.textBaseline = "alphabetic";
      }
      renderer.moonbitWidth = Math.max(1, Number(width) || 1);
      renderer.moonbitHeight = Math.max(1, Number(height) || 1);
      renderer.width = renderer.moonbitWidth;
      renderer.height = renderer.moonbitHeight;
      const canvas = renderer.surface?.canvas;
      const cw = canvas ? canvas.width : 1;
      const ch = canvas ? canvas.height : 1;
      // Scale from MoonBit logical space to Canvas2D physical pixel space
      renderer.scaleX = cw / renderer.moonbitWidth;
      renderer.scaleY = ch / renderer.moonbitHeight;
      renderer.presentCount++;
      return ok();
    },

    clear(rendererHandle, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const canvas = renderer.surface?.canvas;
      const w = canvas ? canvas.width : 1;
      const h = canvas ? canvas.height : 1;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.globalAlpha = 1;
      ctx.fillStyle = cssColor({ r, g, b, a });
      ctx.fillRect(0, 0, w, h);
      return ok();
    },

    fill_rect(rendererHandle, x, y, width, height, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.fillStyle = cssColor({ r, g, b, a });
      ctx.fillRect(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height));
      return ok();
    },
    stroke_rect(rendererHandle, x, y, width, height, r, g, b, a, strokeWidth) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.strokeStyle = cssColor({ r, g, b, a });
      ctx.lineWidth = scx(renderer, Number(strokeWidth) || 1);
      ctx.strokeRect(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height));
      return ok();
    },

    fill_rounded_rect(rendererHandle, x, y, width, height, radius, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.fillStyle = cssColor({ r, g, b, a });
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius));
      ctx.fill(path);
      return ok();
    },
    stroke_rounded_rect(rendererHandle, x, y, width, height, radius, r, g, b, a, strokeWidth) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.strokeStyle = cssColor({ r, g, b, a });
      ctx.lineWidth = scx(renderer, Number(strokeWidth) || 1);
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius));
      ctx.stroke(path);
      return ok();
    },

    fill_rounded_rect_gradient(rendererHandle, x, y, width, height, radius, startX, startY, endX, endY, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const gradient = ctx.createLinearGradient(scx(renderer, startX), scy(renderer, startY), scx(renderer, endX), scy(renderer, endY));
      gradient.addColorStop(0, cssColor({ r: r0, g: g0, b: b0, a: a0 }));
      gradient.addColorStop(1, cssColor({ r: r1, g: g1, b: b1, a: a1 }));
      ctx.fillStyle = gradient;
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius));
      ctx.fill(path);
      return ok();
    },
    stroke_rounded_rect_gradient(rendererHandle, x, y, width, height, radius, strokeWidth, startX, startY, endX, endY, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const gradient = ctx.createLinearGradient(scx(renderer, startX), scy(renderer, startY), scx(renderer, endX), scy(renderer, endY));
      gradient.addColorStop(0, cssColor({ r: r0, g: g0, b: b0, a: a0 }));
      gradient.addColorStop(1, cssColor({ r: r1, g: g1, b: b1, a: a1 }));
      ctx.strokeStyle = gradient;
      ctx.lineWidth = scx(renderer, Number(strokeWidth) || 1);
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius));
      ctx.stroke(path);
      return ok();
    },

    fill_rounded_rect_radial(rendererHandle, x, y, width, height, radius, centerX, centerY, gradientRadius, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const gr = Math.max(0.0001, scx(renderer, Number(gradientRadius) || 0));
      const gradient = ctx.createRadialGradient(scx(renderer, centerX), scy(renderer, centerY), 0, scx(renderer, centerX), scy(renderer, centerY), gr);
      gradient.addColorStop(0, cssColor({ r: r0, g: g0, b: b0, a: a0 }));
      gradient.addColorStop(1, cssColor({ r: r1, g: g1, b: b1, a: a1 }));
      ctx.fillStyle = gradient;
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius));
      ctx.fill(path);
      return ok();
    },
    stroke_rounded_rect_radial(rendererHandle, x, y, width, height, radius, strokeWidth, centerX, centerY, gradientRadius, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const gr = Math.max(0.0001, scx(renderer, Number(gradientRadius) || 0));
      const gradient = ctx.createRadialGradient(scx(renderer, centerX), scy(renderer, centerY), 0, scx(renderer, centerX), scy(renderer, centerY), gr);
      gradient.addColorStop(0, cssColor({ r: r0, g: g0, b: b0, a: a0 }));
      gradient.addColorStop(1, cssColor({ r: r1, g: g1, b: b1, a: a1 }));
      ctx.strokeStyle = gradient;
      ctx.lineWidth = scx(renderer, Number(strokeWidth) || 1);
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius));
      ctx.stroke(path);
      return ok();
    },

    draw_shadow(rendererHandle, x, y, width, height, radius, offsetX, offsetY, blurRadius, spread, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const blur = Math.max(0, scx(renderer, Number(blurRadius) || 0));
      const spreadVal = Math.max(0, scx(renderer, Number(spread) || 0));
      const ox = scx(renderer, Number(offsetX) || 0);
      const oy = scy(renderer, Number(offsetY) || 0);
      ctx.save();
      ctx.shadowColor = cssColor({ r, g, b, a });
      ctx.shadowBlur = blur;
      ctx.shadowOffsetX = ox;
      ctx.shadowOffsetY = oy;
      ctx.fillStyle = "transparent";
      const path = roundedRectPath(scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height), scx(renderer, radius) + spreadVal);
      ctx.fill(path);
      ctx.restore();
      return ok();
    },

    draw_text(rendererHandle, text, x, y, width, height, family, style, size, weight, r, g, b, a, align) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const value = stringValue(text);
      if (!value) return ok();
      const fontFamily = stringValue(family) || WEB_FONT_STACK;
      const fontStyle = stringValue(style) || "normal";
      const fontSize = Math.max(1, Number(size) || 14);
      const fontWeight = Number(weight) || 400;
      // Canvas2D ctx.font size is in canvas coordinate units (physical pixels).
      // The canvas CSS size (viewport) is scaleX times smaller than the pixel
      // buffer, so ALL canvas content is scaled down by scaleX on screen.
      // To make text appear at the correct CSS pixel size on screen, we must
      // multiply the MoonBit logical font size by scaleX.
      const scaleX = getRendererScaleX(renderer);
      const scaleY = getRendererScaleY(renderer);
      const scaledFontSize = fontSize * scaleX;
      ctx.font = cssFont(fontFamily, fontStyle, scaledFontSize, fontWeight);
      ctx.textBaseline = "alphabetic";
      const physX = scx(renderer, x);
      const physW = scx(renderer, width);
      const physY = scy(renderer, y);
      const physH = scy(renderer, height);
      // Compute drawX based on textAlign. ctx.textAlign controls how fillText
      // interprets the X coordinate. We must NOT double-compute alignment.
      let drawX;
      const alignCode = Number(align) || 0;
      if (alignCode === 1) {
        ctx.textAlign = "center";
        drawX = physX + physW / 2;
      } else if (alignCode === 2) {
        ctx.textAlign = "right";
        drawX = physX + physW;
      } else {
        ctx.textAlign = "left";
        drawX = physX;
      }
      // Vertical baseline: the font has been scaled by scaleX, so the
      // ascender height is approximately scaledFontSize physical pixels.
      const ascent = scaledFontSize;
      const drawY = physY + Math.max(ascent, (physH + ascent * 0.72) / 2);
      ctx.fillStyle = cssColor({ r, g, b, a });
      ctx.fillText(value, drawX, drawY);
      recordSelectableTextRun(
        renderer,
        value,
        { x: Number(x), y: Number(y), width: Number(width), height: Number(height) },
        { family: fontFamily, style: fontStyle, size: fontSize, weight: fontWeight },
        alignCode,
        Number(a),
      );
      return ok();
    },

    draw_image(rendererHandle, source, x, y, width, height, opacity, fit) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const src = stringValue(source);
      const rect = {
        x: scx(renderer, Number(x) || 0),
        y: scy(renderer, Number(y) || 0),
        width: Math.max(0, scx(renderer, Number(width) || 0)),
        height: Math.max(0, scy(renderer, Number(height) || 0)),
      };
      if (rect.width <= 0 || rect.height <= 0) return ok();
      const img = loadedImage(renderer, src);
      if (!img) {
        ensureImage(renderer, src);
        ctx.fillStyle = "rgba(180, 180, 200, 0.3)";
        ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
        return ok();
      }
      const alpha = clampOpacity(opacity);
      const imgW = img.naturalWidth || img.width || 1;
      const imgH = img.naturalHeight || img.height || 1;
      const placement = imagePlacement(rect, imgW, imgH, fit);
      ctx.globalAlpha = alpha;
      if (placement.sx !== undefined) {
        ctx.drawImage(img, placement.sx, placement.sy, placement.sw, placement.sh, placement.dx, placement.dy, placement.dw, placement.dh);
      } else {
        ctx.drawImage(img, placement.dx, placement.dy, placement.dw, placement.dh);
      }
      ctx.globalAlpha = 1;
      return ok();
    },

    draw_path_mesh(rendererHandle, meshPayload) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const values = parseDoubleList(stringValue(meshPayload));
      const stride = 15;
      if (values.length < stride * 3) return ok();
      const ctx = rendererCtx(renderer);
      const sx = getRendererScaleX(renderer);
      const sy = getRendererScaleY(renderer);
      for (let i = 0; i + stride * 3 - 1 < values.length; i += stride * 3) {
        const x0 = values[i] * sx;
        const y0 = values[i + 1] * sy;
        const a0 = values[i + 10];
        const x1 = values[i + stride] * sx;
        const y1 = values[i + stride + 1] * sy;
        const a1 = values[i + stride + 10];
        const x2 = values[i + stride * 2] * sx;
        const y2 = values[i + stride * 2 + 1] * sy;
        const a2 = values[i + stride * 2 + 10];
        const r0 = values[i + 7];
        const g0 = values[i + 8];
        const b0 = values[i + 9];
        const r1 = values[i + stride + 7];
        const g1 = values[i + stride + 8];
        const b1 = values[i + stride + 9];
        const r2 = values[i + stride * 2 + 7];
        const g2 = values[i + stride * 2 + 8];
        const b2 = values[i + stride * 2 + 9];
        // Canvas2D has no per-vertex shader interpolation. Approximate the
        // WebGPU path mesh gradient with a linear gradient along the longest
        // triangle edge (va->vb) and place the third vertex's color at its
        // projection onto that edge, so adjacent triangles blend
        // continuously instead of flat-filling with a single average color.
        const edges = [
          { ax: x0, ay: y0, bx: x1, by: y1, cx: x2, cy: y2, ca: a0, cr: r0, cg: g0, cb: b0, aa: a1, ar: r1, ag: g1, ab: b1, ba: a2, br: r2, bg: g2, bb: b2 },
          { ax: x1, ay: y1, bx: x2, by: y2, cx: x0, cy: y0, ca: a1, cr: r1, cg: g1, cb: b1, aa: a2, ar: r2, ag: g2, ab: b2, ba: a0, br: r0, bg: g0, bb: b0 },
          { ax: x2, ay: y2, bx: x0, by: y0, cx: x1, cy: y1, ca: a2, cr: r2, cg: g2, cb: b2, aa: a0, ar: r0, ag: g0, ab: b0, ba: a1, br: r1, bg: g1, bb: b1 },
        ];
        let best = edges[0];
        let bestLen = -1;
        for (const e of edges) {
          const len = (e.bx - e.ax) * (e.bx - e.ax) + (e.by - e.ay) * (e.by - e.ay);
          if (len > bestLen) {
            bestLen = len;
            best = e;
          }
        }
        const dx = best.bx - best.ax;
        const dy = best.by - best.ay;
        const t = bestLen > 0
          ? Math.max(0, Math.min(1, ((best.cx - best.ax) * dx + (best.cy - best.ay) * dy) / bestLen))
          : 0.5;
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(x0, y0);
        ctx.lineTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.closePath();
        ctx.clip();
        const gradient = ctx.createLinearGradient(best.ax, best.ay, best.bx, best.by);
        gradient.addColorStop(0, cssColor({ r: best.ar, g: best.ag, b: best.ab, a: best.aa }));
        gradient.addColorStop(t, cssColor({ r: best.cr, g: best.cg, b: best.cb, a: best.ca }));
        gradient.addColorStop(1, cssColor({ r: best.br, g: best.bg, b: best.bb, a: best.ba }));
        ctx.fillStyle = gradient;
        // Vertex alpha already lives in the gradient stops; applying it again
        // through globalAlpha would square it (a² vs the host's a).
        ctx.globalAlpha = 1;
        ctx.fill();
        ctx.restore();
      }
      return ok();
    },

    image_resource_status(rendererHandle, source) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return 0;
      const key = stringValue(source);
      if (renderer.failedImages.has(key)) return 3;
      if (renderer.loadedImages.has(key)) return 2;
      if (renderer.images.has(key)) return 1;
      return 0;
    },
    image_resource_width(rendererHandle, source) {
      const renderer = renderers.get(rendererHandle);
      const key = stringValue(source);
      const img = renderer?.loadedImages.get(key);
      if (img) return Math.max(0, Math.round(img.naturalWidth || img.width || 0));
      const cached = renderer?.images.get(key);
      if (cached && cached.complete) return Math.max(0, Math.round(cached.naturalWidth || cached.width || 0));
      return 0;
    },
    image_resource_height(rendererHandle, source) {
      const renderer = renderers.get(rendererHandle);
      const key = stringValue(source);
      const img = renderer?.loadedImages.get(key);
      if (img) return Math.max(0, Math.round(img.naturalHeight || img.height || 0));
      const cached = renderer?.images.get(key);
      if (cached && cached.complete) return Math.max(0, Math.round(cached.naturalHeight || cached.height || 0));
      return 0;
    },

    push_clip(rendererHandle, x, y, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      saveAndSetClip(renderer, scx(renderer, x), scy(renderer, y), scx(renderer, width), scy(renderer, height));
      // Track logical-space clip for the text-selection overlay.
      const current = renderer.renderState[renderer.renderState.length - 1] ?? {
        transform: identityTransform(),
        clip: null,
      };
      const transformed = transformRect(current.transform, {
        x: Number(x),
        y: Number(y),
        width: Number(width),
        height: Number(height),
      });
      renderer.renderState.push({
        transform: current.transform,
        clip: intersectRects(current.clip, transformed),
      });
      return ok();
    },
    pop_clip(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.restore();
      if (renderer.renderState.length > 1) renderer.renderState.pop();
      return ok();
    },

    push_transform(rendererHandle, a, b, c, d, tx, ty) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const sx = getRendererScaleX(renderer);
      const sy = getRendererScaleY(renderer);
      // The transform matrix operates in MoonBit logical space; Canvas2D uses
      // physical pixel space, so scale the translation and conjugate the
      // off-diagonal entries (S·T·S⁻¹). ctx.transform accumulates, matching
      // the WebGPU host's multiplyTransform semantics for nested scopes.
      saveAndSetTransform(renderer,
        Number(a),
        (Number(b) * sx) / sy,
        (Number(c) * sy) / sx,
        Number(d),
        scx(renderer, tx), scy(renderer, ty)
      );
      // Track logical-space transform for the text-selection overlay.
      const current = renderer.renderState[renderer.renderState.length - 1] ?? {
        transform: identityTransform(),
        clip: null,
      };
      renderer.renderState.push({
        transform: multiplyTransform(current.transform, {
          a: Number(a),
          b: Number(b),
          c: Number(c),
          d: Number(d),
          tx: Number(tx),
          ty: Number(ty),
        }),
        clip: current.clip,
      });
      return ok();
    },
    pop_transform(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.restore();
      if (renderer.renderState.length > 1) renderer.renderState.pop();
      return ok();
    },

    push_opacity(rendererHandle, opacity) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      saveAndSetOpacity(renderer, opacity);
      return ok();
    },
    pop_opacity(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.restore();
      return ok();
    },

    push_layer(rendererHandle, opacity, blendMode, maskKind, maskX, maskY, maskWidth, maskHeight, maskRadius, offscreen) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const offCanvas = createOffscreenCanvas(renderer);
      const offCtx = offCanvas.getContext("2d");
      if (!offCtx) return ok();
      offCtx.imageSmoothingEnabled = true;
      offCtx.imageSmoothingQuality = "high";
      if (!renderer.layerStack) renderer.layerStack = [];
      renderer.layerStack.push({
        ctx,
        opacity: clampOpacity(opacity),
        blendMode: Number(blendMode) || 0,
        mask: {
          kind: Number(maskKind) || 0,
          x: scx(renderer, Number(maskX) || 0),
          y: scy(renderer, Number(maskY) || 0),
          width: scx(renderer, Number(maskWidth) || 0),
          height: scy(renderer, Number(maskHeight) || 0),
          radius: scx(renderer, Number(maskRadius) || 0),
        },
      });
      renderer.ctx = offCtx;
      return ok();
    },
    pop_layer(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const layerInfo = renderer.layerStack?.pop();
      if (!layerInfo) return ok();
      const ctx = rendererCtx(renderer);
      renderer.ctx = layerInfo.ctx;
      const offCanvas = ctx.canvas;
      const dpr = renderer.scaleFactor || 1;
      const alpha = layerInfo.opacity;
      const blendOp = blendModeOp(layerInfo.blendMode);
      const mainCtx = layerInfo.ctx;
      mainCtx.save();
      mainCtx.globalAlpha = alpha;
      mainCtx.globalCompositeOperation = blendOp;
      if (layerInfo.mask.kind > 0) {
        mainCtx.beginPath();
        if (layerInfo.mask.kind === 2) {
          const path = roundedRectPath(
            layerInfo.mask.x, layerInfo.mask.y,
            layerInfo.mask.width, layerInfo.mask.height,
            layerInfo.mask.radius,
          );
          mainCtx.clip(path);
        } else {
          mainCtx.rect(layerInfo.mask.x, layerInfo.mask.y, layerInfo.mask.width, layerInfo.mask.height);
          mainCtx.clip();
        }
      }
      mainCtx.drawImage(offCanvas, 0, 0);
      mainCtx.restore();
      return ok();
    },

    push_filter(rendererHandle, filterKind, amount, matrixValues) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      if (!renderer.layerStack) renderer.layerStack = [];
      const offCanvas = createOffscreenCanvas(renderer);
      const offCtx = offCanvas.getContext("2d");
      if (!offCtx) return ok();
      offCtx.imageSmoothingEnabled = true;
      renderer.layerStack.push({
        ctx,
        filter: {
          // Mirror the WebGPU host's normalizeFilter: payload kinds are
          // Blur=0, Saturate=1, Brightness=2, Contrast=3, ColorMatrix=4;
          // render kinds are blur=1, saturate=2, brightness=3, contrast=4,
          // color-matrix=5.
          kind: (Number(filterKind) || 0) + 1,
          amount: Number(amount) || 0,
          matrixValues: stringValue(matrixValues),
        },
      });
      renderer.ctx = offCtx;
      return ok();
    },
    pop_filter(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const layerInfo = renderer.layerStack?.pop();
      if (!layerInfo) return ok();
      const ctx = rendererCtx(renderer);
      renderer.ctx = layerInfo.ctx;
      const offCanvas = ctx.canvas;
      const mainCtx = layerInfo.ctx;
      const filter = layerInfo.filter || { kind: 0, amount: 0, matrixValues: "" };
      const kind = filter.kind;
      const amount = filter.amount;
      mainCtx.save();
      if (kind === 1) {
        mainCtx.filter = `blur(${Math.max(0, amount)}px)`;
      } else if (kind === 2) {
        // Saturate: CSS `saturate()` keeps the original hue at amount=1,
        // matching the WebGPU shader's mix(luma, rgb, amount).
        mainCtx.filter = `saturate(${Math.max(0, amount)})`;
      } else if (kind === 3) {
        mainCtx.filter = `brightness(${Math.max(0, amount)})`;
      } else if (kind === 4) {
        mainCtx.filter = `contrast(${Math.max(0, amount)})`;
      } else if (kind === 5) {
        // Color-matrix (5x4 row-major, Skia-compatible 20 values) via an
        // inline SVG feColorMatrix; Canvas2D has no direct matrix filter.
        mainCtx.filter = colorMatrixFilter(rendererHandle, filter.matrixValues);
      }
      mainCtx.drawImage(offCanvas, 0, 0);
      mainCtx.restore();
      mainCtx.filter = "none";
      return ok();
    },

    draw_shader_effect(rendererHandle, name, x, y, width, height, uniforms, startX, startY, endX, endY, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      const shaderName = stringValue(name);
      // Consume the uniforms string handle before any early return so a
      // zero-size effect cannot leak the handle.
      const parsedUniforms = parseDoubleList(stringValue(uniforms));
      const effectAmount = parsedUniforms[0] ?? 8;
      const rect = {
        x: scx(renderer, Number(x) || 0),
        y: scy(renderer, Number(y) || 0),
        width: Math.max(0, scx(renderer, Number(width) || 0)),
        height: Math.max(0, scy(renderer, Number(height) || 0)),
      };
      if (rect.width <= 0 || rect.height <= 0) return ok();
      const c0 = cssColor({ r: r0, g: g0, b: b0, a: a0 });
      const c1 = cssColor({ r: r1, g: g1, b: b1, a: a1 });
      switch (shaderName) {
        case "checker":
          {
            // Mirror the WebGPU shader: local (0..1) x scale, alternating
            // c0/c1 cells (scale = uniforms[0], min 8).
            const cells = Math.max(8, Math.round(Number(effectAmount) || 8));
            const cellW = rect.width / cells;
            const cellH = rect.height / cells;
            ctx.fillStyle = c0;
            ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
            ctx.fillStyle = c1;
            for (let row = 0; row < cells; row += 1) {
              for (let col = 0; col < cells; col += 1) {
                if (((col + row) & 1) === 1) {
                  ctx.fillRect(
                    rect.x + col * cellW,
                    rect.y + row * cellH,
                    Math.ceil(cellW),
                    Math.ceil(cellH),
                  );
                }
              }
            }
          }
          break;
        case "solid":
          ctx.fillStyle = c0;
          ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
          break;
        case "linear-gradient-debug":
          {
            const gradient = ctx.createLinearGradient(
              scx(renderer, Number(startX) || 0), scy(renderer, Number(startY) || 0),
              scx(renderer, Number(endX) || 0), scy(renderer, Number(endY) || 0)
            );
            gradient.addColorStop(0, c0);
            gradient.addColorStop(1, c1);
            ctx.fillStyle = gradient;
            ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
          }
          break;
        case "vignette":
          {
            // Mirror the WebGPU shader:
            //   fade = 1 - smoothstep(0.25, max(amount, 0.8), length(centered))
            //   out  = vec4f(c0.rgb * fade, c0.a)
            // The color dims toward black while alpha stays at c0.a (the
            // gradient must not become transparent, or the backdrop shows
            // through on the fallback).
            const cx = rect.x + rect.width / 2;
            const cy = rect.y + rect.height / 2;
            const inner = 0.25;
            const outer = Math.max(0.8, Number(effectAmount) || 0.8);
            // The shader measures d = length(centered) in [-1,1]² space, where
            // d = 2 * dist / side for a square rect and reaches black at
            // d = outer. Scale the gradient radius by outer / sqrt(2) so the
            // canvas stop t = dist / radius lands on d/outer: t=1 (black) at
            // d=outer and the inner/outer stop at d=0.25, matching the WGSL
            // smoothstep endpoints for square rects (a circular gradient is
            // the Canvas2D approximation for non-square rects).
            const maxRadius = Math.hypot(rect.width, rect.height) * 0.5;
            const radius = (maxRadius * outer) / Math.SQRT2;
            const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(radius, 1));
            gradient.addColorStop(0, c0);
            gradient.addColorStop(inner / outer, c0);
            gradient.addColorStop(1, cssColor({ r: 0, g: 0, b: 0, a: Number(a0) || 1 }));
            ctx.fillStyle = gradient;
            ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
          }
          break;
        default:
          ctx.fillStyle = c0;
          ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
          break;
      }
      return ok();
    },

    present(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      syncTextSelectionLayer(renderer);
      return ok();
    },

    renderer_dispose(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return;
      disposeTextSelectionLayer(renderer.textSelection);
      // Remove the per-renderer SVG color-matrix filter node so repeated
      // create/dispose cycles do not leak DOM nodes.
      const matrixEntry = colorMatrixFilters.get(rendererHandle);
      if (matrixEntry) {
        matrixEntry.svg?.remove?.();
        colorMatrixFilters.delete(rendererHandle);
      }
      renderer.images.clear();
      renderer.loadedImages.clear();
      renderer.failedImages.clear();
      renderers.delete(rendererHandle);
    },
  };
}
