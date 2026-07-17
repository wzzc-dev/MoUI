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
    const context = {
      font: "",
      textAlign: "left",
      textBaseline: "alphabetic",
      fillStyle: "white",
      lastText: "",
      clearRect() {
        this.lastText = "";
      },
      fillText(text) {
        this.lastText = `${text ?? ""}`;
      },
      getImageData(_x, _y, width, height) {
        const data = new Uint8ClampedArray(width * height * 4);
        const color = this.lastText.includes("👩‍💻");
        for (let i = 0; i < data.length; i += 4) {
          data[i] = color ? 245 : 255;
          data[i + 1] = color ? 80 : 255;
          data[i + 2] = color ? 20 : 255;
          data[i + 3] = 255;
        }
        return { data };
      },
      measureText(text) {
        return {
          width: Array.from(`${text ?? ""}`).length * 8,
          actualBoundingBoxLeft: 0,
          actualBoundingBoxRight: Array.from(`${text ?? ""}`).length * 8,
          actualBoundingBoxAscent: 12,
          actualBoundingBoxDescent: 4,
        };
      },
    };
    return {
      ...context,
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

const observationEvents = [];
globalThis.__mouiWebRuntimeObservation = {
  recordEvent(event) {
    observationEvents.push(event);
  },
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

const canvasIdHandle = stringHandle("radial-canvas");
const surface = imports.create_surface(canvasIdHandle, 100, 60, 1);
assert(surface > 0, "expected fake WebGPU surface");
assert(
  imports.create_surface(canvasIdHandle, 100, 60, 1) === 0,
  "WebGPU string handles should be consumed after one host call",
);
const renderer = imports.create_renderer(surface);
assert(renderer > 0, "expected fake WebGPU renderer");

assert(
  shaderSources.some(source => source.includes("radial_gradient_color")),
  "visual shader must include radial_gradient_color",
);
assert(
  shaderSources.some(source =>
    source.includes("return brush_color(in.local, in.blurStart.zw, in.end, in.color0, in.color1, in.blurStart.y);"),
  ),
  "visual shader must shade path mode through brush_color",
);
assert(
  shaderSources.some(source => source.includes("in.color.r < -0.5")),
  "text shader must preserve RGBA color glyph atlas payloads",
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
assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame for radial path failed");
const radialPathPayload = [
  10, 10, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
  42, 10, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
  10, 42, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
].join(",");
assert(
  imports.draw_path_mesh(renderer, stringHandle(radialPathPayload)) === 0,
  "draw_path_mesh radial payload failed",
);
assert(imports.present(renderer) === 0, "present radial path failed");
const pathVisual = uploadedBuffers.find(buffer => buffer.length === 3 * 22);
assert(pathVisual, "expected uploaded visual vertex buffer for radial path");
assertNear(pathVisual[2], 10, "path local x");
assertNear(pathVisual[3], 10, "path local y");
assertNear(pathVisual[7], 3, "path mode");
assertNear(pathVisual[9], 1, "path radial brush kind");
assertNear(pathVisual[10], 20, "path radial center x");
assertNear(pathVisual[11], 20, "path radial center y");
assertNear(pathVisual[12], 16, "path radial radius");
assertNear(pathVisual[18], 0, "path edge red");
assertNear(pathVisual[19], 0, "path edge green");
assertNear(pathVisual[20], 1, "path edge blue");

uploadedBuffers.length = 0;
assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame for malformed path failed");
const malformedPathValues = radialPathPayload.split(",");
malformedPathValues[17] = "NaN";
assert(
  imports.draw_path_mesh(renderer, stringHandle(malformedPathValues.join(","))) === 0,
  "draw_path_mesh malformed payload should be ignored without failing",
);
assert(imports.present(renderer) === 0, "present malformed path failed");
assert(
  !uploadedBuffers.some(buffer => buffer.length === 3 * 22),
  "malformed path payload must not upload misaligned path vertices",
);

uploadedBuffers.length = 0;
assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame for partial triangle path failed");
assert(
  imports.draw_path_mesh(
    renderer,
    stringHandle([
      radialPathPayload,
      [
        42, 42, 1, 20, 20, 16, 0, 1, 0, 0, 1, 0, 0, 1, 1,
      ].join(","),
    ].join(",")),
  ) === 0,
  "draw_path_mesh partial triangle payload should be ignored without failing",
);
assert(imports.present(renderer) === 0, "present partial triangle path failed");
assert(
  !uploadedBuffers.some(buffer => buffer.length === 4 * 22),
  "partial triangle path payload must not upload non-triangle vertices",
);

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

uploadedBuffers.length = 0;
observationEvents.length = 0;
assert(imports.begin_frame(renderer, 100, 60) === 0, "begin_frame for text smoke failed");
assert(
  imports.draw_text(
    renderer,
    stringHandle("👩‍💻"),
    2,
    2,
    40,
    24,
    stringHandle("system-ui"),
    stringHandle("normal"),
    18,
    500,
    0,
    0,
    0,
    1,
    0,
  ) === 0,
  "draw_text emoji smoke failed",
);
assert(
  imports.draw_text(
    renderer,
    stringHandle("ABC אבג 123"),
    2,
    28,
    90,
    18,
    stringHandle("system-ui"),
    stringHandle("normal"),
    14,
    500,
    0,
    0,
    0,
    1,
    0,
  ) === 0,
  "draw_text bidi smoke failed",
);
for (let index = 1; index <= 3; index += 1) {
  assert(
    imports.draw_text(
      renderer,
      stringHandle(`Smoke wrap line ${index}`),
      2,
      42 + index * 8,
      90,
      14,
      stringHandle("system-ui"),
      stringHandle("normal"),
      12,
      500,
      0,
      0,
      0,
      1,
      0,
    ) === 0,
    `draw_text paragraph smoke ${index} failed`,
  );
}
assert(imports.present(renderer) === 0, "present text smoke failed");
assert(
  observationEvents.some(event =>
    event.name === "text_color_glyph" &&
    event.format === "rgba" &&
    typeof event.fontFamily === "string" &&
    event.fontFamily.length > 0 &&
    Number(event.fontSize) > 0 &&
    typeof event.glyphKey === "string" &&
    event.glyphKey.length > 0 &&
    Number(event.glyphWidth) > 0 &&
    Number(event.highSaturationPixels) >= 8
  ),
  "text smoke must record high-saturation RGBA glyph observation with font/glyph metadata",
);
assert(
  observationEvents.some(event =>
    event.name === "text_grapheme_layout" &&
    event.singleGraphemeCluster === true &&
    event.noInteriorCaret === true
  ),
  "text smoke must record ZWJ single-grapheme observation",
);
assert(
  observationEvents.some(event => event.name === "text_bidi_layout" && event.visualOrderDiffers === true),
  "text smoke must record bidi visual-order observation",
);
assert(
  observationEvents.filter(event => event.name === "text_paragraph_line").length === 3,
  "text smoke must record paragraph line metrics",
);
assert(
  uploadedBuffers.some(buffer => buffer.some(value => value < -0.5)),
  "text vertices must include the color-glyph RGBA atlas sentinel",
);

console.log("webgpu runtime radial brush tests: ok");
