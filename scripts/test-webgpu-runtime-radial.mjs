#!/usr/bin/env node

import { createWebGpuImports } from "../moui/backend/web/runtime.js";

globalThis.GPUBufferUsage = { VERTEX: 1, COPY_DST: 2 };
globalThis.GPUTextureUsage = {
  RENDER_ATTACHMENT: 1,
  TEXTURE_BINDING: 2,
  COPY_SRC: 4,
  COPY_DST: 8,
};

class FakeCanvas {
  constructor() {
    this.width = 100;
    this.height = 60;
    this.style = {};
  }

  getContext(kind) {
    if (kind === "webgpu") return fakeContext;
    return {
      font: "",
      textAlign: "left",
      textBaseline: "alphabetic",
      measureText(text) {
        return {
          width: `${text ?? ""}`.length * 8,
          actualBoundingBoxLeft: 0,
          actualBoundingBoxRight: `${text ?? ""}`.length * 8,
          actualBoundingBoxAscent: 12,
          actualBoundingBoxDescent: 4,
        };
      },
    };
  }
}

const fakeTexture = () => ({
  createView() {
    return {};
  },
  destroy() {},
});

const fakePass = {
  setScissorRect() {},
  setPipeline() {},
  setVertexBuffer() {},
  setBindGroup() {},
  draw() {},
  end() {},
};

const fakeContext = {
  configure() {},
  getCurrentTexture() {
    return fakeTexture();
  },
};

const shaderSources = [];
const uploadedBuffers = [];
const bindGroupEntryCounts = [];
const fakePipeline = {
  getBindGroupLayout() {
    return {};
  },
};

const fakeDevice = {
  createShaderModule({ code }) {
    shaderSources.push(code);
    return {};
  },
  createRenderPipeline() {
    return fakePipeline;
  },
  createSampler() {
    return {};
  },
  createTexture() {
    return fakeTexture();
  },
  createBindGroup(descriptor) {
    bindGroupEntryCounts.push(descriptor?.entries?.length ?? 0);
    return {};
  },
  createBuffer(descriptor) {
    return { descriptor };
  },
  createCommandEncoder() {
    return {
      beginRenderPass() {
        return fakePass;
      },
      copyTextureToTexture() {},
      finish() {
        return {};
      },
    };
  },
  queue: {
    writeBuffer(_buffer, _offset, data) {
      uploadedBuffers.push(Array.from(data));
    },
    writeTexture() {},
    copyExternalImageToTexture() {},
    submit() {},
  },
};

const canvas = new FakeCanvas();
globalThis.HTMLCanvasElement = FakeCanvas;
globalThis.document = {
  createElement(tag) {
    return tag === "canvas" ? new FakeCanvas() : {};
  },
  getElementById(id) {
    return id === "radial-canvas" ? canvas : null;
  },
};
globalThis.window = { devicePixelRatio: 1 };

const assert = (condition, message) => {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
};

const assertNear = (actual, expected, message) => {
  assert(
    Math.abs(Number(actual) - Number(expected)) < 0.0001,
    `${message}: expected ${expected}, got ${actual}`,
  );
};

const imports = createWebGpuImports({
  device: fakeDevice,
  format: "rgba8unorm",
});

const stringHandle = value => {
  const handle = imports.begin_create_string();
  for (const ch of value) imports.string_append_char(handle, ch.codePointAt(0));
  return imports.finish_create_string(handle);
};

const surface = imports.create_surface(stringHandle("radial-canvas"), 100, 60, 1);
assert(surface > 0, "expected fake WebGPU surface");
const renderer = imports.create_renderer(surface);
assert(renderer > 0, "expected fake WebGPU renderer");

assert(
  shaderSources.some(source => source.includes("radial_gradient_color")),
  "visual shader must include radial_gradient_color",
);

assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame failed");
assert(
  imports.fill_rounded_rect_radial(
    renderer,
    10,
    12,
    40,
    24,
    6,
    24,
    24,
    18,
    1,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
  ) === 0,
  "fill_rounded_rect_radial failed",
);
assert(
  imports.stroke_rounded_rect_radial(
    renderer,
    10,
    12,
    40,
    24,
    6,
    3,
    24,
    24,
    18,
    1,
    0,
    0,
    1,
    0,
    0,
    1,
    1,
  ) === 0,
  "stroke_rounded_rect_radial failed",
);
assert(imports.present(renderer) === 0, "present failed");

const visual = uploadedBuffers.find(buffer => buffer.length === 12 * 22);
assert(visual, "expected one uploaded visual vertex buffer for radial fill/stroke");

assertNear(visual[7], 0, "fill mode");
assertNear(visual[8], 0, "fill stroke width");
assertNear(visual[9], 1, "fill brush kind");
assertNear(visual[10], 14, "fill radial center x");
assertNear(visual[11], 12, "fill radial center y");
assertNear(visual[12], 18, "fill radial radius");
assertNear(visual[13], 0, "fill radial payload reserved y");

const strokeOffset = 6 * 22;
assertNear(visual[strokeOffset + 7], 1, "stroke mode");
assertNear(visual[strokeOffset + 8], 3, "stroke width");
assertNear(visual[strokeOffset + 9], 1, "stroke brush kind");
assertNear(visual[strokeOffset + 10], 14, "stroke radial center x");
assertNear(visual[strokeOffset + 11], 12, "stroke radial center y");
assertNear(visual[strokeOffset + 12], 18, "stroke radial radius");

uploadedBuffers.length = 0;
bindGroupEntryCounts.length = 0;
assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame for clipped filter failed");
assert(imports.push_clip(renderer, 4, 6, 80, 42) === 0, "push_clip failed");
assert(imports.push_filter(renderer, 1, 1.08, stringHandle("")) === 0, "push_filter failed");
assert(
  imports.fill_rounded_rect(renderer, 12, 14, 32, 20, 6, 0, 0.8, 0.9, 1) === 0,
  "fill_rounded_rect inside clipped filter failed",
);
assert(imports.pop_filter(renderer) === 0, "pop_filter should composite a clipped unmasked filter");
assert(imports.pop_clip(renderer) === 0, "pop_clip failed");
assert(imports.present(renderer) === 0, "present for clipped filter failed");
assert(
  uploadedBuffers.some(buffer => buffer.length > 0),
  "expected clipped filter render path to upload vertices",
);
assert(
  bindGroupEntryCounts.some(count => count === 3),
  "clipped unmasked filter should create an advanced backdrop bind group",
);

uploadedBuffers.length = 0;
bindGroupEntryCounts.length = 0;
assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame for overlay layer failed");
assert(
  imports.push_layer(renderer, 0.75, 3, 0, 0, 0, 0, 0, 0, true) === 0,
  "push_layer overlay failed",
);
assert(
  imports.fill_rounded_rect(renderer, 20, 18, 34, 24, 8, 1, 0.2, 0.1, 1) === 0,
  "fill_rounded_rect inside overlay layer failed",
);
assert(imports.pop_layer(renderer) === 0, "pop_layer overlay failed");
assert(imports.present(renderer) === 0, "present for overlay layer failed");
assert(
  bindGroupEntryCounts.some(count => count === 2),
  "overlay snapshot copy should use a two-entry bind group",
);
assert(
  bindGroupEntryCounts.some(count => count === 3),
  "overlay advanced composite should use a three-entry bind group",
);

console.log("webgpu runtime radial brush tests: ok");
