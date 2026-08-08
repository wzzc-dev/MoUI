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
    if (Number(fit) === 2) {
      return { dx: rect.x, dy: rect.y, dw: rect.width, dh: rect.height };
    }
    const frameRatio = rect.width / Math.max(rect.height, 0.0001);
    const imgRatio = imageWidth / Math.max(imageHeight, 0.0001);
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
        ctx.fillStyle = cssColor({ r: r0, g: g0, b: b0, a: (a0 + a1 + a2) / 3 });
        ctx.beginPath();
        ctx.moveTo(x0, y0);
        ctx.lineTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.closePath();
        ctx.fill();
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
      return ok();
    },
    pop_clip(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.restore();
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
      return ok();
    },
    pop_transform(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const ctx = rendererCtx(renderer);
      ctx.restore();
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
          kind: Number(filterKind) || 0,
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
        mainCtx.filter = `grayscale(${Math.min(1, Math.max(0, amount))})`;
      } else if (kind === 3) {
        mainCtx.filter = `brightness(${Math.max(0, amount)})`;
      } else if (kind === 4) {
        mainCtx.filter = `contrast(${Math.max(0, amount)})`;
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
          ctx.fillStyle = c0;
          ctx.fillRect(rect.x, rect.y, rect.width, rect.height);
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
            const cx = rect.x + rect.width / 2;
            const cy = rect.y + rect.height / 2;
            const radius = Math.max(rect.width, rect.height) * 0.7;
            const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
            gradient.addColorStop(0, c0);
            gradient.addColorStop(1, c1);
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
      return ok();
    },

    renderer_dispose(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return;
      renderer.images.clear();
      renderer.loadedImages.clear();
      renderer.failedImages.clear();
      renderers.delete(rendererHandle);
    },
  };
}
