const canvas = document.querySelector("#moui-canvas");
const status = document.querySelector("#status");

const rectShader = `
struct VertexOut {
  @builtin(position) position: vec4f,
  @location(0) color: vec4f,
};

@vertex
fn vs_main(@location(0) position: vec2f, @location(1) color: vec4f) -> VertexOut {
  var out: VertexOut;
  out.position = vec4f(position, 0.0, 1.0);
  out.color = color;
  return out;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
  return in.color;
}
`;

const textShader = `
struct VertexOut {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
  @location(1) color: vec4f,
};

@group(0) @binding(0) var glyphSampler: sampler;
@group(0) @binding(1) var glyphAtlas: texture_2d<f32>;

@vertex
fn vs_main(
  @location(0) position: vec2f,
  @location(1) uv: vec2f,
  @location(2) color: vec4f,
) -> VertexOut {
  var out: VertexOut;
  out.position = vec4f(position, 0.0, 1.0);
  out.uv = uv;
  out.color = color;
  return out;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
  let sample = textureSample(glyphAtlas, glyphSampler, in.uv);
  return vec4f(in.color.rgb, in.color.a * sample.a);
}
`;

class GlyphAtlas {
  constructor(device, queue) {
    this.device = device;
    this.queue = queue;
    this.size = 1024;
    this.padding = 2;
    this.x = this.padding;
    this.y = this.padding;
    this.rowHeight = 0;
    this.entries = new Map();
    this.canvas = document.createElement("canvas");
    this.canvas.width = this.size;
    this.canvas.height = this.size;
    this.ctx = this.canvas.getContext("2d", { willReadFrequently: true });
    this.ctx.clearRect(0, 0, this.size, this.size);
    this.texture = device.createTexture({
      size: [this.size, this.size],
      format: "rgba8unorm",
      usage:
        GPUTextureUsage.TEXTURE_BINDING |
        GPUTextureUsage.COPY_DST |
        GPUTextureUsage.RENDER_ATTACHMENT,
    });
    this.sampler = device.createSampler({
      magFilter: "linear",
      minFilter: "linear",
    });
  }

  getGlyph(character, font) {
    const key = `${font.weight}:${font.size}:${font.family}:${character}`;
    const cached = this.entries.get(key);
    if (cached) return cached;

    const size = Math.max(1, font.size);
    const cssFont = `${font.weight} ${size}px ${font.family}`;
    this.ctx.font = cssFont;
    this.ctx.textBaseline = "alphabetic";
    const metrics = this.ctx.measureText(character);
    const left = Math.ceil(Math.max(0, -metrics.actualBoundingBoxLeft));
    const width = Math.max(1, Math.ceil(metrics.width + left + 4));
    const ascent = Math.ceil(metrics.actualBoundingBoxAscent || size * 0.8);
    const descent = Math.ceil(metrics.actualBoundingBoxDescent || size * 0.25);
    const height = Math.max(1, ascent + descent + 4);

    if (this.x + width + this.padding > this.size) {
      this.x = this.padding;
      this.y += this.rowHeight + this.padding;
      this.rowHeight = 0;
    }
    if (this.y + height + this.padding > this.size) {
      this.clear();
    }

    const x = this.x;
    const y = this.y;
    this.x += width + this.padding;
    this.rowHeight = Math.max(this.rowHeight, height);

    this.ctx.clearRect(x, y, width, height);
    this.ctx.font = cssFont;
    this.ctx.fillStyle = "white";
    this.ctx.textBaseline = "alphabetic";
    this.ctx.fillText(character, x + left + 2, y + 2 + ascent);

    const pixels = this.ctx.getImageData(x, y, width, height);
    this.queue.writeTexture(
      { texture: this.texture, origin: [x, y, 0] },
      pixels.data,
      { bytesPerRow: width * 4, rowsPerImage: height },
      [width, height, 1],
    );

    const glyph = {
      u0: x / this.size,
      v0: y / this.size,
      u1: (x + width) / this.size,
      v1: (y + height) / this.size,
      width,
      height,
      advance: metrics.width,
      bearingX: -left - 2,
      bearingY: ascent + 2,
    };
    this.entries.set(key, glyph);
    return glyph;
  }

  clear() {
    this.x = this.padding;
    this.y = this.padding;
    this.rowHeight = 0;
    this.entries.clear();
    this.ctx.clearRect(0, 0, this.size, this.size);
  }
}

class MoUIWebGpuRenderer {
  constructor({ device, context, format, canvas }) {
    this.device = device;
    this.queue = device.queue;
    this.context = context;
    this.format = format;
    this.canvas = canvas;
    this.cssWidth = 1;
    this.cssHeight = 1;
    this.clearColor = [1, 1, 1, 1];
    this.rectVertices = [];
    this.textVertices = [];
    this.clipStack = [];
    this.activeClip = null;

    this.rectPipeline = device.createRenderPipeline({
      layout: "auto",
      vertex: {
        module: device.createShaderModule({ code: rectShader }),
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
        module: device.createShaderModule({ code: rectShader }),
        entryPoint: "fs_main",
        targets: [{ format }],
      },
      primitive: { topology: "triangle-list" },
    });

    this.textPipeline = device.createRenderPipeline({
      layout: "auto",
      vertex: {
        module: device.createShaderModule({ code: textShader }),
        entryPoint: "vs_main",
        buffers: [
          {
            arrayStride: 32,
            attributes: [
              { shaderLocation: 0, offset: 0, format: "float32x2" },
              { shaderLocation: 1, offset: 8, format: "float32x2" },
              { shaderLocation: 2, offset: 16, format: "float32x4" },
            ],
          },
        ],
      },
      fragment: {
        module: device.createShaderModule({ code: textShader }),
        entryPoint: "fs_main",
        targets: [
          {
            format,
            blend: {
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
            },
          },
        ],
      },
      primitive: { topology: "triangle-list" },
    });

    this.rectBuffer = device.createBuffer({
      size: 4,
      usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
    });
    this.textBuffer = device.createBuffer({
      size: 4,
      usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
    });
    this.rectBufferCapacity = 4;
    this.textBufferCapacity = 4;
    this.glyphAtlas = new GlyphAtlas(device, this.queue);
    this.textBindGroup = device.createBindGroup({
      layout: this.textPipeline.getBindGroupLayout(0),
      entries: [
        { binding: 0, resource: this.glyphAtlas.sampler },
        { binding: 1, resource: this.glyphAtlas.texture.createView() },
      ],
    });
  }

  resize(width, height) {
    this.cssWidth = Math.max(1, width);
    this.cssHeight = Math.max(1, height);
    const ratio = globalThis.devicePixelRatio || 1;
    const pixelWidth = Math.max(1, Math.round(this.cssWidth * ratio));
    const pixelHeight = Math.max(1, Math.round(this.cssHeight * ratio));
    if (this.canvas.width !== pixelWidth) this.canvas.width = pixelWidth;
    if (this.canvas.height !== pixelHeight) this.canvas.height = pixelHeight;
  }

  begin(width, height) {
    this.resize(width, height);
    this.clearColor = [1, 1, 1, 1];
    this.rectVertices = [];
    this.textVertices = [];
    this.clipStack = [];
    this.activeClip = null;
  }

  clear(r, g, b, a) {
    this.clearColor = [r, g, b, a];
  }

  fillRect(x, y, width, height, r, g, b, a) {
    this.appendRect(this.rectVertices, x, y, width, height, [r, g, b, a]);
  }

  drawText(text, x, y, width, height, family, size, weight, r, g, b, a) {
    const font = { family, size, weight };
    const glyphs = [...text].map((ch) => this.glyphAtlas.getGlyph(ch, font));
    const totalWidth = glyphs.reduce((sum, glyph) => sum + glyph.advance, 0);
    const centerAscent = size * 0.72;
    let cursor = x + Math.max(0, (width - totalWidth) / 2);
    const baseline = y + Math.max(size, (height + centerAscent) / 2);
    for (const glyph of glyphs) {
      const gx = cursor + glyph.bearingX;
      const gy = baseline - glyph.bearingY;
      this.appendTextRect(
        gx,
        gy,
        glyph.width,
        glyph.height,
        glyph.u0,
        glyph.v0,
        glyph.u1,
        glyph.v1,
        [r, g, b, a],
      );
      cursor += glyph.advance;
    }
  }

  pushClip(x, y, width, height) {
    const clip = { x, y, width, height };
    this.clipStack.push(clip);
    this.activeClip = clip;
  }

  popClip() {
    this.clipStack.pop();
    this.activeClip = this.clipStack[this.clipStack.length - 1] ?? null;
  }

  present() {
    const encoder = this.device.createCommandEncoder();
    const view = this.context.getCurrentTexture().createView();
    const pass = encoder.beginRenderPass({
      colorAttachments: [
        {
          view,
          clearValue: {
            r: this.clearColor[0],
            g: this.clearColor[1],
            b: this.clearColor[2],
            a: this.clearColor[3],
          },
          loadOp: "clear",
          storeOp: "store",
        },
      ],
    });

    if (this.activeClip) {
      const ratio = globalThis.devicePixelRatio || 1;
      pass.setScissorRect(
        Math.max(0, Math.floor(this.activeClip.x * ratio)),
        Math.max(0, Math.floor(this.activeClip.y * ratio)),
        Math.max(1, Math.floor(this.activeClip.width * ratio)),
        Math.max(1, Math.floor(this.activeClip.height * ratio)),
      );
    }

    this.drawVertexList(pass, this.rectVertices, this.rectPipeline, 6);
    if (this.textVertices.length > 0) {
      pass.setBindGroup(0, this.textBindGroup);
      this.drawVertexList(pass, this.textVertices, this.textPipeline, 8);
    }
    pass.end();
    this.queue.submit([encoder.finish()]);
  }

  dispose() {
    this.rectBuffer.destroy();
    this.textBuffer.destroy();
    this.glyphAtlas.texture.destroy();
  }

  drawVertexList(pass, vertices, pipeline, floatsPerVertex) {
    if (vertices.length === 0) return;
    const data = new Float32Array(vertices);
    const required = data.byteLength;
    const buffer = this.ensureBuffer(
      floatsPerVertex === 6 ? "rect" : "text",
      required,
    );
    this.queue.writeBuffer(buffer, 0, data);
    pass.setPipeline(pipeline);
    pass.setVertexBuffer(0, buffer);
    pass.draw(data.length / floatsPerVertex);
  }

  ensureBuffer(kind, required) {
    if (kind === "rect") {
      if (this.rectBufferCapacity < required) {
        this.rectBuffer.destroy();
        this.rectBufferCapacity = growCapacity(required);
        this.rectBuffer = this.device.createBuffer({
          size: this.rectBufferCapacity,
          usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
        });
      }
      return this.rectBuffer;
    }
    if (this.textBufferCapacity < required) {
      this.textBuffer.destroy();
      this.textBufferCapacity = growCapacity(required);
      this.textBuffer = this.device.createBuffer({
        size: this.textBufferCapacity,
        usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
      });
    }
    return this.textBuffer;
  }

  appendRect(out, x, y, width, height, color) {
    const x0 = toNdcX(x, this.cssWidth);
    const x1 = toNdcX(x + width, this.cssWidth);
    const y0 = toNdcY(y, this.cssHeight);
    const y1 = toNdcY(y + height, this.cssHeight);
    const [r, g, b, a] = color;
    out.push(
      x0,
      y0,
      r,
      g,
      b,
      a,
      x0,
      y1,
      r,
      g,
      b,
      a,
      x1,
      y1,
      r,
      g,
      b,
      a,
      x0,
      y0,
      r,
      g,
      b,
      a,
      x1,
      y1,
      r,
      g,
      b,
      a,
      x1,
      y0,
      r,
      g,
      b,
      a,
    );
  }

  appendTextRect(x, y, width, height, u0, v0, u1, v1, color) {
    const x0 = toNdcX(x, this.cssWidth);
    const x1 = toNdcX(x + width, this.cssWidth);
    const y0 = toNdcY(y, this.cssHeight);
    const y1 = toNdcY(y + height, this.cssHeight);
    const [r, g, b, a] = color;
    this.textVertices.push(
      x0,
      y0,
      u0,
      v0,
      r,
      g,
      b,
      a,
      x0,
      y1,
      u0,
      v1,
      r,
      g,
      b,
      a,
      x1,
      y1,
      u1,
      v1,
      r,
      g,
      b,
      a,
      x0,
      y0,
      u0,
      v0,
      r,
      g,
      b,
      a,
      x1,
      y1,
      u1,
      v1,
      r,
      g,
      b,
      a,
      x1,
      y0,
      u1,
      v0,
      r,
      g,
      b,
      a,
    );
  }
}

function growCapacity(required) {
  let capacity = 256;
  while (capacity < required) capacity *= 2;
  return capacity;
}

function toNdcX(x, width) {
  return (x / width) * 2 - 1;
}

function toNdcY(y, height) {
  return 1 - (y / height) * 2;
}

function showUnsupported(message) {
  canvas.style.display = "none";
  status.textContent = message;
  status.classList.add("visible");
}

async function main() {
  try {
    if (!navigator.gpu) {
      showUnsupported("WebGPU is not available in this browser.");
      return;
    }
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) {
      showUnsupported("No WebGPU adapter is available.");
      return;
    }
    const device = await adapter.requestDevice();
    const context = canvas.getContext("webgpu");
    const format = navigator.gpu.getPreferredCanvasFormat();
    context.configure({
      device,
      format,
      alphaMode: "opaque",
    });
    const renderer = new MoUIWebGpuRenderer({
      device,
      context,
      format,
      canvas,
    });
    const bootContext = {
      canvas,
      renderer,
      width: () => canvas.clientWidth,
      height: () => canvas.clientHeight,
    };
    globalThis.__mouiBootContext = bootContext;
    const appName = new URLSearchParams(globalThis.location?.search ?? "").get(
      "app",
    );
    const start =
      appName === "todo"
        ? globalThis.start_todo_web
        : globalThis.start_counter_web;
    if (typeof start === "function") {
      globalThis.__mouiStarted = true;
      globalThis.__mouiApp = start(bootContext);
    } else {
      throw new Error("MoonBit web entrypoint was not exported.");
    }
  } catch (error) {
    console.error(error);
    showUnsupported("WebGPU initialization failed.");
  }
}

main();
