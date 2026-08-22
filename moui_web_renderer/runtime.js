// Browser WebGPU renderer runtime and application composition helper.
// canvas2d_runtime.js is loaded on demand as the Canvas2D fallback when WebGPU
// is unavailable (e.g. WebKitGTK, older browsers, restricted contexts).
import {
  connectWindowWeb,
  createWindowWebImports,
} from "../moui/backend/web/browser_runtime.js";

const VISUAL_STRIDE_FLOATS = 22;
const TEXT_STRIDE_FLOATS = 8;
const IMAGE_STRIDE_FLOATS = 9;
const ATLAS_SIZE = 2048;
const WEB_FONT_STACK = 'system-ui';
const ADVANCED_STRIDE_FLOATS = 44;

export function createImageResourceChangeNotifier(callback, scheduleRedraw) {
  const notify = typeof callback === "function" ? callback : undefined;
  const schedule = typeof scheduleRedraw === "function" ? scheduleRedraw : () => {};
  return event => {
    try {
      globalThis.__mouiWebRuntimeObservation?.recordEvent?.({
        kind: 92,
        name: "image_resource_change",
        ...(event ?? {}),
      });
      notify?.(event);
    } finally {
      schedule();
      globalThis.__mouiWebRuntimeObservation?.recordEvent?.({
        kind: 93,
        name: "image_repaint_request",
        source: event?.source ?? "",
        status: event?.status ?? "unknown",
      });
    }
  };
}

export function createWebGpuImports(options = {}) {
  if (!options.device || !options.format) {
    throw new Error("createWebGpuImports requires a pre-initialized WebGPU device. Use createWebGpuImportsAsync().");
  }

  const device = options.device;
  const format = options.format;
  const overlaySurfaceFormat = options.overlayFormat || "rgba8unorm";
  const strings = new Map();
  const surfaces = new Map();
  const renderers = new Map();
  const threeDSurfaces = new Map();
  const threeDRenderers = new Map();
  let nextStringHandle = 1;
  let nextSurfaceHandle = 1;
  let nextRendererHandle = 1;
  let nextThreeDSurfaceHandle = 1;
  let nextThreeDRendererHandle = 1;
  const measureCanvas = document.createElement("canvas");
  const measureContext = measureCanvas.getContext("2d");
  const notifyImageResourceChanged =
    typeof options.onImageResourceChange === "function"
      ? options.onImageResourceChange
      : () => {};
  const reportImageResourceChange = event => {
    try {
      notifyImageResourceChanged(event);
    } catch (error) {
      globalThis.console?.error?.("MoUI image resource notification failed", error);
    }
  };
  const recordRuntimeObservationEvent = event => {
    try {
      globalThis.__mouiWebRuntimeObservation?.recordEvent?.(event);
    } catch {
      // Observation recording is best-effort and must not affect rendering.
    }
  };
  const textSelectionOptions = options.textSelection ?? {};
  const textSelectionEnabled = textSelectionOptions.enabled === true;
  const textSelectionClassName =
    `${textSelectionOptions.className || "moui-text-selection-layer"}`;
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

  const getCanvas = id => {
    const canvas = document.getElementById(id);
    return canvas instanceof HTMLCanvasElement ? canvas : undefined;
  };

  const contextFor = canvas => {
    try {
      return canvas?.getContext?.("webgpu") ?? undefined;
    } catch {
      return undefined;
    }
  };

  const resizeCanvas = (canvas, width, height, scaleFactor) => {
    const dpr = Number(scaleFactor) || window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.round(Number(width) * dpr));
    canvas.height = Math.max(1, Math.round(Number(height) * dpr));
    canvas.style.width = `${Math.max(1, Number(width))}px`;
    canvas.style.height = `${Math.max(1, Number(height))}px`;
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
    syncTextSelectionLayerCursor(state);
  };

  const canvasCursorValue = canvas => {
    try {
      const explicit = `${canvas?.style?.cursor ?? ""}`.trim();
      const computed = explicit || `${globalThis.getComputedStyle?.(canvas)?.cursor ?? ""}`.trim();
      return !computed || computed === "auto" ? "default" : computed;
    } catch {
      return "default";
    }
  };

  const syncTextSelectionLayerCursor = state => {
    if (!state?.layer) return;
    state.layer.style.cursor = canvasCursorValue(state.canvas);
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
    // Input stays with canvas-host's capture-phase router. This layer only
    // exposes selectable text; it never redispatches synthetic canvas events.
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

  const intersectRects = (a, b) => {
    if (!a) return b;
    if (!b) return a;
    const x0 = Math.max(a.x, b.x);
    const y0 = Math.max(a.y, b.y);
    const x1 = Math.min(a.x + a.width, b.x + b.width);
    const y1 = Math.min(a.y + a.height, b.y + b.height);
    return {
      x: x0,
      y: y0,
      width: Math.max(0, x1 - x0),
      height: Math.max(0, y1 - y0),
    };
  };

  const rendererState = renderer => renderer.stateStack[renderer.stateStack.length - 1];

  const cloneState = state => ({
    opacity: state.opacity,
    transform: { ...state.transform },
    clip: state.clip ? { ...state.clip } : undefined,
  });

  const clampOpacity = value => Math.max(0, Math.min(1, Number(value)));

  const multiplyColorAlpha = (color, opacity) => ({
    r: color.r,
    g: color.g,
    b: color.b,
    a: color.a * opacity,
  });

  const cssPixels = value => `${Number(value) || 0}px`;

  const cssTextAlign = align => {
    switch (Number(align) || 0) {
      case 1: return "center";
      case 2: return "right";
      default: return "left";
    }
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

  const pushSelectableRun = (selection, state, renderer, text, frame, font, align) => {
    if (!text) return;
    const transformed = transformRect(state.transform, frame);
    const canvasClip = {
      x: 0,
      y: 0,
      width: Math.max(1, Number(renderer.width || renderer.surface.width || 1)),
      height: Math.max(1, Number(renderer.height || renderer.surface.height || 1)),
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

  const recordSelectableTextRun = (renderer, text, frame, font, align, alpha, segments) => {
    const selection = renderer.textSelection;
    if (!selection || !text || alpha <= 0.01) return;
    const state = rendererState(renderer);
    const logicalFrame = {
      x: Number(frame.x) || 0,
      y: Number(frame.y) || 0,
      width: Math.max(0, Number(frame.width) || 0),
      height: Math.max(0, Number(frame.height) || 0),
    };
    if (logicalFrame.width <= 0 || logicalFrame.height <= 0) return;
    if (segments?.length > 0) {
      for (const segment of segments) {
        pushSelectableRun(
          selection,
          state,
          renderer,
          segment.text,
          {
            x: Number(segment.x) || 0,
            y: logicalFrame.y,
            width: Math.max(0, Number(segment.width) || 0),
            height: logicalFrame.height,
          },
          font,
          0,
        );
      }
      return;
    }
    pushSelectableRun(selection, state, renderer, text, logicalFrame, font, align);
  };

  const selectableClusterKind = cluster => /^\s+$/.test(`${cluster ?? ""}`) ? "space" : "text";

  const buildSelectableTextSegments = (glyphs, startX) => {
    const segments = [];
    let current = null;
    let cursor = startX;
    const flush = () => {
      if (current && current.text.length > 0 && current.width > 0) {
        segments.push(current);
      }
      current = null;
    };
    for (const { cluster, glyph } of glyphs) {
      const width = Math.max(0, Number(glyph?.advance) || 0);
      const kind = selectableClusterKind(cluster);
      if (!current || current.kind !== kind) {
        flush();
        current = { kind, text: "", x: cursor, width: 0 };
      }
      current.text += cluster;
      current.width += width;
      cursor += width;
    }
    flush();
    return segments;
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
        record.span.style.display = "none";
        record.hidden = true;
      }
    }
  };

  const parseDoubleList = value => `${value ?? ""}`
    .split(",")
    .map(part => Number(part.trim()))
    .filter(value => Number.isFinite(value));

  const parseStrictDoubleList = value => {
    const source = `${value ?? ""}`;
    if (source.trim() === "") return [];
    const result = [];
    for (const part of source.split(",")) {
      const trimmed = part.trim();
      if (trimmed.length === 0) return undefined;
      const number = Number(trimmed);
      if (!Number.isFinite(number)) return undefined;
      result.push(number);
    }
    return result;
  };

  const maskClip = mask => {
    if (!mask || !mask.kind) return undefined;
    return {
      x: Number(mask.x) || 0,
      y: Number(mask.y) || 0,
      width: Math.max(0, Number(mask.width) || 0),
      height: Math.max(0, Number(mask.height) || 0),
    };
  };

  const maskRect = (mask, renderer) => {
    if (!mask || !mask.kind) {
      return { x: 0, y: 0, width: renderer.width, height: renderer.height, radius: 0, rounded: false };
    }
    return {
      x: Number(mask.x) || 0,
      y: Number(mask.y) || 0,
      width: Math.max(0, Number(mask.width) || 0),
      height: Math.max(0, Number(mask.height) || 0),
      radius: Math.max(0, Number(mask.radius) || 0),
      rounded: Number(mask.kind) === 2,
    };
  };

  const emptyMatrix = () => [
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
    0, 0, 0, 0,
  ];

  const normalizeFilter = filter => {
    if (!filter) return { kind: 0, amount: 0, matrix: emptyMatrix() };
    const kind = Number(filter.kind) || 0;
    const amount = Number(filter.amount);
    const matrix = emptyMatrix();
    if (kind === 4) {
      const values = parseDoubleList(filter.matrixValues);
      for (let i = 0; i < Math.min(values.length, matrix.length); i += 1) {
        matrix[i] = values[i];
      }
    }
    return {
      kind: kind + 1,
      amount: Number.isFinite(amount) ? amount : 1,
      matrix,
    };
  };

  const fallbackImageColor = source => {
    let hash = 2166136261;
    for (const ch of `${source ?? ""}`) {
      hash ^= ch.codePointAt(0) || 0;
      hash = Math.imul(hash, 16777619) >>> 0;
    }
    return {
      r: 0.25 + ((hash & 0xff) / 255) * 0.45,
      g: 0.25 + (((hash >> 8) & 0xff) / 255) * 0.45,
      b: 0.25 + (((hash >> 16) & 0xff) / 255) * 0.45,
      a: 1,
    };
  };

  const pushRendererItem = (renderer, item) => {
    const state = rendererState(renderer);
    const target = rendererScope(renderer);
    target.items.push({
      ...item,
      clip: state.clip ? { ...state.clip } : undefined,
    });
  };

  const rendererScope = renderer => renderer.scopeStack[renderer.scopeStack.length - 1];

  const newDrawScope = () => ({
    visualVertices: [],
    textVertices: [],
    imageVertices: [],
    advancedVertices: [],
    items: [],
  });

  const shaderKindForName = name => {
    switch (`${name ?? ""}`) {
      case "checker": return 1;
      case "solid": return 2;
      case "linear-gradient-debug": return 3;
      case "vignette": return 4;
      default: return 0;
    }
  };

  const pushAdvancedVertex = (scope, renderer, px, py, u, v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform) => {
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    const matrix = filter.matrix ?? emptyMatrix();
    const transformed = transformPoint(transform, px, py);
    scope.advancedVertices.push(
      transformed.x / w * 2 - 1,
      1 - transformed.y / h * 2,
      u, v,
      opacity,
      blendMode,
      shaderKind,
      effectAmount,
      (px - rect.x) / Math.max(rect.width, 0.0001),
      (py - rect.y) / Math.max(rect.height, 0.0001),
      filter.kind,
      filter.amount,
      color0.r, color0.g, color0.b, color0.a,
      color1.r, color1.g, color1.b, color1.a,
      ...matrix,
      Math.max(0, Number(mask?.width) || 0),
      Math.max(0, Number(mask?.height) || 0),
      Math.max(0, Number(mask?.radius) || 0),
      mask?.rounded ? 1 : 0,
    );
  };

  const pushAdvancedQuad = (renderer, rect, texture, view, sampler, filterInput, opacity, blendMode, shaderKind = 0, effectAmount = 0, color0 = { r: 1, g: 1, b: 1, a: 1 }, color1 = color0, clip, options = {}) => {
    if (!texture || rect.width <= 0 || rect.height <= 0) return;
    const scope = rendererScope(renderer);
    const filter = normalizeFilter(filterInput);
    const uvRect = options.uvRect;
    const transform = options.transform ?? identityTransform();
    const mask = options.mask ?? { width: rect.width, height: rect.height, radius: 0, rounded: false };
    const start = scope.advancedVertices.length / ADVANCED_STRIDE_FLOATS;
    const x0 = rect.x;
    const y0 = rect.y;
    const x1 = rect.x + rect.width;
    const y1 = rect.y + rect.height;
    const uvFor = (px, py, fallbackU, fallbackV) => uvRect
      ? {
          u: px / Math.max(renderer.width, 0.0001),
          v: py / Math.max(renderer.height, 0.0001),
        }
      : { u: fallbackU, v: fallbackV };
    const uv0 = uvFor(x0, y0, 0, 0);
    const uv1 = uvFor(x0, y1, 0, 1);
    const uv2 = uvFor(x1, y1, 1, 1);
    const uv3 = uvFor(x1, y0, 1, 0);
    pushAdvancedVertex(scope, renderer, x0, y0, uv0.u, uv0.v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform);
    pushAdvancedVertex(scope, renderer, x0, y1, uv1.u, uv1.v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform);
    pushAdvancedVertex(scope, renderer, x1, y1, uv2.u, uv2.v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform);
    pushAdvancedVertex(scope, renderer, x0, y0, uv0.u, uv0.v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform);
    pushAdvancedVertex(scope, renderer, x1, y1, uv2.u, uv2.v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform);
    pushAdvancedVertex(scope, renderer, x1, y0, uv3.u, uv3.v, opacity, blendMode, shaderKind, effectAmount, filter, rect, color0, color1, mask, transform);
    scope.items.push({
      type: "advanced",
      start,
      count: 6,
      texture,
      view,
      sampler,
      bindGroup: Number(blendMode) === 3 ? undefined : createAdvancedBindGroup(blendMode, sampler, view),
      bindGroupOwned: Number(blendMode) !== 3,
      blendMode,
      clip,
    });
  };

  const createSamplerTextureBindGroup = (layout, sampler, view, backdropView, includeBackdrop = false) => {
    const entries = [
      { binding: 0, resource: sampler },
      { binding: 1, resource: view },
    ];
    if (includeBackdrop) {
      entries.push({ binding: 2, resource: backdropView ?? view });
    }
    return device.createBindGroup({ layout, entries });
  };

  const createAdvancedBindGroup = (blendMode, sampler, view, backdropView) => {
    const overlay = Number(blendMode) === 3;
    const layout = overlay
      ? advancedOverlayPipeline.getBindGroupLayout(0)
      : advancedPipelineForBlend(blendMode).getBindGroupLayout(0);
    return createSamplerTextureBindGroup(layout, sampler, view, backdropView, true);
  };

  const setPassClip = (pass, renderer, clip) => {
    const dpr = Number(renderer.surface.scaleFactor) || 1;
    const width = Math.max(1, Math.round(renderer.width * dpr));
    const height = Math.max(1, Math.round(renderer.height * dpr));
    if (!clip) {
      pass.setScissorRect(0, 0, width, height);
      return true;
    }
    const x = Math.max(0, Math.floor(clip.x * dpr));
    const y = Math.max(0, Math.floor(clip.y * dpr));
    const right = Math.min(width, Math.ceil((clip.x + clip.width) * dpr));
    const bottom = Math.min(height, Math.ceil((clip.y + clip.height) * dpr));
    const scissorWidth = Math.max(0, right - x);
    const scissorHeight = Math.max(0, bottom - y);
    if (scissorWidth <= 0 || scissorHeight <= 0) return false;
    pass.setScissorRect(x, y, scissorWidth, scissorHeight);
    return true;
  };

  const visualModule = device.createShaderModule({
    code: `
      struct VSOut {
        @builtin(position) position: vec4f,
        @location(0) local: vec2f,
        @location(1) sizeRadiusModeStroke: vec4f,
        @location(2) blurStart: vec4f,
        @location(3) end: vec2f,
        @location(4) color0: vec4f,
        @location(5) color1: vec4f,
      };

      @vertex
      fn vs_main(
        @location(0) position: vec2f,
        @location(1) local: vec2f,
        @location(2) sizeRadiusModeStroke: vec4f,
        @location(3) blurStart: vec4f,
        @location(4) end: vec2f,
        @location(5) color0: vec4f,
        @location(6) color1: vec4f,
      ) -> VSOut {
        var out: VSOut;
        out.position = vec4f(position, 0.0, 1.0);
        out.local = local;
        out.sizeRadiusModeStroke = sizeRadiusModeStroke;
        out.blurStart = blurStart;
        out.end = end;
        out.color0 = color0;
        out.color1 = color1;
        return out;
      }

      fn rounded_box_sdf(p: vec2f, halfSize: vec2f, radius: f32) -> f32 {
        let r = min(radius, min(halfSize.x, halfSize.y));
        let q = abs(p) - (halfSize - vec2f(r, r));
        return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - r;
      }

      fn linear_gradient_color(local: vec2f, start: vec2f, end: vec2f, c0: vec4f, c1: vec4f) -> vec4f {
        let axis = end - start;
        let denom = max(dot(axis, axis), 0.0001);
        let t = clamp(dot(local - start, axis) / denom, 0.0, 1.0);
        return mix(c0, c1, t);
      }

      fn radial_gradient_color(local: vec2f, center: vec2f, radius: f32, c0: vec4f, c1: vec4f) -> vec4f {
        let t = clamp(distance(local, center) / max(radius, 0.0001), 0.0, 1.0);
        return mix(c0, c1, t);
      }

      fn brush_color(local: vec2f, start: vec2f, end: vec2f, c0: vec4f, c1: vec4f, kind: f32) -> vec4f {
        if (kind > 0.5) {
          return radial_gradient_color(local, start, end.x, c0, c1);
        }
        return linear_gradient_color(local, start, end, c0, c1);
      }

      @fragment
      fn fs_main(in: VSOut) -> @location(0) vec4f {
        let width = in.sizeRadiusModeStroke.x;
        let height = in.sizeRadiusModeStroke.y;
        let radius = in.sizeRadiusModeStroke.z;
        let mode = in.sizeRadiusModeStroke.w;
        let strokeWidth = in.blurStart.x;
        let blurRadius = in.blurStart.y;
        let center = vec2f(width * 0.5, height * 0.5);
        if (mode > 2.5) {
          return brush_color(in.local, in.blurStart.zw, in.end, in.color0, in.color1, in.blurStart.y);
        }
        let dist = rounded_box_sdf(in.local - center, center, radius);
        var alpha = 1.0 - smoothstep(-0.5, 0.5, dist);
        if (mode > 1.5) {
          let spread = max(blurRadius, 1.0);
          alpha = 1.0 - smoothstep(-spread, spread, dist);
          alpha = alpha * alpha * in.color0.a;
          return vec4f(in.color0.rgb, alpha);
        }
        if (mode > 0.5) {
          let innerRadius = max(radius - strokeWidth, 0.0);
          let innerHalf = max(center - vec2f(strokeWidth), vec2f(0.0));
          let innerDist = rounded_box_sdf(in.local - center, innerHalf, innerRadius);
          let innerAlpha = 1.0 - smoothstep(-0.5, 0.5, innerDist);
          alpha = max(alpha - innerAlpha, 0.0);
        }
        let color = brush_color(in.local, in.blurStart.zw, in.end, in.color0, in.color1, in.blurStart.y);
        return vec4f(color.rgb, color.a * alpha);
      }
    `,
  });

  const visualPipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: {
      module: visualModule,
      entryPoint: "vs_main",
      buffers: [{
        arrayStride: VISUAL_STRIDE_FLOATS * 4,
        attributes: [
          { shaderLocation: 0, offset: 0, format: "float32x2" },
          { shaderLocation: 1, offset: 8, format: "float32x2" },
          { shaderLocation: 2, offset: 16, format: "float32x4" },
          { shaderLocation: 3, offset: 32, format: "float32x4" },
          { shaderLocation: 4, offset: 48, format: "float32x2" },
          { shaderLocation: 5, offset: 56, format: "float32x4" },
          { shaderLocation: 6, offset: 72, format: "float32x4" },
        ],
      }],
    },
    fragment: {
      module: visualModule,
      entryPoint: "fs_main",
      targets: [{ format, blend: alphaBlend() }],
    },
    primitive: { topology: "triangle-list" },
  });

  const textModule = device.createShaderModule({
    code: `
      struct VSOut {
        @builtin(position) position: vec4f,
        @location(0) uv: vec2f,
        @location(1) color: vec4f,
      };

      @vertex
      fn vs_main(
        @location(0) position: vec2f,
        @location(1) uv: vec2f,
        @location(2) color: vec4f,
      ) -> VSOut {
        var out: VSOut;
        out.position = vec4f(position, 0.0, 1.0);
        out.uv = uv;
        out.color = color;
        return out;
      }

      @group(0) @binding(0) var glyphSampler: sampler;
      @group(0) @binding(1) var glyphAtlas: texture_2d<f32>;

      @fragment
      fn fs_main(in: VSOut) -> @location(0) vec4f {
        let sample = textureSample(glyphAtlas, glyphSampler, in.uv);
        if (in.color.r < -0.5) {
          return vec4f(sample.rgb, sample.a * in.color.a);
        }
        return vec4f(in.color.rgb, in.color.a * sample.a);
      }
    `,
  });

  const textPipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: {
      module: textModule,
      entryPoint: "vs_main",
      buffers: [{
        arrayStride: TEXT_STRIDE_FLOATS * 4,
        attributes: [
          { shaderLocation: 0, offset: 0, format: "float32x2" },
          { shaderLocation: 1, offset: 8, format: "float32x2" },
          { shaderLocation: 2, offset: 16, format: "float32x4" },
        ],
      }],
    },
    fragment: {
      module: textModule,
      entryPoint: "fs_main",
      targets: [{ format, blend: alphaBlend() }],
    },
    primitive: { topology: "triangle-list" },
  });

  const imageModule = device.createShaderModule({
    code: `
      struct VSOut {
        @builtin(position) position: vec4f,
        @location(0) uv: vec2f,
        @location(1) opacity: f32,
      };

      @vertex
      fn vs_main(
        @location(0) position: vec2f,
        @location(1) uv: vec2f,
        @location(2) opacity: f32,
      ) -> VSOut {
        var out: VSOut;
        out.position = vec4f(position, 0.0, 1.0);
        out.uv = uv;
        out.opacity = opacity;
        return out;
      }

      @group(0) @binding(0) var imageSampler: sampler;
      @group(0) @binding(1) var imageTexture: texture_2d<f32>;

      @fragment
      fn fs_main(in: VSOut) -> @location(0) vec4f {
        let sample = textureSample(imageTexture, imageSampler, in.uv);
        return vec4f(sample.rgb, sample.a * in.opacity);
      }
    `,
  });

  const imagePipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: {
      module: imageModule,
      entryPoint: "vs_main",
      buffers: [{
        arrayStride: IMAGE_STRIDE_FLOATS * 4,
        attributes: [
          { shaderLocation: 0, offset: 0, format: "float32x2" },
          { shaderLocation: 1, offset: 8, format: "float32x2" },
          { shaderLocation: 2, offset: 16, format: "float32" },
        ],
      }],
    },
    fragment: {
      module: imageModule,
      entryPoint: "fs_main",
      targets: [{ format, blend: alphaBlend() }],
    },
    primitive: { topology: "triangle-list" },
  });

  const advancedBlend = mode => {
    switch (Number(mode) || 0) {
      case 1:
        return {
          color: {
            srcFactor: "dst",
            dstFactor: "zero",
            operation: "add",
          },
          alpha: {
            srcFactor: "one",
            dstFactor: "one-minus-src-alpha",
            operation: "add",
          },
        };
      case 2:
        return {
          color: {
            srcFactor: "one",
            dstFactor: "one-minus-src",
            operation: "add",
          },
          alpha: {
            srcFactor: "one",
            dstFactor: "one-minus-src-alpha",
            operation: "add",
          },
        };
      case 4:
        return {
          color: {
            srcFactor: "one",
            dstFactor: "one",
            operation: "min",
          },
          alpha: {
            srcFactor: "one",
            dstFactor: "one-minus-src-alpha",
            operation: "add",
          },
        };
      case 5:
        return {
          color: {
            srcFactor: "one",
            dstFactor: "one",
            operation: "max",
          },
          alpha: {
            srcFactor: "one",
            dstFactor: "one-minus-src-alpha",
            operation: "add",
          },
        };
      default:
        return alphaBlend();
    }
  };

  const advancedModule = device.createShaderModule({
    code: `
      struct VSOut {
        @builtin(position) position: vec4f,
        @location(0) uv: vec2f,
        @location(1) meta0: vec4f,
        @location(2) meta1: vec4f,
        @location(3) color0: vec4f,
        @location(4) color1: vec4f,
        @location(5) matrix0: vec4f,
        @location(6) matrix1: vec4f,
        @location(7) matrix2: vec4f,
        @location(8) matrix3: vec4f,
        @location(9) matrix4: vec4f,
        @location(10) rectMask: vec4f,
      };

      @vertex
      fn vs_main(
        @location(0) position: vec2f,
        @location(1) uv: vec2f,
        @location(2) meta0: vec4f,
        @location(3) meta1: vec4f,
        @location(4) color0: vec4f,
        @location(5) color1: vec4f,
        @location(6) matrix0: vec4f,
        @location(7) matrix1: vec4f,
        @location(8) matrix2: vec4f,
        @location(9) matrix3: vec4f,
        @location(10) matrix4: vec4f,
        @location(11) rectMask: vec4f,
      ) -> VSOut {
        var out: VSOut;
        out.position = vec4f(position, 0.0, 1.0);
        out.uv = uv;
        out.meta0 = meta0;
        out.meta1 = meta1;
        out.color0 = color0;
        out.color1 = color1;
        out.matrix0 = matrix0;
        out.matrix1 = matrix1;
        out.matrix2 = matrix2;
        out.matrix3 = matrix3;
        out.matrix4 = matrix4;
        out.rectMask = rectMask;
        return out;
      }

      @group(0) @binding(0) var layerSampler: sampler;
      @group(0) @binding(1) var layerTexture: texture_2d<f32>;
      @group(0) @binding(2) var backdropTexture: texture_2d<f32>;

      fn checker(local: vec2f, amount: f32, c0: vec4f, c1: vec4f) -> vec4f {
        let scale = max(amount, 8.0);
        let cell = floor(local * scale);
        let alt = (i32(cell.x) + i32(cell.y)) & 1;
        if (alt == 0) {
          return c0;
        }
        return c1;
      }

      fn vignette(local: vec2f, amount: f32, c0: vec4f) -> vec4f {
        let centered = local * 2.0 - vec2f(1.0);
        let fade = 1.0 - smoothstep(0.25, max(amount, 0.8), length(centered));
        return vec4f(c0.rgb * fade, c0.a);
      }

      fn blur_sample(uv: vec2f, amount: f32) -> vec4f {
        let dims = vec2f(textureDimensions(layerTexture));
        let step = vec2f(1.0) / max(dims, vec2f(1.0));
        let radius = max(amount, 1.0);
        var color = vec4f(0.0);
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f(-1.0, -1.0), 0.0) * 0.0625;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f( 0.0, -1.0), 0.0) * 0.125;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f( 1.0, -1.0), 0.0) * 0.0625;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f(-1.0,  0.0), 0.0) * 0.125;
        color += textureSampleLevel(layerTexture, layerSampler, uv, 0.0) * 0.25;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f( 1.0,  0.0), 0.0) * 0.125;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f(-1.0,  1.0), 0.0) * 0.0625;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f( 0.0,  1.0), 0.0) * 0.125;
        color += textureSampleLevel(layerTexture, layerSampler, uv + step * radius * vec2f( 1.0,  1.0), 0.0) * 0.0625;
        return color;
      }

      fn rounded_box_sdf_advanced(p: vec2f, halfSize: vec2f, radius: f32) -> f32 {
        let r = min(radius, min(halfSize.x, halfSize.y));
        let q = abs(p) - (halfSize - vec2f(r));
        return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - r;
      }

      fn apply_filter(color: vec4f, kind: i32, amount: f32, m0: vec4f, m1: vec4f, m2: vec4f, m3: vec4f, m4: vec4f) -> vec4f {
        if (kind == 2) {
          let luma = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));
          return vec4f(mix(vec3f(luma), color.rgb, amount), color.a);
        }
        if (kind == 3) {
          return vec4f(color.rgb * amount, color.a);
        }
        if (kind == 4) {
          return vec4f((color.rgb - vec3f(0.5)) * amount + vec3f(0.5), color.a);
        }
        if (kind == 5) {
          let v = vec4f(color.rgb, color.a);
          return vec4f(
            dot(v, m0) + m4.x,
            dot(v, m1) + m4.y,
            dot(v, m2) + m4.z,
            dot(v, m3) + m4.w,
          );
        }
        return color;
      }

      fn overlayChannel(base: f32, source: f32) -> f32 {
        if (base <= 0.5) {
          return 2.0 * base * source;
        }
        return 1.0 - 2.0 * (1.0 - base) * (1.0 - source);
      }

      fn overlayRgb(base: vec3f, source: vec3f) -> vec3f {
        return vec3f(
          overlayChannel(base.r, source.r),
          overlayChannel(base.g, source.g),
          overlayChannel(base.b, source.b),
        );
      }

      @fragment
      fn fs_main(in: VSOut) -> @location(0) vec4f {
        let opacity = in.meta0.x;
        let shaderKind = i32(in.meta0.z + 0.5);
        let effectAmount = in.meta0.w;
        let filterKind = i32(in.meta1.z + 0.5);
        let filterAmount = in.meta1.w;
        var sample = textureSample(layerTexture, layerSampler, in.uv);
        if (shaderKind == 1) {
          sample = checker(in.meta1.xy, effectAmount, in.color0, in.color1);
        } else if (shaderKind == 2) {
          sample = vec4f(in.color0.rgb, in.color0.a);
        } else if (shaderKind == 3) {
          sample = vec4f(mix(in.color0.rgb, in.color1.rgb, clamp(in.meta1.x, 0.0, 1.0)), mix(in.color0.a, in.color1.a, clamp(in.meta1.x, 0.0, 1.0)));
        } else if (shaderKind == 4) {
          sample = vignette(in.meta1.xy, effectAmount, in.color0);
        } else if (shaderKind == 5) {
          sample = vec4f(in.color0.rgb, in.color0.a);
        }
        if (filterKind == 1) {
          sample = blur_sample(in.uv, filterAmount);
        }
        sample = apply_filter(sample, filterKind, filterAmount, in.matrix0, in.matrix1, in.matrix2, in.matrix3, in.matrix4);
        let backdrop = textureSampleLevel(backdropTexture, layerSampler, in.uv, 0.0);
        var maskAlpha = 1.0;
        if (in.rectMask.w > 0.5) {
          let maskSize = in.rectMask.xy;
          let local = in.meta1.xy * maskSize;
          let dist = rounded_box_sdf_advanced(local - maskSize * 0.5, maskSize * 0.5, in.rectMask.z);
          maskAlpha = 1.0 - smoothstep(-0.5, 0.5, dist);
        }
        if (i32(in.meta0.y + 0.5) == 3) {
          let sourceAlpha = clamp(sample.a * opacity * maskAlpha, 0.0, 1.0);
          let blended = overlayRgb(backdrop.rgb, sample.rgb);
          let outRgb = mix(backdrop.rgb, blended, sourceAlpha);
          let outAlpha = sourceAlpha + backdrop.a * (1.0 - sourceAlpha);
          return vec4f(outRgb, outAlpha);
        }
        return vec4f(sample.rgb, sample.a * opacity * maskAlpha);
      }
    `,
  });

  const createAdvancedPipeline = (blendMode, options = {}) => device.createRenderPipeline({
    layout: "auto",
    vertex: {
      module: advancedModule,
      entryPoint: "vs_main",
      buffers: [{
        arrayStride: ADVANCED_STRIDE_FLOATS * 4,
        attributes: [
          { shaderLocation: 0, offset: 0, format: "float32x2" },
          { shaderLocation: 1, offset: 8, format: "float32x2" },
          { shaderLocation: 2, offset: 16, format: "float32x4" },
          { shaderLocation: 3, offset: 32, format: "float32x4" },
          { shaderLocation: 4, offset: 48, format: "float32x4" },
          { shaderLocation: 5, offset: 64, format: "float32x4" },
          { shaderLocation: 6, offset: 80, format: "float32x4" },
          { shaderLocation: 7, offset: 96, format: "float32x4" },
          { shaderLocation: 8, offset: 112, format: "float32x4" },
          { shaderLocation: 9, offset: 128, format: "float32x4" },
          { shaderLocation: 10, offset: 144, format: "float32x4" },
          { shaderLocation: 11, offset: 160, format: "float32x4" },
        ],
      }],
    },
    fragment: {
      module: advancedModule,
      entryPoint: "fs_main",
      targets: [{ format, blend: options.disableBlend ? undefined : advancedBlend(blendMode) }],
    },
    primitive: { topology: "triangle-list" },
  });

  const advancedPipelines = new Map();
  const advancedPipelineForBlend = blendMode => {
    const key = Number(blendMode) || 0;
    let pipeline = advancedPipelines.get(key);
    if (!pipeline) {
      pipeline = createAdvancedPipeline(key);
      advancedPipelines.set(key, pipeline);
    }
    return pipeline;
  };

  const advancedOverlayPipeline = createAdvancedPipeline(3, { disableBlend: true });

  const textureCopyModule = device.createShaderModule({
    code: `
      struct VSOut {
        @builtin(position) position: vec4f,
        @location(0) uv: vec2f,
      };

      @vertex
      fn vs_main(@builtin(vertex_index) vid: u32) -> VSOut {
        var positions = array<vec2f, 3>(
          vec2f(-1.0, -1.0),
          vec2f( 3.0, -1.0),
          vec2f(-1.0,  3.0),
        );
        var uvs = array<vec2f, 3>(
          vec2f(0.0, 1.0),
          vec2f(2.0, 1.0),
          vec2f(0.0, -1.0),
        );
        var out: VSOut;
        out.position = vec4f(positions[vid], 0.0, 1.0);
        out.uv = uvs[vid];
        return out;
      }

      @group(0) @binding(0) var sourceSampler: sampler;
      @group(0) @binding(1) var sourceTexture: texture_2d<f32>;
      @group(0) @binding(2) var unusedTexture: texture_2d<f32>;

      @fragment
      fn fs_main(in: VSOut) -> @location(0) vec4f {
        return textureSample(sourceTexture, sourceSampler, in.uv);
      }
    `,
  });

  const textureCopyPipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: {
      module: textureCopyModule,
      entryPoint: "vs_main",
    },
    fragment: {
      module: textureCopyModule,
      entryPoint: "fs_main",
      targets: [{ format: overlaySurfaceFormat }],
    },
    primitive: { topology: "triangle-list" },
  });

  const surfaceSampler = device.createSampler({
    magFilter: "linear",
    minFilter: "linear",
    addressModeU: "clamp-to-edge",
    addressModeV: "clamp-to-edge",
  });

  const pushVisualVertex = (renderer, rect, px, py, radius, mode, strokeWidth, blurRadius, start, end, c0, c1) => {
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    const transformed = transformPoint(rendererState(renderer).transform, px, py);
    rendererScope(renderer).visualVertices.push(
      transformed.x / w * 2 - 1,
      1 - transformed.y / h * 2,
      px - rect.x,
      py - rect.y,
      rect.width,
      rect.height,
      Math.max(0, Math.min(radius, Math.min(rect.width, rect.height) / 2)),
      mode,
      strokeWidth,
      blurRadius,
      start.x - rect.x,
      start.y - rect.y,
      end.x - rect.x,
      end.y - rect.y,
      c0.r, c0.g, c0.b, c0.a,
      c1.r, c1.g, c1.b, c1.a,
    );
  };

  const pushVisualQuad = (renderer, rect, radius, mode, strokeWidth, blurRadius, start, end, c0, c1) => {
    if (rect.width <= 0 || rect.height <= 0) return;
    const scope = rendererScope(renderer);
    const startIndex = scope.visualVertices.length / VISUAL_STRIDE_FLOATS;
    const state = rendererState(renderer);
    const color0 = multiplyColorAlpha(c0, state.opacity);
    const color1 = multiplyColorAlpha(c1, state.opacity);
    const x0 = rect.x;
    const y0 = rect.y;
    const x1 = rect.x + rect.width;
    const y1 = rect.y + rect.height;
    pushVisualVertex(renderer, rect, x0, y0, radius, mode, strokeWidth, blurRadius, start, end, color0, color1);
    pushVisualVertex(renderer, rect, x0, y1, radius, mode, strokeWidth, blurRadius, start, end, color0, color1);
    pushVisualVertex(renderer, rect, x1, y1, radius, mode, strokeWidth, blurRadius, start, end, color0, color1);
    pushVisualVertex(renderer, rect, x0, y0, radius, mode, strokeWidth, blurRadius, start, end, color0, color1);
    pushVisualVertex(renderer, rect, x1, y1, radius, mode, strokeWidth, blurRadius, start, end, color0, color1);
    pushVisualVertex(renderer, rect, x1, y0, radius, mode, strokeWidth, blurRadius, start, end, color0, color1);
    pushRendererItem(renderer, { type: "visual", start: startIndex, count: 6 });
  };

  const pushPathMesh = (renderer, payload) => {
    const stride = 15;
    const values = parseStrictDoubleList(payload);
    if (!values || values.length < stride * 3 || values.length % (stride * 3) !== 0) return;
    const scope = rendererScope(renderer);
    const startIndex = scope.visualVertices.length / VISUAL_STRIDE_FLOATS;
    const state = rendererState(renderer);
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    for (let index = 0; index + stride - 1 < values.length; index += stride) {
      const transformed = transformPoint(state.transform, values[index], values[index + 1]);
      const alpha0 = values[index + 10] * state.opacity;
      const alpha1 = values[index + 14] * state.opacity;
      scope.visualVertices.push(
        transformed.x / w * 2 - 1,
        1 - transformed.y / h * 2,
        values[index], values[index + 1],
        0, 0,
        0,
        3,
        0,
        values[index + 2],
        values[index + 3], values[index + 4],
        values[index + 5], values[index + 6],
        values[index + 7], values[index + 8], values[index + 9], alpha0,
        values[index + 11], values[index + 12], values[index + 13], alpha1,
      );
    }
    const count = scope.visualVertices.length / VISUAL_STRIDE_FLOATS - startIndex;
    if (count > 0) {
      pushRendererItem(renderer, { type: "visual", start: startIndex, count });
    }
  };

  const pushSolidRounded = (renderer, x, y, width, height, radius, color, mode = 0, strokeWidth = 0) => {
    const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
    pushVisualQuad(renderer, rect, Number(radius), mode, Number(strokeWidth), 0, { x: rect.x, y: rect.y }, { x: rect.x + 1, y: rect.y }, color, color);
  };

  const pushGradientRounded = (renderer, x, y, width, height, radius, strokeWidth, start, end, c0, c1, mode) => {
    const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
    pushVisualQuad(renderer, rect, Number(radius), mode, Number(strokeWidth), 0, start, end, c0, c1);
  };

  const pushRadialRounded = (renderer, x, y, width, height, radius, strokeWidth, center, gradientRadius, c0, c1, mode) => {
    const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
    pushVisualQuad(
      renderer,
      rect,
      Number(radius),
      mode,
      Number(strokeWidth),
      1,
      center,
      {
        x: rect.x + Math.max(0.0001, Number(gradientRadius) || 0),
        y: rect.y,
      },
      c0,
      c1,
    );
  };

  const summarizeGlyphPixels = image => {
    let alphaPixels = 0;
    let highSaturationPixels = 0;
    for (let index = 0; index < image.data.length; index += 4) {
      const r = image.data[index];
      const g = image.data[index + 1];
      const b = image.data[index + 2];
      const a = image.data[index + 3];
      if (a < 24) continue;
      alphaPixels += 1;
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      if (max - min >= 64 && max >= 140) {
        highSaturationPixels += 1;
      }
    }
    return { alphaPixels, highSaturationPixels };
  };

  const fallbackClusterAdvance = (cluster, fontSize) => {
    let width = 0;
    for (const char of `${cluster ?? ""}`) {
      width += textLayoutAdvance(char, fontSize);
    }
    return width;
  };

  const ensureGlyph = (renderer, cluster, font) => {
    const dpr = Number(renderer.surface.scaleFactor) || 1;
    const wantsColorGlyph = isEmojiCluster(cluster);
    const key = `${dpr}|${font.style}|${font.weight}|${font.size}|${font.family}|${wantsColorGlyph ? "rgba" : "alpha"}|${cluster}`;
    const cached = renderer.glyphs.get(key);
    if (cached) return cached;
    const ctx = renderer.glyphContext;
    const physicalSize = font.size * dpr;
    ctx.font = `${font.style} ${font.weight} ${physicalSize}px ${font.family}`;
    ctx.textAlign = "left";
    ctx.textBaseline = "alphabetic";
    const metrics = ctx.measureText(cluster);
    const left = Math.ceil(Math.max(1, -metrics.actualBoundingBoxLeft));
    const right = Math.ceil(Math.max(1, metrics.actualBoundingBoxRight));
    const ascent = Math.ceil(Math.max(physicalSize * 0.8, metrics.actualBoundingBoxAscent || physicalSize * 0.8));
    const descent = Math.ceil(Math.max(physicalSize * 0.25, metrics.actualBoundingBoxDescent || physicalSize * 0.25));
    const padding = Math.max(2, Math.ceil(2 * dpr));
    const width = Math.max(1, left + right + padding * 2);
    const height = Math.max(1, ascent + descent + padding * 2);
    const placed = placeGlyph(renderer, width, height);
    if (!placed) return undefined;
    ctx.clearRect(0, 0, renderer.glyphCanvas.width, renderer.glyphCanvas.height);
    ctx.fillStyle = wantsColorGlyph ? "black" : "white";
    ctx.font = `${font.style} ${font.weight} ${physicalSize}px ${font.family}`;
    ctx.fillText(cluster, left + padding, ascent + padding);
    const image = ctx.getImageData(0, 0, width, height);
    const pixelSummary = summarizeGlyphPixels(image);
    const colorGlyph = wantsColorGlyph && pixelSummary.highSaturationPixels >= 8;
    device.queue.writeTexture(
      { texture: renderer.atlasTexture, origin: { x: placed.x, y: placed.y } },
      image.data,
      { bytesPerRow: width * 4, rowsPerImage: height },
      { width, height },
    );
    const glyph = {
      x: placed.x,
      y: placed.y,
      width: width / dpr,
      height: height / dpr,
      textureWidth: width,
      textureHeight: height,
      offsetX: -(left + padding) / dpr,
      offsetY: -(ascent + padding) / dpr,
      advance: metrics.width > 0 ? metrics.width / dpr : fallbackClusterAdvance(cluster, font.size),
      colorGlyph,
      pixelSummary,
    };
    if (wantsColorGlyph) {
      recordRuntimeObservationEvent({
        kind: 94,
        name: colorGlyph ? "text_color_glyph" : "text_emoji_glyph",
        text: cluster,
        codepoints: codepointsFor(cluster).map(codepointHex),
        format: colorGlyph ? "rgba" : "alpha",
        fontFamily: font.family,
        fontStyle: font.style,
        fontWeight: font.weight,
        fontSize: font.size,
        glyphKey: key,
        glyphWidth: glyph.width,
        glyphHeight: glyph.height,
        highSaturationPixels: pixelSummary.highSaturationPixels,
        alphaPixels: pixelSummary.alphaPixels,
      });
    }
    renderer.glyphs.set(key, glyph);
    return glyph;
  };

  const placeGlyph = (renderer, width, height) => {
    const paddedWidth = width + 2;
    const paddedHeight = height + 2;
    if (paddedWidth > ATLAS_SIZE || paddedHeight > ATLAS_SIZE) return undefined;
    if (renderer.atlasX + paddedWidth > ATLAS_SIZE) {
      renderer.atlasX = 0;
      renderer.atlasY += renderer.atlasShelf;
      renderer.atlasShelf = 0;
    }
    if (renderer.atlasY + paddedHeight > ATLAS_SIZE) {
      renderer.glyphs.clear();
      renderer.atlasX = 0;
      renderer.atlasY = 0;
      renderer.atlasShelf = 0;
    }
    const x = renderer.atlasX + 1;
    const y = renderer.atlasY + 1;
    renderer.atlasX += paddedWidth;
    renderer.atlasShelf = Math.max(renderer.atlasShelf, paddedHeight);
    return { x, y };
  };

  const pushTextQuad = (renderer, x, y, glyph, color) => {
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    const x0 = x;
    const y0 = y;
    const x1 = x + glyph.width;
    const y1 = y + glyph.height;
    const u0 = glyph.x / ATLAS_SIZE;
    const v0 = glyph.y / ATLAS_SIZE;
    const u1 = (glyph.x + glyph.textureWidth) / ATLAS_SIZE;
    const v1 = (glyph.y + glyph.textureHeight) / ATLAS_SIZE;
    const push = (px, py, u, v) => {
      const transformed = transformPoint(rendererState(renderer).transform, px, py);
      rendererScope(renderer).textVertices.push(
      transformed.x / w * 2 - 1,
      1 - transformed.y / h * 2,
      u, v,
      color.r, color.g, color.b, color.a,
      );
    };
    push(x0, y0, u0, v0);
    push(x0, y1, u0, v1);
    push(x1, y1, u1, v1);
    push(x0, y0, u0, v0);
    push(x1, y1, u1, v1);
    push(x1, y0, u1, v0);
  };

  const textAlignExtra = (align, width, total) => {
    const extra = Math.max(0, Number(width) - total);
    switch (Number(align) || 0) {
      case 1:
        return extra / 2;
      case 2:
        return extra;
      default:
        return 0;
    }
  };

  const inRange = (value, start, end) => value >= start && value <= end;

  const isZeroWidthTextCodepoint = codepoint =>
    inRange(codepoint, 0x0300, 0x036f) ||
    inRange(codepoint, 0x1ab0, 0x1aff) ||
    inRange(codepoint, 0x1dc0, 0x1dff) ||
    inRange(codepoint, 0x20d0, 0x20ff) ||
    inRange(codepoint, 0xfe20, 0xfe2f);

  const isFullwidthTextCodepoint = codepoint =>
    inRange(codepoint, 0x1100, 0x115f) ||
    inRange(codepoint, 0x2329, 0x232a) ||
    inRange(codepoint, 0x2e80, 0xa4cf) ||
    inRange(codepoint, 0xac00, 0xd7a3) ||
    inRange(codepoint, 0xf900, 0xfaff) ||
    inRange(codepoint, 0xfe10, 0xfe19) ||
    inRange(codepoint, 0xfe30, 0xfe6f) ||
    inRange(codepoint, 0xff00, 0xff60) ||
    inRange(codepoint, 0xffe0, 0xffe6);

  const codepointsFor = text => Array.from(`${text ?? ""}`).map(ch => ch.codePointAt(0) || 0);

  const codepointHex = codepoint => `U+${codepoint.toString(16).toUpperCase().padStart(4, "0")}`;

  const isVariationSelectorCodepoint = codepoint =>
    inRange(codepoint, 0xfe00, 0xfe0f) || inRange(codepoint, 0xe0100, 0xe01ef);

  const isEmojiModifierCodepoint = codepoint => inRange(codepoint, 0x1f3fb, 0x1f3ff);

  const isRegionalIndicatorCodepoint = codepoint => inRange(codepoint, 0x1f1e6, 0x1f1ff);

  const isEmojiCodepoint = codepoint =>
    inRange(codepoint, 0x1f000, 0x1faff) ||
    inRange(codepoint, 0x2600, 0x27bf) ||
    codepoint === 0x00a9 ||
    codepoint === 0x00ae ||
    isEmojiModifierCodepoint(codepoint) ||
    isRegionalIndicatorCodepoint(codepoint);

  const isRtlCodepoint = codepoint =>
    inRange(codepoint, 0x0590, 0x08ff) ||
    inRange(codepoint, 0xfb1d, 0xfdff) ||
    inRange(codepoint, 0xfe70, 0xfeff);

  const clusterHasCodepoint = (cluster, predicate) =>
    codepointsFor(cluster).some(predicate);

  const isEmojiCluster = cluster =>
    cluster.includes("\u200d") ||
    clusterHasCodepoint(cluster, isEmojiCodepoint) ||
    clusterHasCodepoint(cluster, isVariationSelectorCodepoint);

  const isRtlCluster = cluster => clusterHasCodepoint(cluster, isRtlCodepoint);

  const segmentTextClusters = text => {
    const value = `${text ?? ""}`;
    if (value.length === 0) return [];
    try {
      if (typeof globalThis.Intl?.Segmenter === "function") {
        const segmenter = new globalThis.Intl.Segmenter(undefined, { granularity: "grapheme" });
        const segments = Array.from(segmenter.segment(value), item => item.segment);
        if (segments.length > 0) return segments;
      }
    } catch {
      // Fall through to the compact local segmenter.
    }
    const chars = Array.from(value);
    const out = [];
    let index = 0;
    while (index < chars.length) {
      const start = index;
      index += 1;
      let advanced = true;
      while (advanced && index < chars.length) {
        advanced = false;
        const codepoint = chars[index].codePointAt(0) || 0;
        if (
          isZeroWidthTextCodepoint(codepoint) ||
          isVariationSelectorCodepoint(codepoint) ||
          isEmojiModifierCodepoint(codepoint)
        ) {
          index += 1;
          advanced = true;
        } else if (chars[index] === "\u200d" && index + 1 < chars.length) {
          index += 2;
          advanced = true;
        } else if (
          index > start &&
          isRegionalIndicatorCodepoint(chars[index - 1].codePointAt(0) || 0) &&
          isRegionalIndicatorCodepoint(codepoint) &&
          index - start < 2
        ) {
          index += 1;
          advanced = true;
        }
      }
      out.push(chars.slice(start, index).join(""));
    }
    return out;
  };

  const visualTextClusters = clusters => {
    const visual = [];
    let index = 0;
    while (index < clusters.length) {
      const rtl = isRtlCluster(clusters[index]);
      const start = index;
      index += 1;
      while (index < clusters.length && isRtlCluster(clusters[index]) === rtl) {
        index += 1;
      }
      const run = clusters.slice(start, index);
      if (rtl) run.reverse();
      visual.push(...run);
    }
    return visual;
  };

  const cssColor = color => {
    const r = Math.round(Math.max(0, Math.min(1, Number(color.r) || 0)) * 255);
    const g = Math.round(Math.max(0, Math.min(1, Number(color.g) || 0)) * 255);
    const b = Math.round(Math.max(0, Math.min(1, Number(color.b) || 0)) * 255);
    const a = Math.max(0, Math.min(1, Number(color.a) || 0));
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  };

  const smokeRoleForText = text => {
    const value = `${text ?? ""}`;
    if (value.includes("👩‍💻")) return "emoji-zwj";
    if (value.includes("אבג")) return "bidi";
    if (value.startsWith("Smoke wrap line ")) return "paragraph-line";
    return "";
  };

  const textLayoutAdvance = (char, fontSize) => {
    const codepoint = char.codePointAt(0) || 0;
    if (isZeroWidthTextCodepoint(codepoint)) return 0;
    if (isFullwidthTextCodepoint(codepoint)) return fontSize;
    if (inRange(codepoint, 0x30, 0x39)) return fontSize * 0.58;
    if (codepoint === 0x20) return fontSize * 0.33;
    if (codepoint === 0x49) return fontSize * 0.34;
    if (codepoint === 0x4d || codepoint === 0x57) return fontSize * 0.9;
    if (inRange(codepoint, 0x41, 0x5a)) return fontSize * 0.67;
    if (codepoint === 0x69 || codepoint === 0x6a || codepoint === 0x6c) return fontSize * 0.3;
    if (codepoint === 0x66 || codepoint === 0x72 || codepoint === 0x74) return fontSize * 0.4;
    if (codepoint === 0x6d || codepoint === 0x77) return fontSize * 0.82;
    if (inRange(codepoint, 0x61, 0x7a)) return fontSize * 0.55;
    if (
      codepoint === 0x21 ||
      codepoint === 0x2c ||
      codepoint === 0x2e ||
      codepoint === 0x3a ||
      codepoint === 0x3b ||
      codepoint === 0x7c
    ) return fontSize * 0.3;
    if (
      inRange(codepoint, 0x21, 0x2f) ||
      inRange(codepoint, 0x3a, 0x40) ||
      inRange(codepoint, 0x5b, 0x60) ||
      inRange(codepoint, 0x7b, 0x7e)
    ) return fontSize * 0.4;
    return fontSize * 0.6;
  };

  const measureTextWidth = (text, family, style, size, weight) => {
    const font = {
      family: family || WEB_FONT_STACK,
      style: style || "normal",
      size: Math.max(1, Number(size) || 14),
      weight: Number(weight) || 400,
    };
    const value = `${text ?? ""}`;
    if (measureContext) {
      measureContext.font = `${font.style} ${font.weight} ${font.size}px ${font.family}`;
      const metrics = measureContext.measureText(value);
      if (metrics.width > 0 || value.length === 0) return metrics.width;
    }
    let width = 0;
    for (const char of value) width += textLayoutAdvance(char, font.size);
    return width;
  };

  const registerFontData = (family, base64Data) => {
    if (typeof FontFace !== "function" || !document.fonts) return invalidResource();
    const data = base64ToUint8Array(base64Data);
    if (!data || data.length === 0) return invalidResource();
    const cssFamily = `${family || ""}`.replace(/^"|"$/g, "");
    if (!cssFamily) return invalidResource();
    try {
      const blob = new Blob([data], { type: "font/ttf" });
      const url = URL.createObjectURL(blob);
      const face = new FontFace(cssFamily, `url(${url})`);
      document.fonts.add(face);
      face.load().catch(() => URL.revokeObjectURL(url));
      return ok();
    } catch {
      return invalidResource();
    }
  };

  const pushTextRun = (renderer, text, x, y, width, height, family, style, size, weight, color, align) => {
    const font = {
      family: family || WEB_FONT_STACK,
      style: style || "normal",
      size: Math.max(1, Number(size) || 14),
      weight: Number(weight) || 400,
    };
    const value = `${text ?? ""}`;
    const logicalClusters = segmentTextClusters(value);
    const visualClusters = visualTextClusters(logicalClusters);
    const smokeRole = smokeRoleForText(value);
    const glyphs = [];
    let total = 0;
    for (const cluster of visualClusters) {
      const glyph = ensureGlyph(renderer, cluster, font);
      if (!glyph) continue;
      glyphs.push({ cluster, glyph });
      total += glyph.advance;
    }
    const scope = rendererScope(renderer);
    const startIndex = scope.textVertices.length / TEXT_STRIDE_FLOATS;
    let cursor = Number(x) + textAlignExtra(align, width, total);
    const selectableSegments = buildSelectableTextSegments(glyphs, cursor);
    const baseline = Number(y) + Math.max(font.size, (Number(height) + font.size * 0.72) / 2);
    const state = rendererState(renderer);
    const drawColor = multiplyColorAlpha(color, state.opacity);
    recordSelectableTextRun(
      renderer,
      value,
      {
        x: Number(x),
        y: Number(y),
        width: Number(width),
        height: Number(height),
      },
      font,
      align,
      drawColor.a,
      selectableSegments,
    );
    for (const { glyph } of glyphs) {
      const glyphColor = glyph.colorGlyph
        ? { r: -1, g: 0, b: 0, a: drawColor.a }
        : drawColor;
      pushTextQuad(renderer, cursor + glyph.offsetX, baseline + glyph.offsetY, glyph, glyphColor);
      cursor += glyph.advance;
    }
    const count = scope.textVertices.length / TEXT_STRIDE_FLOATS - startIndex;
    if (count > 0) pushRendererItem(renderer, { type: "text", start: startIndex, count });
    if (smokeRole === "emoji-zwj") {
      recordRuntimeObservationEvent({
        kind: 95,
        name: "text_grapheme_layout",
        text: value,
        logicalClusters: logicalClusters.length,
        visualClusters: visualClusters.length,
        containsZwj: value.includes("\u200d"),
        singleGraphemeCluster: logicalClusters.length === 1,
        noInteriorCaret: logicalClusters.length === 1 && value.includes("\u200d"),
        codepoints: codepointsFor(value).map(codepointHex),
      });
    } else if (smokeRole === "bidi") {
      recordRuntimeObservationEvent({
        kind: 96,
        name: "text_bidi_layout",
        text: value,
        logicalClusters,
        visualClusters,
        visualOrderDiffers: logicalClusters.join("\u0000") !== visualClusters.join("\u0000"),
      });
    } else if (smokeRole === "paragraph-line") {
      const match = value.match(/^Smoke wrap line (\d+)/);
      recordRuntimeObservationEvent({
        kind: 97,
        name: "text_paragraph_line",
        text: value,
        lineIndex: match ? Number(match[1]) : 0,
        baseline,
        x: Number(x),
        y: Number(y),
        width: Number(width),
        height: Number(height),
      });
    }
  };

  const ensureImageResource = (renderer, source) => {
    const key = `${source ?? ""}`;
    if (!key) return undefined;
    let entry = renderer.images.get(key);
    if (!entry) {
      const image = new Image();
      if (!key.startsWith("data:") && !key.startsWith("blob:")) image.crossOrigin = "anonymous";
      entry = {
        source: key,
        image,
        uploadSource: undefined,
        decodeStarted: false,
        loaded: false,
        failed: false,
      };
      const reportReady = () => {
        entry.loaded = true;
        entry.failed = false;
        reportImageResourceChange({
          source: key,
          status: "ready",
          width: entry.width,
          height: entry.height,
        });
      };
      const reportFailure = diagnostic => {
        entry.loaded = false;
        entry.failed = true;
        recordRuntimeObservationEvent({
          kind: 91,
          name: "image_error",
          source: key,
          diagnostic,
        });
        reportImageResourceChange({
          source: key,
          status: "failed",
          diagnostic,
        });
      };
      const prepareImage = () => {
        if (entry.decodeStarted) return;
        entry.decodeStarted = true;
        entry.width = image.naturalWidth || image.width || 1;
        entry.height = image.naturalHeight || image.height || 1;
        recordRuntimeObservationEvent({
          kind: 90,
          name: "image_load",
          source: key,
          width: entry.width,
          height: entry.height,
        });
        try {
          const stagingCanvas = document.createElement("canvas");
          stagingCanvas.width = entry.width;
          stagingCanvas.height = entry.height;
          const stagingContext = stagingCanvas.getContext("2d");
          if (!stagingContext) {
            reportFailure("browser image staging canvas is unavailable");
            return;
          }
          stagingContext.drawImage(
            image,
            0,
            0,
            entry.width,
            entry.height,
          );
          entry.uploadSource = stagingCanvas;
          reportReady();
        } catch (error) {
          reportFailure(
            error instanceof Error ? error.message : `${error}`,
          );
        }
      };
      image.onload = prepareImage;
      image.onerror = () => {
        reportFailure("browser image load failed");
      };
      renderer.images.set(key, entry);
      image.src = key;
      if (image.complete && image.naturalWidth > 0 && image.naturalHeight > 0) {
        prepareImage();
      }
    }
    if (entry.loaded && !entry.texture && !entry.failed) {
      try {
        const width = Math.max(1, entry.width || entry.image.naturalWidth || entry.image.width || 1);
        const height = Math.max(1, entry.height || entry.image.naturalHeight || entry.image.height || 1);
        const texture = device.createTexture({
          size: [width, height],
          format: "rgba8unorm",
          usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
        });
        device.queue.copyExternalImageToTexture(
          { source: entry.uploadSource ?? entry.image },
          { texture },
          { width, height },
        );
        const sampler = device.createSampler({
          magFilter: "linear",
          minFilter: "linear",
          addressModeU: "clamp-to-edge",
          addressModeV: "clamp-to-edge",
        });
        const bindGroup = device.createBindGroup({
          layout: imagePipeline.getBindGroupLayout(0),
          entries: [
            { binding: 0, resource: sampler },
            { binding: 1, resource: texture.createView() },
          ],
        });
        entry.texture = texture;
        entry.sampler = sampler;
        entry.bindGroup = bindGroup;
        entry.width = width;
        entry.height = height;
      } catch (error) {
        entry.failed = true;
        recordRuntimeObservationEvent({
          kind: 91,
          name: "image_texture_error",
          source: key,
          diagnostic: error instanceof Error ? error.message : `${error}`,
        });
      }
    }
    return entry.texture && entry.bindGroup ? entry : undefined;
  };

  const imagePlacement = (rect, imageWidth, imageHeight, fit) => {
    if (Number(fit) === 2) {
      return { rect, u0: 0, v0: 0, u1: 1, v1: 1 };
    }
    const frameRatio = rect.width / Math.max(rect.height, 0.0001);
    const imageRatio = imageWidth / Math.max(imageHeight, 0.0001);
    const containPlacement = () => {
      if (imageRatio > frameRatio) {
        const height = rect.width / imageRatio;
        return {
          rect: { x: rect.x, y: rect.y + (rect.height - height) * 0.5, width: rect.width, height },
          u0: 0, v0: 0, u1: 1, v1: 1,
        };
      }
      const width = rect.height * imageRatio;
      return {
        rect: { x: rect.x + (rect.width - width) * 0.5, y: rect.y, width, height: rect.height },
        u0: 0, v0: 0, u1: 1, v1: 1,
      };
    };
    const fitWidthPlacement = () => {
      const height = rect.width / imageRatio;
      if (height <= rect.height) {
        return {
          rect: { x: rect.x, y: rect.y + (rect.height - height) * 0.5, width: rect.width, height },
          u0: 0, v0: 0, u1: 1, v1: 1,
        };
      }
      const visible = rect.height / height;
      const inset = (1 - visible) * 0.5;
      return { rect, u0: 0, v0: inset, u1: 1, v1: 1 - inset };
    };
    const fitHeightPlacement = () => {
      const width = rect.height * imageRatio;
      if (width <= rect.width) {
        return {
          rect: { x: rect.x + (rect.width - width) * 0.5, y: rect.y, width, height: rect.height },
          u0: 0, v0: 0, u1: 1, v1: 1,
        };
      }
      const visible = rect.width / width;
      const inset = (1 - visible) * 0.5;
      return { rect, u0: inset, v0: 0, u1: 1 - inset, v1: 1 };
    };
    if (Number(fit) === 3) {
      if (imageWidth <= rect.width && imageHeight <= rect.height) {
        return {
          rect: {
            x: rect.x + (rect.width - imageWidth) * 0.5,
            y: rect.y + (rect.height - imageHeight) * 0.5,
            width: imageWidth,
            height: imageHeight,
          },
          u0: 0, v0: 0, u1: 1, v1: 1,
        };
      }
      return containPlacement();
    }
    if (Number(fit) === 4) {
      return fitWidthPlacement();
    }
    if (Number(fit) === 5) {
      return fitHeightPlacement();
    }
    if (Number(fit) === 1) {
      if (imageRatio > frameRatio) {
        const visible = frameRatio / imageRatio;
        const inset = (1 - visible) * 0.5;
        return { rect, u0: inset, v0: 0, u1: 1 - inset, v1: 1 };
      }
      const visible = imageRatio / frameRatio;
      const inset = (1 - visible) * 0.5;
      return { rect, u0: 0, v0: inset, u1: 1, v1: 1 - inset };
    }
    return containPlacement();
  };

  const pushImageQuad = (renderer, rect, source, opacity, fit) => {
    if (rect.width <= 0 || rect.height <= 0) return false;
    const resource = ensureImageResource(renderer, source);
    if (!resource) return false;
    const placed = imagePlacement(rect, resource.width, resource.height, fit);
    const drawRect = placed.rect;
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    const state = rendererState(renderer);
    const alpha = clampOpacity(opacity) * state.opacity;
    const scope = rendererScope(renderer);
    const startIndex = scope.imageVertices.length / IMAGE_STRIDE_FLOATS;
    const push = (px, py, u, v) => {
      const transformed = transformPoint(state.transform, px, py);
      scope.imageVertices.push(
        transformed.x / w * 2 - 1,
        1 - transformed.y / h * 2,
        u, v,
        alpha, 0, 0, 0, 0,
      );
    };
    const x0 = drawRect.x;
    const y0 = drawRect.y;
    const x1 = drawRect.x + drawRect.width;
    const y1 = drawRect.y + drawRect.height;
    push(x0, y0, placed.u0, placed.v0);
    push(x0, y1, placed.u0, placed.v1);
    push(x1, y1, placed.u1, placed.v1);
    push(x0, y0, placed.u0, placed.v0);
    push(x1, y1, placed.u1, placed.v1);
    push(x1, y0, placed.u1, placed.v0);
    pushRendererItem(renderer, {
      type: "image",
      start: startIndex,
      count: 6,
      bindGroup: resource.bindGroup,
    });
    return true;
  };

  const createFrameTexture = renderer => {
    const dpr = Number(renderer.surface.scaleFactor) || 1;
    const width = Math.max(1, Math.round(renderer.width * dpr));
    const height = Math.max(1, Math.round(renderer.height * dpr));
    const texture = device.createTexture({
      size: [width, height],
      format,
      usage:
        GPUTextureUsage.RENDER_ATTACHMENT |
        GPUTextureUsage.TEXTURE_BINDING |
        GPUTextureUsage.COPY_SRC |
        GPUTextureUsage.COPY_DST,
    });
    const view = texture.createView();
    const sampler = device.createSampler({
      magFilter: "linear",
      minFilter: "linear",
      addressModeU: "clamp-to-edge",
      addressModeV: "clamp-to-edge",
    });
    renderer.frameResources.push(texture);
    return { texture, view, sampler, width, height };
  };

  const createBackdropTexture = renderer => {
    const dpr = Number(renderer.surface.scaleFactor) || 1;
    const width = Math.max(1, Math.round(renderer.width * dpr));
    const height = Math.max(1, Math.round(renderer.height * dpr));
    const texture = device.createTexture({
      size: [width, height],
      format: overlaySurfaceFormat,
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_SRC,
    });
    const sampler = device.createSampler({
      magFilter: "linear",
      minFilter: "linear",
      addressModeU: "clamp-to-edge",
      addressModeV: "clamp-to-edge",
    });
    renderer.frameResources.push(texture);
    return { texture, view: texture.createView(), sampler, width, height };
  };

  const copyTargetSnapshot = (renderer, targetTexture, _view, _clearValue, encoder) => {
    const backdrop = createFrameTexture(renderer);
    if (targetTexture) {
      encoder.copyTextureToTexture(
        { texture: targetTexture },
        { texture: backdrop.texture },
        [backdrop.width, backdrop.height, 1],
      );
    }
    return backdrop;
  };

  const renderTargetSnapshot = (renderer, _targetTexture, view, clearValue, encoder) => {
    const snapshot = createBackdropTexture(renderer);
    const pass = beginScopePass(snapshot.view, clearValue, "clear")(encoder);
    pass.setPipeline(textureCopyPipeline);
    pass.setBindGroup(0, createSamplerTextureBindGroup(textureCopyPipeline.getBindGroupLayout(0), surfaceSampler, view, snapshot.view));
    pass.draw(3, 1, 0, 0);
    pass.end();
    return snapshot;
  };

  const ensureWhiteTexture = renderer => {
    if (renderer.whiteTexture) return;
    const texture = device.createTexture({
      size: [1, 1],
      format: "rgba8unorm",
      usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
    });
    device.queue.writeTexture(
      { texture },
      new Uint8Array([255, 255, 255, 255]),
      { bytesPerRow: 4, rowsPerImage: 1 },
      { width: 1, height: 1 },
    );
    renderer.whiteTexture = texture;
    renderer.whiteView = texture.createView();
    renderer.whiteSampler = device.createSampler({
      magFilter: "nearest",
      minFilter: "nearest",
      addressModeU: "clamp-to-edge",
      addressModeV: "clamp-to-edge",
    });
  };

  const beginScopePass = (view, clearValue, loadOp) => encoder => encoder.beginRenderPass({
    colorAttachments: [{
      view,
      loadOp,
      clearValue: clearValue ?? { r: 0, g: 0, b: 0, a: 0 },
      storeOp: "store",
    }],
  });

  const renderScopeSpan = (renderer, scope, pass, buffers, startIndex, endIndex) => {
    for (let index = startIndex; index < endIndex; index += 1) {
      const item = scope.items[index];
      if (!setPassClip(pass, renderer, item.clip)) continue;
      if (item.type === "visual" && buffers.visual) {
        pass.setPipeline(visualPipeline);
        pass.setVertexBuffer(0, buffers.visual);
        pass.draw(item.count, 1, item.start, 0);
      } else if (item.type === "text" && buffers.text) {
        pass.setPipeline(textPipeline);
        pass.setBindGroup(0, renderer.atlasBindGroup);
        pass.setVertexBuffer(0, buffers.text);
        pass.draw(item.count, 1, item.start, 0);
      } else if (item.type === "image" && buffers.image && item.bindGroup) {
        pass.setPipeline(imagePipeline);
        pass.setBindGroup(0, item.bindGroup);
        pass.setVertexBuffer(0, buffers.image);
        pass.draw(item.count, 1, item.start, 0);
      } else if (item.type === "advanced" && buffers.advanced && item.bindGroup) {
        pass.setPipeline(advancedPipelineForBlend(item.blendMode));
        pass.setBindGroup(0, item.bindGroup);
        pass.setVertexBuffer(0, buffers.advanced);
        pass.draw(item.count, 1, item.start, 0);
      }
    }
  };

  const drawOverlayItemToView = (renderer, item, advancedBuffer, targetTexture, view, clearValue, encoder, clearPass, targetSnapshot) => {
    if (!advancedBuffer || !item.view || !item.sampler) return false;
    if (clearPass) {
      const clear = beginScopePass(view, clearValue, "clear")(encoder);
      clear.end();
    }
    const backdrop = targetSnapshot(renderer, targetTexture, view, clearValue, encoder);
    const bindGroup = createAdvancedBindGroup(item.blendMode, item.sampler, item.view, backdrop.view);
    const pass = beginScopePass(view, clearValue, "load")(encoder);
    if (setPassClip(pass, renderer, item.clip)) {
      pass.setPipeline(advancedOverlayPipeline);
      pass.setBindGroup(0, bindGroup);
      pass.setVertexBuffer(0, advancedBuffer);
      pass.draw(item.count, 1, item.start, 0);
    }
    pass.end();
    return true;
  };

  const renderScopeToView = (renderer, scope, targetTexture, view, clearValue, encoder, loadOp = "clear", targetSnapshot = copyTargetSnapshot) => {
    const buffers = {
      visual: uploadVertexBuffer(scope.visualVertices),
      text: uploadVertexBuffer(scope.textVertices),
      image: uploadVertexBuffer(scope.imageVertices),
      advanced: uploadVertexBuffer(scope.advancedVertices),
    };
    let clearPass = loadOp === "clear";
    let spanStart = 0;
    for (let index = 0; index < scope.items.length; index += 1) {
      const item = scope.items[index];
      if (item.type !== "advanced" || Number(item.blendMode) !== 3) continue;
      if (spanStart < index) {
        const pass = beginScopePass(view, clearValue, clearPass ? "clear" : "load")(encoder);
        renderScopeSpan(renderer, scope, pass, buffers, spanStart, index);
        pass.end();
        clearPass = false;
      }
      if (drawOverlayItemToView(renderer, item, buffers.advanced, targetTexture, view, clearValue, encoder, clearPass, targetSnapshot)) {
        clearPass = false;
      }
      spanStart = index + 1;
    }
    if (spanStart < scope.items.length) {
      const pass = beginScopePass(view, clearValue, clearPass ? "clear" : "load")(encoder);
      renderScopeSpan(renderer, scope, pass, buffers, spanStart, scope.items.length);
      pass.end();
      clearPass = false;
    }
    if (clearPass) {
      const pass = beginScopePass(view, clearValue, "clear")(encoder);
      pass.end();
    }
  };

  const compositeScope = (renderer, layer) => {
    const currentScope = renderer.scopeStack.pop();
    if (!currentScope || renderer.scopeStack.length === 0) return;
    const state = renderer.stateStack.pop() ?? { opacity: 1, transform: identityTransform(), clip: undefined };
    const target = createFrameTexture(renderer);
    const encoder = device.createCommandEncoder();
    renderScopeToView(
      renderer,
      currentScope,
      target.texture,
      target.view,
      { r: 0, g: 0, b: 0, a: 0 },
      encoder,
    );
    device.queue.submit([encoder.finish()]);
    const mask = maskRect(layer.mask, renderer);
    const rect = mask.width > 0 && mask.height > 0
      ? { x: mask.x, y: mask.y, width: mask.width, height: mask.height }
      : { x: 0, y: 0, width: renderer.width, height: renderer.height };
    const clip = intersectRects(layer.clip, maskClip(layer.mask));
    pushAdvancedQuad(
      renderer,
      rect,
      target.texture,
      target.view,
      target.sampler,
      layer.filter,
      clampOpacity(layer.opacity) * state.opacity,
      Number(layer.blendMode) || 0,
      0,
      0,
      { r: 1, g: 1, b: 1, a: 1 },
      { r: 1, g: 1, b: 1, a: 1 },
      clip,
      { uvRect: rect, mask },
    );
  };

  const pushScopedLayer = (renderer, layer) => {
    const current = rendererState(renderer);
    const next = cloneState(current);
    renderer.stateStack.push(next);
    renderer.scopeStack.push(newDrawScope());
    renderer.layerStack.push(layer);
  };

  const imports = {
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
    webgpu_available() {
      return true;
    },
    adapter_ready() {
      return true;
    },
    can_render() {
      return true;
    },
    three_d_available() {
      return true;
    },
    measure_text_width(text, family, style, size, weight) {
      return measureTextWidth(stringValue(text), stringValue(family), stringValue(style), size, weight);
    },
    register_font_data(family, base64Data) {
      return registerFontData(stringValue(family), stringValue(base64Data));
    },
    create_surface(canvasId, width, height, scaleFactor) {
      const canvas = getCanvas(stringValue(canvasId));
      if (!canvas) return 0;
      resizeCanvas(canvas, width, height, scaleFactor);
      const context = contextFor(canvas);
      if (!context) return 0;
      context.configure({
        device,
        format,
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
        alphaMode: "premultiplied",
      });
      const handle = nextSurfaceHandle++;
      surfaces.set(handle, { canvas, context, scaleFactor, width, height });
      return handle;
    },
    surface_is_valid(surfaceHandle) {
      return surfaces.has(surfaceHandle);
    },
    surface_resize(surfaceHandle, width, height, scaleFactor) {
      const surface = surfaces.get(surfaceHandle);
      if (!surface) return invalidResource();
      resizeCanvas(surface.canvas, width, height, scaleFactor);
      surface.context.configure({
        device,
        format,
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
        alphaMode: "premultiplied",
      });
      surface.width = width;
      surface.height = height;
      surface.scaleFactor = scaleFactor;
      return ok();
    },
    surface_dispose(surfaceHandle) {
      surfaces.delete(surfaceHandle);
    },
    create_renderer(surfaceHandle) {
      const surface = surfaces.get(surfaceHandle);
      if (!surface) return 0;
      const glyphCanvas = document.createElement("canvas");
      glyphCanvas.width = 256;
      glyphCanvas.height = 256;
      const glyphContext = glyphCanvas.getContext("2d", { willReadFrequently: true });
      if (!glyphContext) return 0;
      const atlasTexture = device.createTexture({
        size: [ATLAS_SIZE, ATLAS_SIZE],
        format: "rgba8unorm",
        usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
      });
      const atlasSampler = device.createSampler({
        magFilter: "linear",
        minFilter: "linear",
        addressModeU: "clamp-to-edge",
        addressModeV: "clamp-to-edge",
      });
      const atlasBindGroup = device.createBindGroup({
        layout: textPipeline.getBindGroupLayout(0),
        entries: [
          { binding: 0, resource: atlasSampler },
          { binding: 1, resource: atlasTexture.createView() },
        ],
      });
      const renderer = {
        surface,
        clearColor: { r: 1, g: 1, b: 1, a: 1 },
        glyphCanvas,
        glyphContext,
        glyphs: new Map(),
        images: new Map(),
        atlasTexture,
        atlasSampler,
        atlasBindGroup,
        atlasX: 0,
        atlasY: 0,
        atlasShelf: 0,
        scopeStack: [newDrawScope()],
        layerStack: [],
        frameResources: [],
        stateStack: [{ opacity: 1, transform: identityTransform(), clip: undefined }],
        presentCount: 0,
        textSelection: createTextSelectionLayer(surface.canvas),
      };
      const handle = nextRendererHandle++;
      renderers.set(handle, renderer);
      return handle;
    },
    // Independent 3D host port. It deliberately uses separate handles and
    // resources from the 2D DrawCommand renderer above.
    create_3d_surface(canvasId, width, height, scaleFactor) {
      try {
        const canvas = getCanvas(stringValue(canvasId));
        if (!canvas) return 0;
        resizeCanvas(canvas, width, height, scaleFactor);
        const context = contextFor(canvas);
        if (!context) return 0;
        context.configure({
          device,
          format,
          usage: GPUTextureUsage.RENDER_ATTACHMENT,
          alphaMode: "premultiplied",
        });
        const handle = nextThreeDSurfaceHandle++;
        threeDSurfaces.set(handle, { canvas, context, width, height, scaleFactor });
        return handle;
      } catch (error) {
        globalThis.console?.error?.("MoUI 3D WebGPU surface creation failed", error);
        return 0;
      }
    },
    create_3d_renderer(surfaceHandle) {
      const surface = threeDSurfaces.get(surfaceHandle);
      if (!surface) return 0;
      try {
        const shader = device.createShaderModule({ code: `
        struct Out { @builtin(position) position: vec4<f32>, @location(0) color: vec4<f32> };
        @vertex fn vs_main(@location(0) clipPosition: vec4<f32>, @location(1) normal: vec3<f32>, @location(2) color: vec4<f32>) -> Out {
          var out: Out; out.position = clipPosition; out.color = color; return out;
        }
        @fragment fn fs_main(in: Out) -> @location(0) vec4<f32> { return in.color; }
      ` });
        const pipeline = device.createRenderPipeline({
        layout: "auto",
        vertex: {
          module: shader,
          entryPoint: "vs_main",
          buffers: [{ arrayStride: 44, attributes: [
            { shaderLocation: 0, offset: 0, format: "float32x4" },
            { shaderLocation: 1, offset: 16, format: "float32x3" },
            { shaderLocation: 2, offset: 28, format: "float32x4" },
          ] }],
        },
        fragment: { module: shader, entryPoint: "fs_main", targets: [{ format }] },
        primitive: { topology: "triangle-list", cullMode: "back" },
        depthStencil: { format: "depth24plus", depthWriteEnabled: true, depthCompare: "less" },
      });
        const renderer = {
          surface,
          pipeline,
          depthTexture: undefined,
          depthWidth: 0,
          depthHeight: 0,
          vertexBuffer: undefined,
          vertexPayload: undefined,
          uploadCount: 0,
          frame: 0,
        };
        const handle = nextThreeDRendererHandle++;
        threeDRenderers.set(handle, renderer);
        return handle;
      } catch (error) {
        globalThis.console?.error?.("MoUI 3D WebGPU renderer creation failed", error);
        return 0;
      }
    },
    three_d_surface_resize(surfaceHandle, width, height, scaleFactor) {
      const surface = threeDSurfaces.get(surfaceHandle);
      if (!surface) return invalidResource();
      try {
        resizeCanvas(surface.canvas, width, height, scaleFactor);
        surface.context.configure({ device, format, usage: GPUTextureUsage.RENDER_ATTACHMENT, alphaMode: "premultiplied" });
        surface.width = width; surface.height = height; surface.scaleFactor = scaleFactor;
        return ok();
      } catch (error) {
        globalThis.console?.error?.("MoUI 3D WebGPU surface resize failed", error);
        return invalidResource();
      }
    },
        three_d_draw_mesh_binary(rendererHandle, payload) {
      const renderer = threeDRenderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      try {
        const encoded = String(stringValue(payload) ?? "");
        const decoded = atob(encoded);
        const bytes = new Uint8Array(decoded.length);
        for (let index = 0; index < decoded.length; index += 1) {
          bytes[index] = decoded.charCodeAt(index);
        }
        if (!bytes || bytes.byteLength % 44 !== 0) return invalidResource();
        const data = new Float32Array(bytes.buffer, bytes.byteOffset, bytes.byteLength / 4);
        const surface = renderer.surface;
        if (!renderer.depthTexture || renderer.depthWidth !== surface.canvas.width || renderer.depthHeight !== surface.canvas.height) {
          renderer.depthTexture?.destroy?.();
          renderer.depthTexture = device.createTexture({ size: [surface.canvas.width, surface.canvas.height], format: "depth24plus", usage: GPUTextureUsage.RENDER_ATTACHMENT });
          renderer.depthWidth = surface.canvas.width; renderer.depthHeight = surface.canvas.height;
        }
        let vertexBuffer = renderer.vertexBuffer;
        const samePayload = renderer.vertexPayload &&
          renderer.vertexPayload.byteLength === bytes.byteLength &&
          renderer.vertexPayload.every((value, index) => value === bytes[index]);
        if (!vertexBuffer || !samePayload) {
          renderer.vertexBuffer?.destroy?.();
          vertexBuffer = device.createBuffer({ size: Math.max(4, data.byteLength), usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST });
          device.queue.writeBuffer(vertexBuffer, 0, data);
          renderer.vertexBuffer = vertexBuffer;
          renderer.vertexPayload = bytes.slice();
          renderer.uploadCount += 1;
        }
        const texture = surface.context.getCurrentTexture();
        const encoder = device.createCommandEncoder();
        const pass = encoder.beginRenderPass({
          colorAttachments: [{ view: texture.createView(), clearValue: { r: 0.035, g: 0.045, b: 0.07, a: 1 }, loadOp: "clear", storeOp: "store" }],
          depthStencilAttachment: { view: renderer.depthTexture.createView(), depthClearValue: 1, depthLoadOp: "clear", depthStoreOp: "store" },
        });
        pass.setPipeline(renderer.pipeline); pass.setVertexBuffer(0, vertexBuffer); pass.draw(data.length / 11); pass.end();
        device.queue.submit([encoder.finish()]);
        renderer.frame += 1;
        return ok();
      } catch (error) {
        globalThis.console?.error?.("MoUI 3D binary WebGPU frame failed", error);
        return invalidResource();
      }
    },
    three_d_renderer_dispose(rendererHandle) {
      const renderer = threeDRenderers.get(rendererHandle);
      renderer?.depthTexture?.destroy?.();
      renderer?.vertexBuffer?.destroy?.();
      if (renderer) {
        renderer.vertexBuffer = undefined;
        renderer.vertexPayload = undefined;
      }
      threeDRenderers.delete(rendererHandle);
    },
    three_d_surface_dispose(surfaceHandle) {
      const surface = threeDSurfaces.get(surfaceHandle);
      surface?.context?.unconfigure?.();
      threeDSurfaces.delete(surfaceHandle);
    },
    renderer_is_valid(rendererHandle) {
      return renderers.has(rendererHandle);
    },
    renderer_resize(rendererHandle, width, height, scaleFactor) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      resizeCanvas(renderer.surface.canvas, width, height, scaleFactor);
      renderer.surface.context.configure({
        device,
        format,
        usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
        alphaMode: "premultiplied",
      });
      renderer.surface.width = width;
      renderer.surface.height = height;
      renderer.surface.scaleFactor = scaleFactor;
      syncTextSelectionLayerGeometry(renderer.textSelection);
      return ok();
    },
    begin_frame(rendererHandle, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      for (const texture of renderer.frameResources ?? []) {
        texture?.destroy?.();
      }
      renderer.frameResources = [];
      renderer.width = Number(width) || renderer.surface.width || 1;
      renderer.height = Number(height) || renderer.surface.height || 1;
      renderer.scopeStack = [newDrawScope()];
      renderer.layerStack = [];
      renderer.stateStack = [{ opacity: 1, transform: identityTransform(), clip: undefined }];
      if (renderer.textSelection) renderer.textSelection.runs = [];
      return ok();
    },
    clear(rendererHandle, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      renderer.clearColor = { r, g, b, a };
      return ok();
    },
    fill_rect(rendererHandle, x, y, width, height, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushSolidRounded(renderer, x, y, width, height, 0, { r, g, b, a });
      return ok();
    },
    stroke_rect(rendererHandle, x, y, width, height, r, g, b, a, strokeWidth) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushSolidRounded(renderer, x, y, width, height, 0, { r, g, b, a }, 1, strokeWidth);
      return ok();
    },
    fill_rounded_rect(rendererHandle, x, y, width, height, radius, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushSolidRounded(renderer, x, y, width, height, radius, { r, g, b, a });
      return ok();
    },
    stroke_rounded_rect(rendererHandle, x, y, width, height, radius, r, g, b, a, strokeWidth) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushSolidRounded(renderer, x, y, width, height, radius, { r, g, b, a }, 1, strokeWidth);
      return ok();
    },
    fill_rounded_rect_gradient(rendererHandle, x, y, width, height, radius, startX, startY, endX, endY, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushGradientRounded(renderer, x, y, width, height, radius, 0, { x: startX, y: startY }, { x: endX, y: endY }, { r: r0, g: g0, b: b0, a: a0 }, { r: r1, g: g1, b: b1, a: a1 }, 0);
      return ok();
    },
    stroke_rounded_rect_gradient(rendererHandle, x, y, width, height, radius, strokeWidth, startX, startY, endX, endY, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushGradientRounded(renderer, x, y, width, height, radius, strokeWidth, { x: startX, y: startY }, { x: endX, y: endY }, { r: r0, g: g0, b: b0, a: a0 }, { r: r1, g: g1, b: b1, a: a1 }, 1);
      return ok();
    },
    fill_rounded_rect_radial(rendererHandle, x, y, width, height, radius, centerX, centerY, gradientRadius, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushRadialRounded(renderer, x, y, width, height, radius, 0, { x: centerX, y: centerY }, gradientRadius, { r: r0, g: g0, b: b0, a: a0 }, { r: r1, g: g1, b: b1, a: a1 }, 0);
      return ok();
    },
    stroke_rounded_rect_radial(rendererHandle, x, y, width, height, radius, strokeWidth, centerX, centerY, gradientRadius, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushRadialRounded(renderer, x, y, width, height, radius, strokeWidth, { x: centerX, y: centerY }, gradientRadius, { r: r0, g: g0, b: b0, a: a0 }, { r: r1, g: g1, b: b1, a: a1 }, 1);
      return ok();
    },
    draw_shadow(rendererHandle, x, y, width, height, radius, offsetX, offsetY, blurRadius, spread, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const blur = Math.max(0, Number(blurRadius) || 0);
      const grow = blur * 2 + Math.max(0, Number(spread) || 0);
      const rect = {
        x: Number(x) + Number(offsetX) - grow,
        y: Number(y) + Number(offsetY) - grow,
        width: Number(width) + grow * 2,
        height: Number(height) + grow * 2,
      };
      pushVisualQuad(renderer, rect, Number(radius) + grow, 2, 0, blur, { x: rect.x, y: rect.y }, { x: rect.x + 1, y: rect.y }, { r, g, b, a }, { r, g, b, a });
      return ok();
    },
    draw_text(rendererHandle, text, x, y, width, height, family, style, size, weight, r, g, b, a, align) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushTextRun(renderer, stringValue(text), x, y, width, height, stringValue(family), stringValue(style), size, weight, { r, g, b, a }, align);
      return ok();
    },
    draw_image(rendererHandle, source, x, y, width, height, opacity, fit) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const imageSource = stringValue(source);
      const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
      if (pushImageQuad(renderer, rect, imageSource, opacity, fit)) {
        recordRuntimeObservationEvent({
          kind: 99,
          name: "image_ready_frame",
          source: imageSource,
          x: rect.x,
          y: rect.y,
          width: rect.width,
          height: rect.height,
        });
      } else {
        recordRuntimeObservationEvent({
          kind: 98,
          name: "image_placeholder_frame",
          source: imageSource,
          x: rect.x,
          y: rect.y,
          width: rect.width,
          height: rect.height,
        });
        const color = fallbackImageColor(imageSource);
        const alpha = clampOpacity(opacity);
        pushGradientRounded(
          renderer,
          rect.x,
          rect.y,
          rect.width,
          rect.height,
          0,
          0,
          { x: rect.x, y: rect.y },
          { x: rect.x + rect.width, y: rect.y + rect.height },
          { ...color, a: alpha },
          { r: color.r * 0.65, g: color.g * 0.65, b: color.b * 0.65, a: alpha },
          0,
        );
      }
      return ok();
    },
    draw_path_mesh(rendererHandle, meshPayload) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushPathMesh(renderer, stringValue(meshPayload));
      return ok();
    },
    image_resource_status(rendererHandle, source) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return 0;
      const entry = renderer.images.get(stringValue(source));
      if (!entry) return 0;
      if (entry.failed) return 3;
      if (entry.loaded && entry.texture && entry.bindGroup) return 2;
      return 1;
    },
    image_resource_width(rendererHandle, source) {
      const renderer = renderers.get(rendererHandle);
      const entry = renderer?.images?.get(stringValue(source));
      if (!entry) return 0;
      return Math.max(0, Math.round(entry.width || entry.image?.naturalWidth || entry.image?.width || 0));
    },
    image_resource_height(rendererHandle, source) {
      const renderer = renderers.get(rendererHandle);
      const entry = renderer?.images?.get(stringValue(source));
      if (!entry) return 0;
      return Math.max(0, Math.round(entry.height || entry.image?.naturalHeight || entry.image?.height || 0));
    },
    push_clip(rendererHandle, x, y, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const current = rendererState(renderer);
      const next = cloneState(current);
      const transformed = transformRect(current.transform, {
        x: Number(x),
        y: Number(y),
        width: Number(width),
        height: Number(height),
      });
      next.clip = intersectRects(current.clip, transformed);
      renderer.stateStack.push(next);
      return ok();
    },
    pop_clip(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      if (renderer.stateStack.length > 1) renderer.stateStack.pop();
      return ok();
    },
    push_transform(rendererHandle, a, b, c, d, tx, ty) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const current = rendererState(renderer);
      const next = cloneState(current);
      next.transform = multiplyTransform(current.transform, {
        a: Number(a),
        b: Number(b),
        c: Number(c),
        d: Number(d),
        tx: Number(tx),
        ty: Number(ty),
      });
      renderer.stateStack.push(next);
      return ok();
    },
    pop_transform(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      if (renderer.stateStack.length > 1) renderer.stateStack.pop();
      return ok();
    },
    push_opacity(rendererHandle, opacity) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const current = rendererState(renderer);
      const next = cloneState(current);
      next.opacity = current.opacity * clampOpacity(opacity);
      renderer.stateStack.push(next);
      return ok();
    },
    pop_opacity(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      if (renderer.stateStack.length > 1) renderer.stateStack.pop();
      return ok();
    },
    push_layer(rendererHandle, opacity, blendMode, maskKind, maskX, maskY, maskWidth, maskHeight, maskRadius, offscreen) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const layer = {
        opacity: clampOpacity(opacity),
        blendMode: Number(blendMode) || 0,
        mask: {
          kind: Number(maskKind) || 0,
          x: Number(maskX) || 0,
          y: Number(maskY) || 0,
          width: Number(maskWidth) || 0,
          height: Number(maskHeight) || 0,
          radius: Number(maskRadius) || 0,
        },
    three_d_update_resources(rendererHandle, payload) {
      const renderer = threeDRenderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      try {
        const encoded = `${stringValue(payload) ?? ""}`;
        const next = renderer.resourceResidency ?? new Map();
        if (encoded.length > 0) {
          for (const entry of encoded.split(";")) {
            const [operation, kind, value] = entry.split(":");
            if (!operation || !kind || value === undefined) return invalidResource();
            const key = `${kind}:${value}`;
            if (operation === "remove") next.delete(key);
            else if (operation === "create" || operation === "update") next.set(key, operation);
            else return invalidResource();
          }
        }
        renderer.resourceResidency = next;
        renderer.resourceRevision = (renderer.resourceRevision || 0) + 1;
        return ok();
      } catch (error) {
        globalThis.console?.error?.("MoUI 3D resource residency update failed", error);
        return invalidResource();
      }
    },
        clip: rendererState(renderer).clip ? { ...rendererState(renderer).clip } : undefined,
        filter: undefined,
        offscreen: !!offscreen,
      };
      pushScopedLayer(renderer, layer);
      return ok();
    },
    pop_layer(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const layer = renderer.layerStack.pop();
      if (!layer || renderer.scopeStack.length <= 1) return ok();
      compositeScope(renderer, layer);
      return ok();
    },
    push_filter(rendererHandle, filterKind, amount, matrixValues) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const layer = {
        opacity: 1,
        blendMode: 0,
        mask: { kind: 0, x: 0, y: 0, width: 0, height: 0, radius: 0 },
        clip: rendererState(renderer).clip ? { ...rendererState(renderer).clip } : undefined,
        filter: {
          kind: Number(filterKind) || 0,
          amount: Number(amount) || 0,
          matrixValues: stringValue(matrixValues),
        },
        offscreen: true,
      };
      pushScopedLayer(renderer, layer);
      return ok();
    },
    pop_filter(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const layer = renderer.layerStack.pop();
      if (!layer || renderer.scopeStack.length <= 1) return ok();
      compositeScope(renderer, layer);
      return ok();
    },
    draw_shader_effect(rendererHandle, name, x, y, width, height, uniforms, startX, startY, endX, endY, r0, g0, b0, a0, r1, g1, b1, a1) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      ensureWhiteTexture(renderer);
      const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
      const values = parseDoubleList(stringValue(uniforms));
      pushAdvancedQuad(
        renderer,
        rect,
        renderer.whiteTexture,
        renderer.whiteView,
        renderer.whiteSampler,
        undefined,
        rendererState(renderer).opacity,
        0,
        shaderKindForName(stringValue(name)),
        values[0] ?? 8,
        { r: Number(r0), g: Number(g0), b: Number(b0), a: Number(a0) },
        { r: Number(r1), g: Number(g1), b: Number(b1), a: Number(a1) },
        rendererState(renderer).clip ? { ...rendererState(renderer).clip } : undefined,
        { transform: { ...rendererState(renderer).transform } },
      );
      return ok();
    },
    present(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const encoder = device.createCommandEncoder();
      while (renderer.scopeStack.length > 1) {
        const layer = renderer.layerStack.pop() ?? {
          opacity: 1,
          blendMode: 0,
          mask: { kind: 0, x: 0, y: 0, width: 0, height: 0, radius: 0 },
          clip: undefined,
          filter: undefined,
          offscreen: true,
        };
        compositeScope(renderer, layer);
      }
      const surfaceTexture = renderer.surface.context.getCurrentTexture();
      const surfaceView = surfaceTexture.createView();
      renderScopeToView(
        renderer,
        renderer.scopeStack[0] ?? newDrawScope(),
        surfaceTexture,
        surfaceView,
        renderer.clearColor,
        encoder,
        "clear",
        renderTargetSnapshot,
      );
      device.queue.submit([encoder.finish()]);
      syncTextSelectionLayer(renderer);
      renderer.presentCount += 1;
      recordRuntimeObservationEvent({
        kind: 100,
        name: "present_frame",
        frame: renderer.presentCount,
      });
      return ok();
    },
    renderer_dispose(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      renderer?.atlasTexture?.destroy?.();
      renderer?.whiteTexture?.destroy?.();
      for (const texture of renderer?.frameResources ?? []) {
        texture?.destroy?.();
      }
      for (const image of renderer?.images?.values?.() ?? []) {
        image.texture?.destroy?.();
      }
      disposeTextSelectionLayer(renderer?.textSelection);
      renderers.delete(rendererHandle);
    },
    __moui_recovery_snapshot() {
      return {
        surfaces: [...surfaces.entries()].map(([handle, surface]) => ({
          handle,
          canvasId: surface.canvas?.id ?? "",
          width: surface.width,
          height: surface.height,
          scaleFactor: surface.scaleFactor,
        })),
        renderers: [...renderers.entries()].map(([handle, renderer]) => ({
          handle,
          surfaceHandle: [...surfaces.entries()].find(([, surface]) =>
            surface === renderer.surface)?.[0] ?? 0,
        })),
        threeDSurfaces: [...threeDSurfaces.entries()].map(([handle, surface]) => ({
          handle,
          canvasId: surface.canvas?.id ?? "",
          width: surface.width,
          height: surface.height,
          scaleFactor: surface.scaleFactor,
        })),
        threeDRenderers: [...threeDRenderers.entries()].map(([handle, renderer]) => ({
          handle,
          surfaceHandle: [...threeDSurfaces.entries()].find(([, surface]) =>
            surface === renderer.surface)?.[0] ?? 0,
        })),
      };
    },
    __moui_recovery_restore(snapshot = {}) {
      let restoredSurfaces = 0;
      let restoredRenderers = 0;
      for (const record of snapshot.surfaces ?? []) {
        const canvasId = createStringHandle(record.canvasId ?? "");
        const actual = imports.create_surface(
          canvasId,
          record.width,
          record.height,
          record.scaleFactor,
        );
        if (!actual) continue;
        if (actual !== record.handle) {
          surfaces.set(record.handle, surfaces.get(actual));
          surfaces.delete(actual);
        }
        nextSurfaceHandle = Math.max(nextSurfaceHandle, Number(record.handle) + 1);
        restoredSurfaces += 1;
      }
      for (const record of snapshot.renderers ?? []) {
        const actual = imports.create_renderer(record.surfaceHandle);
        if (!actual) continue;
        if (actual !== record.handle) {
          renderers.set(record.handle, renderers.get(actual));
          renderers.delete(actual);
        }
        nextRendererHandle = Math.max(nextRendererHandle, Number(record.handle) + 1);
        restoredRenderers += 1;
      }
      let restoredThreeDSurfaces = 0;
      let restoredThreeDRenderers = 0;
      for (const record of snapshot.threeDSurfaces ?? []) {
        const canvasId = createStringHandle(record.canvasId ?? "");
        const actual = imports.create_3d_surface(
          canvasId,
          record.width,
          record.height,
          record.scaleFactor,
        );
        if (!actual) continue;
        if (actual !== record.handle) {
          threeDSurfaces.set(record.handle, threeDSurfaces.get(actual));
          threeDSurfaces.delete(actual);
        }
        nextThreeDSurfaceHandle = Math.max(nextThreeDSurfaceHandle, Number(record.handle) + 1);
        restoredThreeDSurfaces += 1;
      }
      for (const record of snapshot.threeDRenderers ?? []) {
        const actual = imports.create_3d_renderer(record.surfaceHandle);
        if (!actual) continue;
        if (actual !== record.handle) {
          threeDRenderers.set(record.handle, threeDRenderers.get(actual));
          threeDRenderers.delete(actual);
        }
        nextThreeDRendererHandle = Math.max(nextThreeDRendererHandle, Number(record.handle) + 1);
        restoredThreeDRenderers += 1;
      }
      return {
        restoredSurfaces,
        restoredRenderers,
        restoredThreeDSurfaces,
        restoredThreeDRenderers,
      };
    },
  };

  return imports;

  function uploadVertexBuffer(vertices) {
    if (!vertices.length) return undefined;
    const data = new Float32Array(vertices);
    const buffer = device.createBuffer({
      size: Math.max(4, data.byteLength),
      usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(buffer, 0, data);
    return buffer;
  }
}

function alphaBlend() {
  return {
    color: {
      srcFactor: "src-alpha",
      dstFactor: "one-minus-src-alpha",
      operation: "add",
    },
    alpha: {
      srcFactor: "one",
      dstFactor: "one-minus-src-alpha",
      operation: "add",
    },
  };
}

export async function createWebGpuImportsAsync(options = {}) {
  const report = options.onStatus ?? (() => {});
  const fallbackToCanvas2d = async () => {
    report("WebGPU unavailable; switching to Canvas2D renderer.");
    const { createCanvas2dImports } = await import("./canvas2d_runtime.js");
    return createCanvas2dImports(options);
  };

  if (options.forceUnavailable === true || typeof navigator === "undefined" || !navigator.gpu) {
    return fallbackToCanvas2d();
  }
  const timeoutMs = options.timeoutMs ?? 8000;
  const withTimeout = (promise, label) =>
    Promise.race([
      promise,
      new Promise((_, reject) =>
        setTimeout(
          () => reject(new Error(`Timed out while ${label}.`)),
          timeoutMs,
        ),
      ),
    ]);
  const requestDevice = async () => {
    report("Requesting WebGPU adapter...");
    const adapter = await withTimeout(
      navigator.gpu.requestAdapter(),
      "requesting a WebGPU adapter",
    );
    if (!adapter) throw new Error("No WebGPU adapter available.");
    report("Requesting WebGPU device...");
    return withTimeout(
      adapter.requestDevice(),
      "requesting a WebGPU device",
    );
  };
  const restoreImports = (next, snapshot) => {
    if (!snapshot) return { restoredSurfaces: 0, restoredRenderers: 0 };
    if (typeof next.__moui_recovery_restore === "function") {
      return next.__moui_recovery_restore(snapshot);
    }
    const makeString = value => {
      const handle = next.begin_create_string();
      for (const char of `${value ?? ""}`) {
        next.string_append_char(handle, char.codePointAt(0));
      }
      return next.finish_create_string(handle);
    };
    let restoredSurfaces = 0;
    let restoredRenderers = 0;
    for (const record of snapshot.surfaces ?? []) {
      const handle = next.create_surface(
        makeString(record.canvasId),
        record.width,
        record.height,
        record.scaleFactor,
      );
      if (handle !== record.handle) {
        throw new Error(`renderer recovery surface handle mismatch: expected ${record.handle}, got ${handle}`);
      }
      restoredSurfaces += 1;
    }
    for (const record of snapshot.renderers ?? []) {
      const handle = next.create_renderer(record.surfaceHandle);
      if (handle !== record.handle) {
        throw new Error(`renderer recovery handle mismatch: expected ${record.handle}, got ${handle}`);
      }
      restoredRenderers += 1;
    }
    return { restoredSurfaces, restoredRenderers };
  };
  const createStableImports = initial => {
    let current = initial;
    const diagnostics = {
      state: "idle",
      generation: 1,
      recoveryCount: 0,
      recoveryFailures: 0,
      fallbackCount: 0,
      readbackCount: 0,
      lastLossReason: "",
    };
    const stable = {};
    for (const [name, value] of Object.entries(initial)) {
      if (name.startsWith("__moui_")) continue;
      stable[name] = typeof value === "function"
        ? (...args) => current[name](...args)
        : value;
    }
    Object.defineProperties(stable, {
      __moui_recovery_snapshot: {
        value: () => current.__moui_recovery_snapshot?.(),
      },
      __moui_recovery_diagnostics: {
        value: () => ({ ...diagnostics }),
      },
      __moui_replace_imports: {
        value: (next, state) => {
          current = next;
          Object.assign(diagnostics, state);
        },
      },
      __moui_update_diagnostics: {
        value: state => Object.assign(diagnostics, state),
      },
    });
    return stable;
  };
  const observeDeviceErrors = (device, stable, format) => {
    device.addEventListener?.("uncapturederror", event => {
      const message = event?.error?.message || event?.error || "unknown WebGPU error";
      globalThis.console?.error?.(`MoUI WebGPU uncaptured error: ${message}`);
      report(`WebGPU uncaptured error: ${message}`);
    });
    device.lost?.then(async info => {
      const reason = `${info?.reason || ""}`.toLowerCase();
      const message = info?.message || info?.reason || "unknown reason";
      if (reason === "destroyed" || `${message}`.toLowerCase().includes("destroyed")) {
        globalThis.console?.info?.(`MoUI WebGPU device destroyed during shutdown: ${message}`);
        return;
      }
      globalThis.console?.error?.(`MoUI WebGPU device lost: ${message}`);
      report(`WebGPU device lost: ${message}`);
      const snapshot = stable.__moui_recovery_snapshot?.();
      for (let attempt = 1; attempt <= 2; attempt += 1) {
        try {
          stable.__moui_update_diagnostics?.({
            state: "recovering",
            lastLossReason: `${message}`,
          });
          const recoveredDevice = await requestDevice();
          const recovered = createWebGpuImports({
            ...options,
            device: recoveredDevice,
            format,
          });
          const restored = restoreImports(recovered, snapshot);
          const previous = stable.__moui_recovery_diagnostics?.() ?? {};
          stable.__moui_replace_imports(recovered, {
            state: "recovered",
            generation: Number(previous.generation || 1) + 1,
            recoveryCount: Number(previous.recoveryCount || 0) + 1,
            recoveryFailures: 0,
            lastLossReason: `${message}`,
          });
          report(`WebGPU recovered generation=${Number(previous.generation || 1) + 1} surfaces=${restored.restoredSurfaces} renderers=${restored.restoredRenderers}.`);
          observeDeviceErrors(recoveredDevice, stable, format);
          return;
        } catch (error) {
          const previous = stable.__moui_recovery_diagnostics?.() ?? {};
          stable.__moui_update_diagnostics?.({
            state: "lost",
            recoveryFailures: Number(previous.recoveryFailures || 0) + 1,
            lastLossReason: `${message}`,
          });
          report(`WebGPU recovery attempt ${attempt} failed: ${error?.message || error}`);
        }
      }
      try {
        const { createCanvas2dImports } = await import("./canvas2d_runtime.js");
        const fallback = createCanvas2dImports(options);
        restoreImports(fallback, snapshot);
        const previous = stable.__moui_recovery_diagnostics?.() ?? {};
        stable.__moui_replace_imports(fallback, {
          state: "fallback-to-canvas2d",
          fallbackCount: Number(previous.fallbackCount || 0) + 1,
          lastLossReason: `${message}`,
        });
        report("WebGPU recovery failed twice; switched to Canvas2D renderer.");
      } catch (error) {
        report(`Canvas2D recovery fallback failed: ${error?.message || error}`);
      }
    });
  };
  let device;
  try {
    device = await requestDevice();
  } catch (error) {
    report("WebGPU initialization failed: " + error.message);
    return fallbackToCanvas2d();
  }
  const format = navigator.gpu.getPreferredCanvasFormat();
  const stable = createStableImports(
    createWebGpuImports({ ...options, device, format }),
  );
  observeDeviceErrors(device, stable, format);
  report("WebGPU ready.");
  return stable;
}

async function instantiateWasm(url, imports, report) {
  report("Loading wasm-gc module...");
  if (WebAssembly.instantiateStreaming) {
    try {
      return await WebAssembly.instantiateStreaming(fetch(url), imports);
    } catch (error) {
      report(`Streaming wasm load failed; retrying from ArrayBuffer. ${error}`);
    }
  }
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch wasm module: ${response.status} ${response.statusText}`);
  }
  const bytes = await response.arrayBuffer();
  return WebAssembly.instantiate(bytes, imports);
}

export async function bootMouiWasmGcApp(options = {}) {
  const report = options.onStatus ?? (() => {});
  if (!options.wasmUrl) {
    throw new Error("bootMouiWasmGcApp requires a wasmUrl option.");
  }
  const wasmUrl = options.wasmUrl;
  report("Preparing window/web host imports...");
  const windowWeb = createWindowWebImports({
    canvasHost: options.canvasHost ?? "#canvas-host",
    onEvent: options.onEvent,
    onRoute: options.onRoute,
  });
  const userWebGpuOptions = options.webgpu ?? {};
  const notifyImageResourceChanged = createImageResourceChangeNotifier(
    userWebGpuOptions.onImageResourceChange,
    () => windowWeb.schedule_animation_frame(),
  );
  const webgpu = await createWebGpuImportsAsync({
    ...userWebGpuOptions,
    onStatus: report,
    onImageResourceChange: notifyImageResourceChanged,
  });
  const imports = {
    ...(options.imports ?? {}),
    window_web: windowWeb,
    webgpu,
    spectest: {
      ...(options.imports?.spectest ?? {}),
      print_char(value) {
        const ch = String.fromCodePoint(Number(value));
        options.onPrint?.(ch);
      },
    },
  };
  const result = await instantiateWasm(wasmUrl, imports, report);
  report("Connecting wasm event bridge...");
  connectWindowWeb(result.instance, windowWeb);
  report("Starting MoonBit app...");
  result.instance.exports._start?.();
  windowWeb.history_dispatch_current?.(0);
  report("MoonBit app started.");
  return result.instance;
}
