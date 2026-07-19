import assert from "node:assert/strict";
import test from "node:test";

import { validateHarmonyosSkiaLinkCompatibility } from "./harmonyos-skia-link.mjs";

test("rejects the locked HarmonyOS dynamic Skia and static Ganesh GPU combination", () => {
  assert.throws(
    () => validateHarmonyosSkiaLinkCompatibility({
      renderer: "skia-gpu",
      linkFlags: "/provider/libskia_ganesh_ext.a -L/provider -lskia -lEGL",
    }),
    /Unset MOUI_SKIA_LINK_MODE or set it to static/,
  );
});

test("accepts the complete static HarmonyOS GPU provider", () => {
  assert.doesNotThrow(() => validateHarmonyosSkiaLinkCompatibility({
    renderer: "skia-gpu",
    linkFlags: "/provider/libskia_ganesh_ext.a /provider/libskia.a -lEGL",
  }));
});

test("accepts a dynamic raster provider without the Ganesh extension", () => {
  assert.doesNotThrow(() => validateHarmonyosSkiaLinkCompatibility({
    renderer: "skia-raster",
    linkFlags: "-L/provider -lskia",
  }));
});
