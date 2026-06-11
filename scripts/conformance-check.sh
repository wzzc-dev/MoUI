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
RUN_PLATFORM_SERVICES_MANIFEST_ONLY=false
RUN_TEXT=false
RUN_TEXT_DIAGNOSTIC=false
RUN_WGPU_EXPERIMENTAL=false
CAPTURE_ARTIFACT_DIR="artifacts/conformance"

usage() {
  printf 'Usage: %s [--input] [--layout] [--render] [--platform-services] [--platform-services-manifest-only] [--text] [--text-diagnostic] [--golden] [--bench] [--platform] [--wgpu-experimental]\n' "$0"
  printf '\n'
  printf 'Runs MoUI conformance-oriented package checks. With no focused flags, runs the default core/host/render/web/showcase suite. Focused flags select smaller suites. Optional modes add screenshot golden scaffolds, performance smoke builds, current-platform backend checks, or native WGPU diagnostics.\n'
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
    --platform-services-manifest-only)
      RUN_DEFAULT=false
      RUN_PLATFORM_SERVICES_MANIFEST_ONLY=true
      ;;
    --text)
      RUN_DEFAULT=false
      RUN_TEXT=true
      ;;
    --text-diagnostic)
      RUN_DEFAULT=false
      RUN_TEXT_DIAGNOSTIC=true
      ;;
    --wgpu-experimental)
      RUN_WGPU_EXPERIMENTAL=true
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
  benchmark_targets_json=""
  if [ "$mode" = "benchmark" ]; then
    benchmark_targets_json='  "benchmarkTargets": [
    {
      "name": "showcase-web-wasm",
      "target": "examples/showcase/web_wasm",
      "url": "http://127.0.0.1:18080/examples/showcase/web_wasm/",
      "metricsPath": "artifacts/benchmarks/showcase-web-wasm.json"
    },
    {
      "name": "markdown-editor-web-wasm",
      "target": "examples/markdown_editor/web_wasm",
      "url": "http://127.0.0.1:18080/examples/markdown_editor/web_wasm/",
      "metricsPath": "artifacts/benchmarks/markdown-editor-web-wasm.json"
    }
  ],
'
  fi
  cat > "$manifest_path" <<EOF
{
  "schemaVersion": 1,
  "mode": "$mode",
  "showcaseTarget": "examples/showcase/web_wasm",
  "url": "http://127.0.0.1:18080/examples/showcase/web_wasm/",
${benchmark_targets_json}
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

validate_capture_manifest() {
  mode="$1"
  manifest_path="$2"
  run node scripts/validate-conformance-capture-manifest.mjs "$manifest_path" --mode "$mode"
}

write_platform_evidence_manifest() {
  manifest_path="$1"
  mkdir -p "$(dirname "$manifest_path")"
  cat > "$manifest_path" <<'EOF'
{
  "schemaVersion": 2,
  "mode": "platform-runtime-evidence",
  "generatedBy": "scripts/conformance-check.sh --platform-services",
  "windowEvidenceSource": ".local_repos/window/scripts/record_moui_evidence.sh",
  "platforms": [
    {
      "name": "web",
      "status": "pending",
      "host": "Web wasm-gc browser host pending",
      "routineCommands": [
        "moon test moui/backend/web --target wasm-gc",
        "moon build examples/showcase/web_wasm --target wasm-gc"
      ],
      "runtimeEvidenceCommands": [
        "python3 -m http.server 18080 --bind 127.0.0.1",
        "node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed # opens examples/showcase/web_wasm",
        "node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json"
      ],
      "exampleTargets": [
        "examples/showcase/web_wasm"
      ],
      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh web --status pending",
      "consumerCommand": "pending",
      "observations": {
        "windowOpened": "pending",
        "resizeRedraw": "pending",
        "representativeInput": "pending",
        "cleanExit": "pending",
        "surface": "pending",
        "redraw": "pending",
        "resizeScale": "pending",
        "consumerInput": "pending",
        "textInput": "pending",
        "rendererHandle": "pending",
        "monitorCursor": "pending",
        "cleanShutdown": "pending",
        "imeCandidateAnchor": "pending",
        "imeSurroundingText": "pending",
        "imeCompositionVisual": "pending",
        "imeCommitDelete": "pending",
        "imeCursorUpdate": "pending",
        "imeScrollAnchor": "pending",
        "imeScaleDprAnchor": "pending",
        "imeResizeAnchor": "pending"
      },
      "artifacts": [
        "artifacts/platform-evidence/web/README.md"
      ],
      "notes": [
        "Web runtime evidence needs browser inspection of Showcase after the wasm-gc build."
      ]
    },
    {
      "name": "macos",
      "status": "pending",
      "host": "macOS Darwin host pending",
      "routineCommands": [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/macos_skia --target native"
      ],
      "runtimeEvidenceCommands": [
        "moon run examples/showcase/macos_skia --target native"
      ],
      "exampleTargets": [
        "examples/showcase/macos_skia"
      ],
      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh macos --status pending",
      "consumerCommand": "pending",
      "observations": {
        "windowOpened": "pending",
        "resizeRedraw": "pending",
        "representativeInput": "pending",
        "cleanExit": "pending",
        "surface": "pending",
        "redraw": "pending",
        "resizeScale": "pending",
        "consumerInput": "pending",
        "textInput": "pending",
        "rendererHandle": "pending",
        "monitorCursor": "pending",
        "cleanShutdown": "pending",
        "imeCandidateAnchor": "pending",
        "imeSurroundingText": "pending",
        "imeCompositionVisual": "pending",
        "imeCommitDelete": "pending",
        "imeCursorUpdate": "pending",
        "imeScrollAnchor": "pending",
        "imeScaleDprAnchor": "pending",
        "imeResizeAnchor": "pending"
      },
      "skiaEvidence": {
        "status": "pending",
        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named macOS host and does not reuse moui_skia dependency evidence.",
        "providerCommands": [
          "moon test moui/render/skia --target native",
          "moon test moui/backend/macos/skia --target native"
        ],
        "runtimeSmokeCommands": [
          "scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --smoke-log artifacts/platform-evidence/macos/skia-renderer-smoke.log --showcase-log artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log"
        ],
        "observations": {
          "providerPreflight": "pending",
          "fallbackUnavailable": "pending",
          "realRendererSmoke": "pending",
          "asyncImageSecondFrame": "pending",
          "showcaseFirstFrame": "pending"
        },
        "artifacts": [
          "artifacts/platform-evidence/macos/README.md"
        ],
        "notes": [
          "macOS Skia runtime evidence is pending until the real-Skia renderer smoke and Showcase first-frame Skia entrypoint log are recorded as artifacts."
        ]
      },
      "artifacts": [
        "artifacts/platform-evidence/macos/README.md"
      ],
      "notes": [
        "macOS package tests are host-scoped; native Skia app runtime evidence should name the local or CI host that launched the Skia examples. Native WGPU entrypoints are retained as experimental diagnostics outside this mainline manifest."
      ]
    },
    {
      "name": "windows",
      "status": "pending",
      "host": "Windows MSVC host pending",
      "routineCommands": [
        "moon test moui/backend/windows --target native",
        "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File scripts/windows/package_windows_app_msvc.ps1 -Package examples/showcase/windows_skia"
      ],
      "runtimeEvidenceCommands": [
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\""
      ],
      "exampleTargets": [
        "examples/showcase/windows_skia"
      ],
      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh windows --status pending",
      "consumerCommand": "pending",
      "observations": {
        "windowOpened": "pending",
        "resizeRedraw": "pending",
        "representativeInput": "pending",
        "cleanExit": "pending",
        "surface": "pending",
        "redraw": "pending",
        "resizeScale": "pending",
        "consumerInput": "pending",
        "textInput": "pending",
        "rendererHandle": "pending",
        "monitorCursor": "pending",
        "cleanShutdown": "pending",
        "imeCandidateAnchor": "pending",
        "imeSurroundingText": "pending",
        "imeCompositionVisual": "pending",
        "imeCommitDelete": "pending",
        "imeCursorUpdate": "pending",
        "imeScrollAnchor": "pending",
        "imeScaleDprAnchor": "pending",
        "imeResizeAnchor": "pending"
      },
      "skiaEvidence": {
        "status": "pending",
        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Windows/MSVC host and does not reuse moui_skia dependency evidence.",
        "providerCommands": [
          "moon test moui/render/skia --target native",
          "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon test moui/backend/windows/skia --target native }\"",
          "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly"
        ],
        "runtimeSmokeCommands": [
          "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; $env:MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT='1'; moon run examples/showcase/windows_skia --target native }\""
        ],
        "observations": {
          "providerPreflight": "pending",
          "fallbackUnavailable": "pending",
          "realRendererSmoke": "pending",
          "asyncImageSecondFrame": "pending",
          "showcaseFirstFrame": "pending"
        },
        "artifacts": [
          "artifacts/platform-evidence/windows/README.md"
        ],
        "notes": [
          "Windows Skia runtime evidence remains matching-host pending until the MSVC first-frame Showcase log is recorded."
        ]
      },
      "artifacts": [
        "artifacts/platform-evidence/windows/README.md"
      ],
      "notes": [
        "Windows runtime evidence must come from an MSVC host after backend tests, Skia Showcase build/package, and direct Skia Showcase launch. Native WGPU entrypoints are retained as experimental diagnostics outside this mainline manifest."
      ]
    },
    {
      "name": "linux",
      "status": "pending",
      "host": "Linux Wayland host pending",
      "routineCommands": [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/linux_skia --target native"
      ],
      "runtimeEvidenceCommands": [
        "moon run examples/showcase/linux_skia --target native"
      ],
      "exampleTargets": [
        "examples/showcase/linux_skia"
      ],
      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh linux --status pending",
      "consumerCommand": "pending",
      "observations": {
        "windowOpened": "pending",
        "resizeRedraw": "pending",
        "representativeInput": "pending",
        "cleanExit": "pending",
        "surface": "pending",
        "redraw": "pending",
        "resizeScale": "pending",
        "consumerInput": "pending",
        "textInput": "pending",
        "rendererHandle": "pending",
        "monitorCursor": "pending",
        "cleanShutdown": "pending",
        "imeCandidateAnchor": "pending",
        "imeSurroundingText": "pending",
        "imeCompositionVisual": "pending",
        "imeCommitDelete": "pending",
        "imeCursorUpdate": "pending",
        "imeScrollAnchor": "pending",
        "imeScaleDprAnchor": "pending",
        "imeResizeAnchor": "pending"
      },
      "skiaEvidence": {
        "status": "pending",
        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Linux Wayland host and does not reuse moui_skia dependency evidence.",
        "providerCommands": [
          "moon test moui/render/skia --target native",
          "moon test moui/backend/linux/skia --target native",
          "moon build examples/showcase/linux_skia --target native"
        ],
        "runtimeSmokeCommands": [
          "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native"
        ],
        "observations": {
          "providerPreflight": "pending",
          "fallbackUnavailable": "pending",
          "realRendererSmoke": "pending",
          "asyncImageSecondFrame": "pending",
          "showcaseFirstFrame": "pending"
        },
        "artifacts": [
          "artifacts/platform-evidence/linux/README.md"
        ],
        "notes": [
          "Linux Skia runtime evidence remains matching-host pending until the Wayland first-frame Showcase log is recorded with configured real Skia link flags."
        ]
      },
      "artifacts": [
        "artifacts/platform-evidence/linux/README.md"
      ],
      "notes": [
        "Linux runtime evidence requires a matching Wayland compositor and configured real Skia link flags; native WGPU/Vulkan entrypoints are retained as experimental diagnostics outside this mainline manifest. Keep unsupported service gaps explicit."
      ]
    }
  ]
}
EOF
  printf 'Wrote platform evidence manifest: %s\n' "$manifest_path"
}

validate_platform_evidence_manifest() {
  manifest_path="$1"
  run node scripts/validate-platform-evidence-manifest.mjs "$manifest_path"
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
  run moon test moui/render/skia --target native
  run moon test moui/render/webgpu_adapter --target wasm-gc
  run node scripts/test-webgpu-runtime-radial.mjs
  if "$RUN_WGPU_EXPERIMENTAL"; then
    run moon test moui/render/wgpu --target native
  else
    printf '\nSkipping native WGPU renderer diagnostics. Pass --wgpu-experimental to run them.\n'
  fi
fi

if "$RUN_PLATFORM_SERVICES"; then
  run moon test moui/backend/host --target native
  run moon test moui/backend/web --target wasm-gc
  if [ -f ".local_repos/window/linux/generated/xdg-decoration-protocol.c" ] &&
    [ -f ".local_repos/window/linux/generated/xdg-shell-protocol.c" ]; then
    run moon test moui/backend/linux --target native
  else
    printf '\nSkipping backend/linux platform-service tests because .local_repos/window/linux/generated Wayland protocol sources are missing.\n'
  fi
  if [ "$(uname -s)" = "Darwin" ]; then
    run moon test moui/backend/macos --target native
  fi
  write_platform_evidence_manifest "$CAPTURE_ARTIFACT_DIR/platform-runtime-evidence.json"
  validate_platform_evidence_manifest "$CAPTURE_ARTIFACT_DIR/platform-runtime-evidence.json"
fi

if "$RUN_PLATFORM_SERVICES_MANIFEST_ONLY"; then
  write_platform_evidence_manifest "$CAPTURE_ARTIFACT_DIR/platform-runtime-evidence.json"
  validate_platform_evidence_manifest "$CAPTURE_ARTIFACT_DIR/platform-runtime-evidence.json"
fi

if "$RUN_TEXT"; then
  run moon test moui/core --target native
  run moon test moui/render/skia --target native
  run moon test moui/render/webgpu_adapter --target wasm-gc
  run moon test moui/backend/web --target wasm-gc
  if "$RUN_WGPU_EXPERIMENTAL"; then
    run moon test moui/render/wgpu --target native
    run moon test moui/render/wgpu/cosmic_text --target native
  else
    printf '\nSkipping native WGPU text diagnostics. Pass --wgpu-experimental to run them.\n'
  fi
fi

if "$RUN_TEXT_DIAGNOSTIC"; then
  run moon test moui/tests/text_conformance/native --target native
  run moon test moui/tests/text_conformance/web --target wasm-gc
fi

if "$RUN_GOLDEN"; then
  run moon build examples/showcase/web_wasm --target wasm-gc
  write_showcase_capture_manifest "golden" "$CAPTURE_ARTIFACT_DIR/showcase-golden-capture.json"
  validate_capture_manifest "golden" "$CAPTURE_ARTIFACT_DIR/showcase-golden-capture.json"
  print_golden_capture_instructions
fi

if "$RUN_BENCH"; then
  run moon build examples/showcase/web_wasm --target wasm-gc
  run moon build examples/markdown_editor/web_wasm --target wasm-gc
  run node scripts/validate-web-runtime-handoff.mjs --manifest "$CAPTURE_ARTIFACT_DIR/web-runtime-handoff.json"
  write_showcase_capture_manifest "benchmark" "$CAPTURE_ARTIFACT_DIR/showcase-benchmark-capture.json"
  validate_capture_manifest "benchmark" "$CAPTURE_ARTIFACT_DIR/showcase-benchmark-capture.json"
  printf '\nBenchmark scaffold complete. Record startup, frame time, dirty-count, draw-command count, memory, and render inspector counters for Showcase and Markdown Editor targets named in the manifest.\n'
fi

if "$RUN_PLATFORM"; then
  if "$RUN_WGPU_EXPERIMENTAL"; then
    run sh scripts/dev-check.sh --platform-examples-test --wgpu-experimental
  else
    run sh scripts/dev-check.sh --platform-examples-test
  fi
fi

printf '\nConformance checks passed.\n'
