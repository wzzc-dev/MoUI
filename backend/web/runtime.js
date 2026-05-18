import {
  connectWindowWeb,
  createWindowWebImports,
} from "./browser_runtime.js";

const VISUAL_STRIDE_FLOATS = 22;
const TEXT_STRIDE_FLOATS = 8;
const ATLAS_SIZE = 2048;

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

  const pushVisualVertex = (renderer, rect, px, py, radius, mode, strokeWidth, blurRadius, start, end, c0, c1) => {
    const w = Number(renderer.width || renderer.surface.width || 1);
    const h = Number(renderer.height || renderer.surface.height || 1);
    renderer.visualVertices.push(
      px / w * 2 - 1,
      1 - py / h * 2,
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
    const x0 = rect.x;
    const y0 = rect.y;
    const x1 = rect.x + rect.width;
    const y1 = rect.y + rect.height;
    pushVisualVertex(renderer, rect, x0, y0, radius, mode, strokeWidth, blurRadius, start, end, c0, c1);
    pushVisualVertex(renderer, rect, x0, y1, radius, mode, strokeWidth, blurRadius, start, end, c0, c1);
    pushVisualVertex(renderer, rect, x1, y1, radius, mode, strokeWidth, blurRadius, start, end, c0, c1);
    pushVisualVertex(renderer, rect, x0, y0, radius, mode, strokeWidth, blurRadius, start, end, c0, c1);
    pushVisualVertex(renderer, rect, x1, y1, radius, mode, strokeWidth, blurRadius, start, end, c0, c1);
    pushVisualVertex(renderer, rect, x1, y0, radius, mode, strokeWidth, blurRadius, start, end, c0, c1);
    renderer.items.push({ type: "visual", start: startIndex, count: 6 });
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
    const key = `${font.weight}|${font.size}|${font.family}|${char}`;
    const cached = renderer.glyphs.get(key);
    if (cached) return cached;
    const ctx = renderer.glyphContext;
    ctx.font = `${font.weight} ${font.size}px ${font.family}`;
    ctx.textAlign = "left";
    ctx.textBaseline = "alphabetic";
    const metrics = ctx.measureText(char);
    const left = Math.ceil(Math.max(1, -metrics.actualBoundingBoxLeft));
    const right = Math.ceil(Math.max(1, metrics.actualBoundingBoxRight));
    const ascent = Math.ceil(Math.max(font.size * 0.8, metrics.actualBoundingBoxAscent || font.size * 0.8));
    const descent = Math.ceil(Math.max(font.size * 0.25, metrics.actualBoundingBoxDescent || font.size * 0.25));
    const width = Math.max(1, left + right + 4);
    const height = Math.max(1, ascent + descent + 4);
    const placed = placeGlyph(renderer, width, height);
    if (!placed) return undefined;
    ctx.clearRect(0, 0, renderer.glyphCanvas.width, renderer.glyphCanvas.height);
    ctx.fillStyle = "white";
    ctx.font = `${font.weight} ${font.size}px ${font.family}`;
    ctx.fillText(char, left + 2, ascent + 2);
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
      width,
      height,
      offsetX: -(left + 2),
      offsetY: -(ascent + 2),
      advance: Math.max(metrics.width, width - 4),
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
    const u1 = (glyph.x + glyph.width) / ATLAS_SIZE;
    const v1 = (glyph.y + glyph.height) / ATLAS_SIZE;
    const push = (px, py, u, v) => renderer.textVertices.push(
      px / w * 2 - 1,
      1 - py / h * 2,
      u, v,
      color.r, color.g, color.b, color.a,
    );
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

  const pushTextRun = (renderer, text, x, y, width, height, family, size, weight, color, align) => {
    const font = {
      family: family || "Segoe UI, system-ui, sans-serif",
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
    for (const glyph of glyphs) {
      pushTextQuad(renderer, cursor + glyph.offsetX, baseline + glyph.offsetY, glyph, color);
      cursor += glyph.advance;
    }
    const count = renderer.textVertices.length / TEXT_STRIDE_FLOATS - startIndex;
    if (count > 0) renderer.items.push({ type: "text", start: startIndex, count });
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
        items: [],
        glyphCanvas,
        glyphContext,
        glyphs: new Map(),
        atlasTexture,
        atlasSampler,
        atlasBindGroup,
        atlasX: 0,
        atlasY: 0,
        atlasShelf: 0,
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
      return ok();
    },
    begin_frame(rendererHandle, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      renderer.visualVertices = [];
      renderer.textVertices = [];
      renderer.items = [];
      renderer.width = Number(width) || renderer.surface.width || 1;
      renderer.height = Number(height) || renderer.surface.height || 1;
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
    draw_image() {
      return ok();
    },
    push_clip() {
      return ok();
    },
    pop_clip() {
      return ok();
    },
    push_transform() {
      return ok();
    },
    pop_transform() {
      return ok();
    },
    push_opacity() {
      return ok();
    },
    pop_opacity() {
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
      for (const item of renderer.items) {
        if (item.type === "visual" && visualBuffer) {
          pass.setPipeline(visualPipeline);
          pass.setVertexBuffer(0, visualBuffer);
          pass.draw(item.count, 1, item.start, 0);
        } else if (item.type === "text" && textBuffer) {
          pass.setPipeline(textPipeline);
          pass.setBindGroup(0, renderer.atlasBindGroup);
          pass.setVertexBuffer(0, textBuffer);
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
