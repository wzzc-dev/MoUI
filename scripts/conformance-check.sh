#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_GOLDEN=false
RUN_BENCH=false
RUN_PLATFORM=false
RUN_DEFAULT=true
RUN_INPUT=false
RUN_LAYOUT=false
RUN_RENDER=false
RUN_PLATFORM_SERVICES=false
RUN_TEXT=false
RUN_TEXT_DIAGNOSTIC=false
CAPTURE_ARTIFACT_DIR="artifacts/conformance"

usage() {
  printf 'Usage: %s [--input] [--layout] [--render] [--platform-services] [--text] [--text-diagnostic] [--golden] [--bench] [--platform]\n' "$0"
  printf '\n'
  printf 'Runs MoUI conformance-oriented package checks. With no focused flags, runs the default core/host/render/web/showcase suite. Focused flags select smaller suites. Optional modes add screenshot golden scaffolds, performance smoke builds, or current-platform backend checks.\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --golden)
      RUN_GOLDEN=true
      ;;
    --bench)
      RUN_BENCH=true
      ;;
    --platform)
      RUN_PLATFORM=true
      ;;
    --input)
      RUN_DEFAULT=false
      RUN_INPUT=true
      ;;
    --layout)
      RUN_DEFAULT=false
      RUN_LAYOUT=true
      ;;
    --render)
      RUN_DEFAULT=false
      RUN_RENDER=true
      ;;
    --platform-services)
      RUN_DEFAULT=false
      RUN_PLATFORM_SERVICES=true
      ;;
    --text)
      RUN_DEFAULT=false
      RUN_TEXT=true
      ;;
    --text-diagnostic)
      RUN_DEFAULT=false
      RUN_TEXT_DIAGNOSTIC=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

print_golden_capture_instructions() {
  cat <<'EOF'

Golden screenshot scaffold complete.

Built target:
  examples/showcase/web_wasm

Generated capture manifest:
  artifacts/conformance/showcase-golden-capture.json

Manual capture handoff:
  1. Serve the repository root or built example directory with a static server.
     Example: python3 -m http.server 18080
  2. Open http://127.0.0.1:18080/examples/showcase/web_wasm/
  3. Capture these canonical viewports:
     - desktop: 1440x900
     - tablet: 1024x768
     - mobile: 390x844
  4. Save artifacts under:
     artifacts/golden/showcase-web-wasm/<viewport>.png

This scaffold intentionally verifies the build and capture contract only. It
does not run browser automation, pixel diffing, or renderer golden assertions.
The capture manifest records the screenshot targets and render inspector
counters that must be saved with the captured artifacts.
EOF
}

write_showcase_capture_manifest() {
  mode="$1"
  manifest_path="$2"
  mkdir -p "$(dirname "$manifest_path")"
  cat > "$manifest_path" <<EOF
{
  "schemaVersion": 1,
  "mode": "$mode",
  "showcaseTarget": "examples/showcase/web_wasm",
  "url": "http://127.0.0.1:18080/examples/showcase/web_wasm/",
  "renderInspectorSource": "Showcase Diagnostics inspector snapshot card backed by @core.RenderInspectorSnapshot",
  "renderInspectorCounters": [
    "command_count",
    "text_count",
    "image_count",
    "clip_depth",
    "open_clip_depth",
    "layer_depth",
    "open_layer_depth",
    "filter_depth",
    "open_filter_depth",
    "path_count",
    "shader_count",
    "unbalanced_pop_count"
  ],
  "screenshotArtifacts": [
    {
      "name": "desktop",
      "viewport": "1440x900",
      "path": "artifacts/golden/showcase-web-wasm/desktop.png"
    },
    {
      "name": "tablet",
      "viewport": "1024x768",
      "path": "artifacts/golden/showcase-web-wasm/tablet.png"
    },
    {
      "name": "mobile",
      "viewport": "390x844",
      "path": "artifacts/golden/showcase-web-wasm/mobile.png"
    }
  ],
  "benchmarkMetrics": [
    "startup_ms",
    "frame_time_ms",
    "dirty_count",
    "draw_command_count",
    "memory_bytes",
    "render_inspector_counters"
  ],
  "notes": [
    "This manifest connects the build scaffold to the manual capture artifacts.",
    "It does not contain captured measurements or screenshots by itself."
  ]
}
EOF
  printf 'Wrote capture manifest: %s\n' "$manifest_path"
}

if "$RUN_DEFAULT"; then
  run moon test moui/core --target native
  run moon test moui/backend/host --target native
  run moon test moui/render --target native
  run moon test moui/render/webgpu_adapter --target wasm-gc
  run moon test moui/backend/web --target wasm-gc
  run moon test examples/showcase/app --target native
fi

if "$RUN_INPUT"; then
  run moon test moui/core --target native
  run moon test moui/backend/host --target native
fi

if "$RUN_LAYOUT"; then
  run moon test moui/core --target native
fi

if "$RUN_RENDER"; then
  run moon test moui/render --target native
  run moon test moui/render/wgpu --target native
  run moon test moui/render/skia --target native
  run moon test moui/render/webgpu_adapter --target wasm-gc
fi

if "$RUN_PLATFORM_SERVICES"; then
  run moon test moui/backend/host --target native
  run moon test moui/backend/web --target wasm-gc
  if [ -f ".local_repos/window/linux/generated/xdg-decoration-protocol.c" ]; then
    run moon test moui/backend/linux --target native
  else
    printf '\nSkipping backend/linux platform-service tests because .local_repos/window/linux/generated/xdg-decoration-protocol.c is missing.\n'
  fi
  if [ "$(uname -s)" = "Darwin" ]; then
    run moon test moui/backend/macos --target native
  fi
fi

if "$RUN_TEXT"; then
  run moon test moui/core --target native
  run moon test moui/render/wgpu --target native
  run moon test moui/render/wgpu/cosmic_text --target native
  run moon test moui/render/webgpu_adapter --target wasm-gc
  run moon test moui/backend/web --target wasm-gc
fi

if "$RUN_TEXT_DIAGNOSTIC"; then
  run moon test moui/tests/text_conformance/native --target native
  run moon test moui/tests/text_conformance/web --target wasm-gc
fi

if "$RUN_GOLDEN"; then
  run moon build examples/showcase/web_wasm --target wasm-gc
  write_showcase_capture_manifest "golden" "$CAPTURE_ARTIFACT_DIR/showcase-golden-capture.json"
  print_golden_capture_instructions
fi

if "$RUN_BENCH"; then
  run moon build examples/showcase/web_wasm --target wasm-gc
  run moon build examples/markdown_editor/web_wasm --target wasm-gc
  write_showcase_capture_manifest "benchmark" "$CAPTURE_ARTIFACT_DIR/showcase-benchmark-capture.json"
  printf '\nBenchmark scaffold complete. Record startup, frame time, dirty-count, draw-command count, memory, and render inspector counters from the built examples.\n'
fi

if "$RUN_PLATFORM"; then
  run sh scripts/dev-check.sh --platform-examples-test
fi

printf '\nConformance checks passed.\n'
