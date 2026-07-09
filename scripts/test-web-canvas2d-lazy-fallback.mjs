#!/usr/bin/env node

import { createWebGpuImportsAsync } from "../moui/backend/web/runtime.js";

const assert = (condition, message) => {
  if (!condition) {
    console.error(message);
    process.exit(1);
  }
};

class FakeCanvas {
  constructor() {
    this.width = 0;
    this.height = 0;
    this.style = {};
    this.parentElement = {
      getBoundingClientRect() {
        return { width: 320, height: 240 };
      },
    };
  }

  getContext(kind) {
    if (kind === "2d") {
      return {
        imageSmoothingEnabled: false,
        imageSmoothingQuality: "low",
        measureText(value) {
          return { width: `${value ?? ""}`.length * 8 };
        },
      };
    }
    if (kind === "webgpu") {
      return {
        configure() {},
      };
    }
    return null;
  }
}

const previousDocument = globalThis.document;
const previousWindow = globalThis.window;
const previousNavigator = globalThis.navigator;
const previousHtmlCanvasElement = globalThis.HTMLCanvasElement;
const previousGpuTextureUsage = globalThis.GPUTextureUsage;

const canvas = new FakeCanvas();
const fakeDocument = {
  createElement(tagName) {
    return tagName === "canvas" ? new FakeCanvas() : {};
  },
  getElementById(id) {
    return id === "canvas" ? canvas : null;
  },
};

Object.defineProperty(globalThis, "document", {
  configurable: true,
  value: fakeDocument,
});
Object.defineProperty(globalThis, "window", {
  configurable: true,
  value: { devicePixelRatio: 2, innerWidth: 320, innerHeight: 240 },
});
Object.defineProperty(globalThis, "HTMLCanvasElement", {
  configurable: true,
  value: FakeCanvas,
});
Object.defineProperty(globalThis, "GPUTextureUsage", {
  configurable: true,
  value: { RENDER_ATTACHMENT: 1, TEXTURE_BINDING: 2 },
});

const restoreGlobal = (name, previous) => {
  if (previous === undefined) {
    delete globalThis[name];
  } else {
    Object.defineProperty(globalThis, name, {
      configurable: true,
      value: previous,
    });
  }
};

try {
  const webGpuStatuses = [];
  const fakeDevice = {
    addEventListener() {},
    lost: new Promise(() => {}),
    createSampler() {
      return {};
    },
    createBindGroupLayout() {
      return {};
    },
    createPipelineLayout() {
      return {};
    },
    createShaderModule() {
      return {};
    },
    createRenderPipeline() {
      return {};
    },
    createBuffer() {
      return {};
    },
    queue: {
      writeBuffer() {},
    },
  };
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: {
      gpu: {
        async requestAdapter() {
          return {
            async requestDevice() {
              return fakeDevice;
            },
          };
        },
        getPreferredCanvasFormat() {
          return "rgba8unorm";
        },
      },
    },
  });

  const webgpu = await createWebGpuImportsAsync({
    onStatus: message => webGpuStatuses.push(message),
  });
  assert(webgpu.webgpu_available() === true, "mock WebGPU path should be available");
  assert(
    !webGpuStatuses.some(message => message.includes("Canvas2D renderer")),
    "mock WebGPU path should not load Canvas2D fallback",
  );

  const fallbackStatuses = [];
  const fallback = await createWebGpuImportsAsync({
    forceUnavailable: true,
    onStatus: message => fallbackStatuses.push(message),
  });
  assert(
    fallbackStatuses.some(message => message.includes("Canvas2D renderer")),
    "forced unavailable path should report Canvas2D fallback",
  );
  assert(
    fallback.webgpu_available() === true && fallback.can_render() === true,
    "Canvas2D fallback should expose a render-capable webgpu-compatible import surface",
  );
  const canvasId = fallback.begin_create_string();
  for (const ch of "canvas") {
    fallback.string_append_char(canvasId, ch.codePointAt(0));
  }
  const surface = fallback.create_surface(fallback.finish_create_string(canvasId), 160, 120, 2);
  assert(surface > 0, "Canvas2D fallback should create a surface through dynamic import");
  assert(canvas.width === 640 && canvas.height === 480, "Canvas2D fallback should size canvas with host DPR");
} finally {
  restoreGlobal("document", previousDocument);
  restoreGlobal("window", previousWindow);
  restoreGlobal("navigator", previousNavigator);
  restoreGlobal("HTMLCanvasElement", previousHtmlCanvasElement);
  restoreGlobal("GPUTextureUsage", previousGpuTextureUsage);
}

console.log("web Canvas2D lazy fallback tests: ok");
