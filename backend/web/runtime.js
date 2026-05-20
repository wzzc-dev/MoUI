import {
  connectWindowWeb,
  createWindowWebImports,
} from "./browser_runtime.js";

const VISUAL_STRIDE_FLOATS = 22;
const TEXT_STRIDE_FLOATS = 8;
const IMAGE_STRIDE_FLOATS = 9;
const ATLAS_SIZE = 2048;
const WEB_FONT_STACK = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif';

export function createWebGpuImports(options = {}) {
  if (!options.device || !options.format) {
    throw new Error("createWebGpuImports requires a pre-initialized WebGPU device. Use createWebGpuImportsAsync().");
  }

  const device = options.device;
  const format = options.format;
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

  const stringValue = handle => strings.get(handle)?.value ?? "";
  const ok = () => 0;
  const invalidResource = () => 6;

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
    renderer.items.push({
      ...item,
      clip: state.clip ? { ...state.clip } : undefined,
    });
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

      fn gradient_color(local: vec2f, start: vec2f, end: vec2f, c0: vec4f, c1: vec4f) -> vec4f {
        let axis = end - start;
        let denom = max(dot(axis, axis), 0.0001);
        let t = clamp(dot(local - start, axis) / denom, 0.0, 1.0);
        return mix(c0, c1, t);
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
        let color = gradient_color(in.local, in.blurStart.zw, in.end, in.color0, in.color1);
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

  const pushVisualVertex = (renderer, rect, px, py, radius, mode, strokeWidth, blurRadius, start, end, c0, c1) => {
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    const transformed = transformPoint(rendererState(renderer).transform, px, py);
    renderer.visualVertices.push(
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
    const startIndex = renderer.visualVertices.length / VISUAL_STRIDE_FLOATS;
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

  const pushSolidRounded = (renderer, x, y, width, height, radius, color, mode = 0, strokeWidth = 0) => {
    const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
    pushVisualQuad(renderer, rect, Number(radius), mode, Number(strokeWidth), 0, { x: rect.x, y: rect.y }, { x: rect.x + 1, y: rect.y }, color, color);
  };

  const pushGradientRounded = (renderer, x, y, width, height, radius, strokeWidth, start, end, c0, c1, mode) => {
    const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
    pushVisualQuad(renderer, rect, Number(radius), mode, Number(strokeWidth), 0, start, end, c0, c1);
  };

  const ensureGlyph = (renderer, char, font) => {
    const dpr = Number(renderer.surface.scaleFactor) || 1;
    const key = `${dpr}|${font.weight}|${font.size}|${font.family}|${char}`;
    const cached = renderer.glyphs.get(key);
    if (cached) return cached;
    const ctx = renderer.glyphContext;
    const physicalSize = font.size * dpr;
    ctx.font = `${font.weight} ${physicalSize}px ${font.family}`;
    ctx.textAlign = "left";
    ctx.textBaseline = "alphabetic";
    const metrics = ctx.measureText(char);
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
    ctx.fillStyle = "white";
    ctx.font = `${font.weight} ${physicalSize}px ${font.family}`;
    ctx.fillText(char, left + padding, ascent + padding);
    const image = ctx.getImageData(0, 0, width, height);
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
      advance: metrics.width > 0 ? metrics.width / dpr : textLayoutAdvance(char, font.size),
    };
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
      renderer.textVertices.push(
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

  const pushTextRun = (renderer, text, x, y, width, height, family, size, weight, color, align) => {
    const font = {
      family: family || WEB_FONT_STACK,
      size: Math.max(1, Number(size) || 14),
      weight: Number(weight) || 400,
    };
    const value = `${text ?? ""}`;
    const glyphs = [];
    let total = 0;
    for (const char of value) {
      const glyph = ensureGlyph(renderer, char, font);
      if (!glyph) continue;
      glyphs.push(glyph);
      total += glyph.advance;
    }
    const startIndex = renderer.textVertices.length / TEXT_STRIDE_FLOATS;
    let cursor = Number(x) + textAlignExtra(align, width, total);
    const baseline = Number(y) + Math.max(font.size, (Number(height) + font.size * 0.72) / 2);
    const state = rendererState(renderer);
    const drawColor = multiplyColorAlpha(color, state.opacity);
    for (const glyph of glyphs) {
      pushTextQuad(renderer, cursor + glyph.offsetX, baseline + glyph.offsetY, glyph, drawColor);
      cursor += glyph.advance;
    }
    const count = renderer.textVertices.length / TEXT_STRIDE_FLOATS - startIndex;
    if (count > 0) pushRendererItem(renderer, { type: "text", start: startIndex, count });
  };

  const ensureImageResource = (renderer, source) => {
    const key = `${source ?? ""}`;
    if (!key) return undefined;
    let entry = renderer.images.get(key);
    if (!entry) {
      const image = new Image();
      if (!key.startsWith("data:") && !key.startsWith("blob:")) image.crossOrigin = "anonymous";
      entry = { source: key, image, loaded: false, failed: false };
      image.onload = () => {
        entry.loaded = true;
        entry.width = image.naturalWidth || image.width || 1;
        entry.height = image.naturalHeight || image.height || 1;
      };
      image.onerror = () => {
        entry.failed = true;
      };
      image.src = key;
      if (image.complete && image.naturalWidth > 0 && image.naturalHeight > 0) {
        entry.loaded = true;
        entry.width = image.naturalWidth;
        entry.height = image.naturalHeight;
      }
      renderer.images.set(key, entry);
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
          { source: entry.image },
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
      } catch {
        entry.failed = true;
      }
    }
    return entry.texture && entry.bindGroup ? entry : undefined;
  };

  const imagePlacement = (rect, imageWidth, imageHeight, fit) => {
    const frameRatio = rect.width / Math.max(rect.height, 0.0001);
    const imageRatio = imageWidth / Math.max(imageHeight, 0.0001);
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
    const startIndex = renderer.imageVertices.length / IMAGE_STRIDE_FLOATS;
    const push = (px, py, u, v) => {
      const transformed = transformPoint(state.transform, px, py);
      renderer.imageVertices.push(
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
    webgpu_available() {
      return true;
    },
    adapter_ready() {
      return true;
    },
    can_render() {
      return true;
    },
    create_surface(canvasId, width, height, scaleFactor) {
      const canvas = getCanvas(stringValue(canvasId));
      if (!canvas) return 0;
      resizeCanvas(canvas, width, height, scaleFactor);
      const context = contextFor(canvas);
      if (!context) return 0;
      context.configure({ device, format, alphaMode: "premultiplied" });
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
      surface.context.configure({ device, format, alphaMode: "premultiplied" });
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
        visualVertices: [],
        textVertices: [],
        imageVertices: [],
        items: [],
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
        stateStack: [{ opacity: 1, transform: identityTransform(), clip: undefined }],
      };
      const handle = nextRendererHandle++;
      renderers.set(handle, renderer);
      return handle;
    },
    renderer_is_valid(rendererHandle) {
      return renderers.has(rendererHandle);
    },
    renderer_resize(rendererHandle, width, height, scaleFactor) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      resizeCanvas(renderer.surface.canvas, width, height, scaleFactor);
      renderer.surface.context.configure({ device, format, alphaMode: "premultiplied" });
      renderer.surface.width = width;
      renderer.surface.height = height;
      renderer.surface.scaleFactor = scaleFactor;
      return ok();
    },
    begin_frame(rendererHandle, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      renderer.visualVertices = [];
      renderer.textVertices = [];
      renderer.imageVertices = [];
      renderer.items = [];
      renderer.width = Number(width) || renderer.surface.width || 1;
      renderer.height = Number(height) || renderer.surface.height || 1;
      renderer.stateStack = [{ opacity: 1, transform: identityTransform(), clip: undefined }];
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
    draw_text(rendererHandle, text, x, y, width, height, family, size, weight, r, g, b, a, align) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      pushTextRun(renderer, stringValue(text), x, y, width, height, stringValue(family), size, weight, { r, g, b, a }, align);
      return ok();
    },
    draw_image(rendererHandle, source, x, y, width, height, opacity, fit) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const rect = { x: Number(x), y: Number(y), width: Number(width), height: Number(height) };
      if (!pushImageQuad(renderer, rect, stringValue(source), opacity, fit)) {
        const color = fallbackImageColor(stringValue(source));
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
    present(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const encoder = device.createCommandEncoder();
      const pass = encoder.beginRenderPass({
        colorAttachments: [{
          view: renderer.surface.context.getCurrentTexture().createView(),
          loadOp: "clear",
          clearValue: renderer.clearColor,
          storeOp: "store",
        }],
      });
      const visualBuffer = uploadVertexBuffer(renderer.visualVertices);
      const textBuffer = uploadVertexBuffer(renderer.textVertices);
      const imageBuffer = uploadVertexBuffer(renderer.imageVertices);
      for (const item of renderer.items) {
        if (!setPassClip(pass, renderer, item.clip)) continue;
        if (item.type === "visual" && visualBuffer) {
          pass.setPipeline(visualPipeline);
          pass.setVertexBuffer(0, visualBuffer);
          pass.draw(item.count, 1, item.start, 0);
        } else if (item.type === "text" && textBuffer) {
          pass.setPipeline(textPipeline);
          pass.setBindGroup(0, renderer.atlasBindGroup);
          pass.setVertexBuffer(0, textBuffer);
          pass.draw(item.count, 1, item.start, 0);
        } else if (item.type === "image" && imageBuffer && item.bindGroup) {
          pass.setPipeline(imagePipeline);
          pass.setBindGroup(0, item.bindGroup);
          pass.setVertexBuffer(0, imageBuffer);
          pass.draw(item.count, 1, item.start, 0);
        }
      }
      pass.end();
      device.queue.submit([encoder.finish()]);
      return ok();
    },
    renderer_dispose(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      renderer?.atlasTexture?.destroy?.();
      for (const image of renderer?.images?.values?.() ?? []) {
        image.texture?.destroy?.();
      }
      renderers.delete(rendererHandle);
    },
  };

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
  if (options.forceUnavailable === true || typeof navigator === "undefined" || !navigator.gpu) {
    throw new Error("Browser WebGPU is required for the MoUI wasm-gc web backend.");
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
  report("Requesting WebGPU adapter...");
  const adapter = await withTimeout(
    navigator.gpu.requestAdapter(),
    "requesting a WebGPU adapter",
  );
  if (!adapter) {
    throw new Error("No WebGPU adapter is available.");
  }
  report("Requesting WebGPU device...");
  const device = await withTimeout(
    adapter.requestDevice(),
    "requesting a WebGPU device",
  );
  const format = navigator.gpu.getPreferredCanvasFormat();
  return createWebGpuImports({ ...options, device, format });
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
  });
  const webgpu = await createWebGpuImportsAsync({
    ...(options.webgpu ?? {}),
    onStatus: report,
  });
  const imports = {
    window_web: windowWeb,
    webgpu,
    spectest: {
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
  report("MoonBit app started.");
  return result.instance;
}
