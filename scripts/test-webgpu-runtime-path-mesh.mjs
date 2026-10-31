#!/usr/bin/env node

// Contract tests for the retained path-mesh bridge.
//
// Two things are checked here:
//
// 1. Every `webgpu` import the MoonBit adapter declares exists in BOTH host
//    providers. The Canvas2D fallback is swapped into an already-instantiated
//    module through `__moui_replace_imports`, so a name that only the WebGPU
//    runtime implements breaks the page as soon as the fallback takes over.
// 2. The mesh handle lifecycle is identical in both providers: an uploaded mesh
//    stays drawable across frames, a released handle reports "invalid resource"
//    so the adapter re-uploads, and a payload that carries no whole triangle is
//    ignored without failing the draw.

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

globalThis.GPUBufferUsage = { VERTEX: 1, COPY_DST: 2 };
globalThis.GPUTextureUsage = {
  RENDER_ATTACHMENT: 1,
  TEXTURE_BINDING: 2,
  COPY_SRC: 4,
  COPY_DST: 8,
};

const assert = (condition, message) => {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
};

class FakeDomElement {
  constructor(tagName) {
    this.tagName = tagName.toUpperCase();
    this.className = "";
    this.style = {};
    this.dataset = {};
    this.children = [];
    this.parentElement = null;
  }

  appendChild(child) {
    this.children.push(child);
    child.parentElement = this;
    return child;
  }

  setAttribute() {}

  addEventListener() {}
}

class FakeCanvas {
  constructor() {
    this.id = "";
    this.width = 100;
    this.height = 60;
    this.style = {};
    this.parentElement = null;
    this.calls = [];
  }

  getBoundingClientRect() {
    return { width: this.width, height: this.height };
  }

  addEventListener() {}

  getContext(kind) {
    if (kind === "webgpu") {
      return {
        configure() {},
        getCurrentTexture() {
          return {
            createView: () => ({}),
            destroy() {},
          };
        },
      };
    }
    const context = {
      canvas: this,
      imageSmoothingEnabled: true,
      imageSmoothingQuality: "high",
      fillStyle: "",
      globalAlpha: 1,
      save: () => this.calls.push("save"),
      restore: () => this.calls.push("restore"),
      beginPath: () => this.calls.push("beginPath"),
      closePath: () => this.calls.push("closePath"),
      clip: () => this.calls.push("clip"),
      fill: () => this.calls.push("fill"),
      moveTo: () => this.calls.push("moveTo"),
      lineTo: () => this.calls.push("lineTo"),
      createLinearGradient: () => ({ addColorStop: () => {} }),
    };
    this.context2d = context;
    return context;
  }
}

const canvas = new FakeCanvas();
canvas.id = "path-mesh-canvas";
const host = new FakeDomElement("div");
host.appendChild(canvas);
globalThis.HTMLCanvasElement = FakeCanvas;
globalThis.document = {
  createElement: tag => (tag === "canvas" ? new FakeCanvas() : new FakeDomElement(tag)),
  getElementById: id => (id === "path-mesh-canvas" ? canvas : null),
  body: host,
};
globalThis.window = { devicePixelRatio: 1, innerWidth: 100, innerHeight: 60 };

const fakePass = {
  setScissorRect() {},
  setPipeline() {},
  setVertexBuffer() {},
  setBindGroup() {},
  draw() {},
  end() {},
};

const fakeDevice = {
  createShaderModule: () => ({}),
  createRenderPipeline: () => ({ getBindGroupLayout: () => ({}) }),
  createSampler: () => ({}),
  createTexture: () => ({
    createView: () => ({}),
    destroy() {},
  }),
  createBindGroup: () => ({}),
  createBuffer: () => ({}),
  createCommandEncoder: () => ({
    beginRenderPass: () => fakePass,
    copyTextureToTexture() {},
    finish: () => ({}),
  }),
  queue: {
    writeBuffer() {},
    writeTexture() {},
    copyExternalImageToTexture() {},
    submit() {},
  },
};

const { createWebGpuImports } = await import(
  "../moui_web_renderer/runtime.js"
);
const { createCanvas2dImports } = await import(
  "../moui_web_renderer/canvas2d_runtime.js"
);

const webgpuImports = createWebGpuImports({
  device: fakeDevice,
  format: "rgba8unorm",
});
const canvas2dImports = createCanvas2dImports({});

const adapterImports = readFileSync(
  resolve(
    dirname(fileURLToPath(import.meta.url)),
    "../moui_web_renderer/adapter_host_imports.mbt",
  ),
  "utf8",
);
const declared = [
  ...new Set(
    [...adapterImports.matchAll(/=\s*"webgpu"\s+"([a-z0-9_]+)"/g)].map(
      match => match[1],
    ),
  ),
];
assert(
  declared.includes("upload_path_mesh") &&
    declared.includes("draw_path_mesh_cached") &&
    declared.includes("release_path_mesh"),
  "expected the adapter to declare the retained path-mesh imports",
);
for (const name of declared) {
  assert(
    typeof webgpuImports[name] === "function",
    `WebGPU runtime is missing the declared webgpu import "${name}"`,
  );
  assert(
    typeof canvas2dImports[name] === "function",
    `Canvas2D fallback is missing the declared webgpu import "${name}"`,
  );
}

const trianglePayload = [
  10, 10, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
  42, 10, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
  10, 42, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
].join(",");

const stringHandle = imports => value => {
  const handle = imports.begin_create_string();
  for (const ch of value) imports.string_append_char(handle, ch.codePointAt(0));
  return imports.finish_create_string(handle);
};

const checkMeshLifecycle = (label, imports, renderer) => {
  const createString = stringHandle(imports);
  const mesh = imports.upload_path_mesh(renderer, createString(trianglePayload));
  assert(mesh > 0, `${label}: upload_path_mesh must return a mesh handle`);
  assert(
    imports.draw_path_mesh_cached(renderer, mesh) === 0,
    `${label}: drawing a retained mesh failed`,
  );
  assert(
    imports.draw_path_mesh_cached(renderer, mesh) === 0,
    `${label}: a retained mesh must stay drawable in later frames`,
  );
  assert(imports.release_path_mesh(mesh) === 0, `${label}: release_path_mesh failed`);
  assert(
    imports.draw_path_mesh_cached(renderer, mesh) === 6,
    `${label}: a released mesh must report invalid resource so the adapter re-uploads`,
  );
  assert(
    imports.upload_path_mesh(renderer + 1000, createString(trianglePayload)) === 0,
    `${label}: uploading for an unknown renderer must return no mesh`,
  );
  const partial = imports.upload_path_mesh(
    renderer,
    createString(`${trianglePayload},7`),
  );
  assert(
    partial > 0,
    `${label}: a payload without a whole extra triangle must still upload`,
  );
  assert(
    imports.draw_path_mesh_cached(renderer, partial) === 0,
    `${label}: an unusable payload must be ignored without failing the draw`,
  );
};

const webgpuSurface = webgpuImports.create_surface(
  stringHandle(webgpuImports)("path-mesh-canvas"),
  100,
  60,
  1,
);
assert(webgpuSurface > 0, "expected a fake WebGPU surface");
const webgpuRenderer = webgpuImports.create_renderer(webgpuSurface);
assert(webgpuRenderer > 0, "expected a fake WebGPU renderer");
checkMeshLifecycle("webgpu", webgpuImports, webgpuRenderer);

const canvas2dSurface = canvas2dImports.create_surface(
  stringHandle(canvas2dImports)("path-mesh-canvas"),
  100,
  60,
  1,
);
assert(canvas2dSurface > 0, "expected a fake Canvas2D surface");
const canvas2dRenderer = canvas2dImports.create_renderer(canvas2dSurface);
assert(canvas2dRenderer > 0, "expected a fake Canvas2D renderer");
canvas.calls.length = 0;
checkMeshLifecycle("canvas2d", canvas2dImports, canvas2dRenderer);
assert(
  canvas.calls.filter(call => call === "fill").length > 0,
  "canvas2d retained mesh must actually rasterise triangles",
);

console.log("Web runtime path-mesh bridge tests: ok");
