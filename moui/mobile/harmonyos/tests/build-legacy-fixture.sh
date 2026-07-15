#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
config="$repo_root/artifacts/harmonyos/legacy-component-gallery.mobile.json"
mkdir -p "$(dirname "$config")"

node - "$config" <<'NODE'
const fs = require("fs");
const output = process.argv[2];
const config = {
  schemaVersion: 1,
  id: "component_gallery",
  displayName: "Component Gallery",
  artifactName: "component_gallery",
  appPackage: "examples/component_gallery/app",
  mobile: { fullscreen: true, supportsScroll: true },
  harmonyos: {
    bundleName: "dev.wzzc.moui.componentgallery",
    productName: "ComponentGallery",
    appName: "Component Gallery",
    moduleName: "entry",
    moduleDescription: "MoUI Component Gallery HarmonyOS app",
    entryDescription: "Component Gallery HarmonyOS entry ability",
    native: {
      moonPackage: "examples/component_gallery/harmonyos",
      generatedC: "harmonyos.c",
      nativeLibrary: "component_gallery_harmonyos",
      appArg: "moui-component-gallery-harmonyos",
      moonbitMainAlias: "moui_component_gallery_harmonyos_moonbit_generated_main",
      exports: {
        attachSurface: "component_gallery_harmonyos_attach_surface",
        resize: "component_gallery_harmonyos_resize",
        dispatchPointer: "component_gallery_harmonyos_dispatch_pointer",
        dispatchScroll: "component_gallery_harmonyos_dispatch_scroll",
        frameTick: "component_gallery_harmonyos_frame_tick",
        renderFrame: "component_gallery_harmonyos_render_frame",
        detachSurface: "component_gallery_harmonyos_detach_surface"
      }
    }
  }
};
fs.writeFileSync(output, `${JSON.stringify(config, null, 2)}\n`);
NODE

"$repo_root/moui/scripts/mobile/build-harmonyos-hap.sh" \
  --workspace-root "$repo_root" \
  --moui-root "$repo_root/moui" \
  --skia-root "$repo_root/moui_skia" \
  --app component_gallery \
  --app-config "$config" \
  --harmonyos-project "$repo_root/examples/component_gallery/harmonyos_app" \
  --build-dir "$repo_root/artifacts/harmonyos/component-gallery-legacy-fixture" \
  --legacy-shell \
  "$@"
