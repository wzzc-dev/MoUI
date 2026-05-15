import {
  connectWindowWeb,
  createWindowWebImports,
} from "../../backend/web/browser_runtime.js";

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
    strings.set(handle, { value: `${value ?? ""}`, offset: 0 });
    return handle;
  };

  const stringValue = handle => strings.get(handle)?.value ?? "";

  const status = code => code;
  const ok = () => status(0);
  const unavailable = () => status(1);
  const invalidResource = () => status(6);

  const getCanvas = id => {
    const canvas = document.getElementById(id);
    return canvas instanceof HTMLCanvasElement ? canvas : undefined;
  };

  const webgpuAvailable = () => true;

  const contextFor = canvas => {
    try {
      return canvas?.getContext?.("webgpu") ?? undefined;
    } catch {
      return undefined;
    }
  };

  const createPipeline = () => {
    const module = device.createShaderModule({
      code: `
        struct VertexOut {
          @builtin(position) position: vec4f,
          @location(0) color: vec4f,
        };

        @vertex
        fn vs_main(
          @location(0) position: vec2f,
          @location(1) color: vec4f,
        ) -> VertexOut {
          var out: VertexOut;
          out.position = vec4f(position, 0.0, 1.0);
          out.color = color;
          return out;
        }

        @fragment
        fn fs_main(in: VertexOut) -> @location(0) vec4f {
          return in.color;
        }
      `,
    });
    return device.createRenderPipeline({
      layout: "auto",
      vertex: {
        module,
        entryPoint: "vs_main",
        buffers: [
          {
            arrayStride: 24,
            attributes: [
              { shaderLocation: 0, offset: 0, format: "float32x2" },
              { shaderLocation: 1, offset: 8, format: "float32x4" },
            ],
          },
        ],
      },
      fragment: {
        module,
        entryPoint: "fs_main",
        targets: [{ format }],
      },
      primitive: { topology: "triangle-list" },
    });
  };

  const pipeline = createPipeline();

  const ensureOverlay = canvas => {
    let overlay = canvas.__mouiTextOverlay;
    if (!(overlay instanceof HTMLCanvasElement)) {
      overlay = document.createElement("canvas");
      overlay.style.position = "absolute";
      overlay.style.pointerEvents = "none";
      overlay.style.zIndex = "1";
      overlay.style.background = "transparent";
      overlay.style.boxShadow = "none";
      overlay.style.outline = "none";
      document.body.appendChild(overlay);
      canvas.__mouiTextOverlay = overlay;
    }
    const rect = canvas.getBoundingClientRect();
    overlay.width = canvas.width;
    overlay.height = canvas.height;
    overlay.style.left = `${rect.left + window.scrollX}px`;
    overlay.style.top = `${rect.top + window.scrollY}px`;
    overlay.style.width = `${rect.width}px`;
    overlay.style.height = `${rect.height}px`;
    return overlay;
  };

  const rendererScale = renderer => {
    const logicalWidth = Number(renderer.width || renderer.surface.width || 1);
    const physicalWidth = Number(renderer.surface.canvas.width || logicalWidth);
    if (logicalWidth <= 0 || physicalWidth <= 0) {
      return 1;
    }
    return physicalWidth / logicalWidth;
  };

  const resizeCanvas = (canvas, width, height, scaleFactor) => {
    const dpr = Number(scaleFactor) || window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.round(Number(width) * dpr));
    canvas.height = Math.max(1, Math.round(Number(height) * dpr));
    canvas.style.width = `${Math.max(1, Number(width))}px`;
    canvas.style.height = `${Math.max(1, Number(height))}px`;
    const overlay = canvas.__mouiTextOverlay;
    if (overlay instanceof HTMLCanvasElement) {
      ensureOverlay(canvas);
    }
  };

  const pushRectVertices = (renderer, x, y, width, height, r, g, b, a) => {
    const w = renderer.width || renderer.surface.width || 1;
    const h = renderer.height || renderer.surface.height || 1;
    const x0 = (x / w) * 2 - 1;
    const x1 = ((x + width) / w) * 2 - 1;
    const y0 = 1 - (y / h) * 2;
    const y1 = 1 - ((y + height) / h) * 2;
    renderer.vertices.push(
      x0, y0, r, g, b, a,
      x0, y1, r, g, b, a,
      x1, y1, r, g, b, a,
      x0, y0, r, g, b, a,
      x1, y1, r, g, b, a,
      x1, y0, r, g, b, a,
    );
  };

  const fillRect = (rendererHandle, x, y, width, height, r, g, b, a) => {
    const renderer = renderers.get(rendererHandle);
    if (!renderer) return invalidResource();
    pushRectVertices(renderer, x, y, width, height, r, g, b, a);
    return ok();
  };

  const strokeRect = (rendererHandle, x, y, width, height, r, g, b, a, strokeWidth) => {
    const renderer = renderers.get(rendererHandle);
    if (!renderer) return invalidResource();
    pushRectVertices(renderer, x, y, width, strokeWidth, r, g, b, a);
    pushRectVertices(renderer, x, y + height - strokeWidth, width, strokeWidth, r, g, b, a);
    pushRectVertices(renderer, x, y, strokeWidth, height, r, g, b, a);
    pushRectVertices(renderer, x + width - strokeWidth, y, strokeWidth, height, r, g, b, a);
    return ok();
  };

  return {
    begin_create_string() {
      return createStringHandle("");
    },
    string_append_char(handle, ch) {
      const entry = strings.get(handle);
      if (entry) {
        entry.value += String.fromCodePoint(Number(ch));
      }
    },
    finish_create_string(handle) {
      return handle;
    },
    webgpu_available: webgpuAvailable,
    adapter_ready() {
      return webgpuAvailable();
    },
    can_render() {
      return webgpuAvailable();
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
        alphaMode: "premultiplied",
      });
      const handle = nextSurfaceHandle++;
      surfaces.set(handle, {
        canvas,
        context,
        scaleFactor,
        width,
        height,
      });
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
      const renderer = {
        surface,
        clearColor: { r: 1, g: 1, b: 1, a: 1 },
        vertices: [],
        overlay: ensureOverlay(surface.canvas),
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
      renderer.overlay = ensureOverlay(renderer.surface.canvas);
      return ok();
    },
    begin_frame(rendererHandle, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      renderer.vertices = [];
      renderer.width = width;
      renderer.height = height;
      const overlay = ensureOverlay(renderer.surface.canvas);
      overlay.getContext("2d")?.clearRect(0, 0, overlay.width, overlay.height);
      return ok();
    },
    clear(rendererHandle, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      renderer.clearColor = { r, g, b, a };
      return ok();
    },
    fill_rect(rendererHandle, x, y, width, height, r, g, b, a) {
      return fillRect(rendererHandle, x, y, width, height, r, g, b, a);
    },
    stroke_rect(rendererHandle, x, y, width, height, r, g, b, a, strokeWidth) {
      return strokeRect(rendererHandle, x, y, width, height, r, g, b, a, strokeWidth);
    },
    fill_rounded_rect(rendererHandle, x, y, width, height, radius, r, g, b, a) {
      return fillRect(rendererHandle, x, y, width, height, r, g, b, a);
    },
    stroke_rounded_rect(rendererHandle, x, y, width, height, radius, r, g, b, a, strokeWidth) {
      return strokeRect(rendererHandle, x, y, width, height, r, g, b, a, strokeWidth);
    },
    draw_text(rendererHandle, text, x, y, width, height, family, size, weight, r, g, b, a) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      const ctx = renderer.overlay.getContext("2d");
      if (!ctx) return invalidResource();
      const scale = rendererScale(renderer);
      const logicalWidth = Number(width) || 0;
      const logicalHeight = Number(height) || Number(size) || 14;
      const textValue = stringValue(text);
      const familyValue = stringValue(family) || "Segoe UI, sans-serif";
      const fontSize = Number(size) || 14;
      const fontWeight = Number(weight) || 400;
      ctx.fillStyle = `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${a})`;
      ctx.font = `${fontWeight} ${fontSize * scale}px ${familyValue}`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(
        textValue,
        (Number(x) + logicalWidth / 2) * scale,
        (Number(y) + logicalHeight / 2) * scale,
        logicalWidth > 0 ? logicalWidth * scale : undefined,
      );
      return ok();
    },
    draw_image() {
      return ok();
    },
    push_clip(rendererHandle, x, y, width, height) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      const ctx = renderer.overlay.getContext("2d");
      if (!ctx) return invalidResource();
      ctx.save();
      ctx.beginPath();
      ctx.rect(x, y, width, height);
      ctx.clip();
      return ok();
    },
    pop_clip(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      renderer.overlay.getContext("2d")?.restore();
      return ok();
    },
    push_transform(rendererHandle, a, b, c, d, tx, ty) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      const ctx = renderer.overlay.getContext("2d");
      if (!ctx) return invalidResource();
      ctx.save();
      ctx.transform(a, b, c, d, tx, ty);
      return ok();
    },
    pop_transform(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      renderer.overlay.getContext("2d")?.restore();
      return ok();
    },
    push_opacity(rendererHandle, opacity) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      const ctx = renderer.overlay.getContext("2d");
      if (!ctx) return invalidResource();
      ctx.save();
      ctx.globalAlpha *= opacity;
      return ok();
    },
    pop_opacity(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer?.overlay) return invalidResource();
      renderer.overlay.getContext("2d")?.restore();
      return ok();
    },
    present(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (!renderer) return invalidResource();
      const encoder = device.createCommandEncoder();
      const pass = encoder.beginRenderPass({
        colorAttachments: [
          {
            view: renderer.surface.context.getCurrentTexture().createView(),
            loadOp: "clear",
            clearValue: renderer.clearColor,
            storeOp: "store",
          },
        ],
      });
      if (renderer.vertices.length > 0) {
        const data = new Float32Array(renderer.vertices);
        const buffer = device.createBuffer({
          size: data.byteLength,
          usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
        });
        device.queue.writeBuffer(buffer, 0, data);
        pass.setPipeline(pipeline);
        pass.setVertexBuffer(0, buffer);
        pass.draw(data.length / 6);
      }
      pass.end();
      device.queue.submit([encoder.finish()]);
      return ok();
    },
    renderer_dispose(rendererHandle) {
      const renderer = renderers.get(rendererHandle);
      if (renderer?.overlay instanceof HTMLCanvasElement) {
        renderer.overlay.remove();
      }
      renderers.delete(rendererHandle);
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

export async function bootCounterWasm(options = {}) {
  const report = options.onStatus ?? (() => {});
  const wasmUrl =
    options.wasmUrl ??
    new URL(
      "../../_build/wasm-gc/debug/build/examples/counter_web_wasm/counter_web_wasm.wasm",
      import.meta.url,
    );
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
