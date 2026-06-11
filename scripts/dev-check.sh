#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_PLATFORM_EXAMPLES_TEST=false
RUN_PLATFORM_EXAMPLES_BUILD=false
RUN_SKIA_REAL_SMOKE=false
RUN_WGPU_EXPERIMENTAL=false

for arg in "$@"; do
  case "$arg" in
    --platform-examples-test)
      RUN_PLATFORM_EXAMPLES_TEST=true
      ;;
    --platform-examples-build)
      RUN_PLATFORM_EXAMPLES_BUILD=true
      ;;
    --platform-examples)
      RUN_PLATFORM_EXAMPLES_TEST=true
      ;;
    --skia-real-smoke)
      RUN_SKIA_REAL_SMOKE=true
      ;;
    --wgpu-experimental)
      RUN_WGPU_EXPERIMENTAL=true
      ;;
    --help|-h)
      printf 'Usage: %s [--platform-examples-test] [--platform-examples-build] [--skia-real-smoke] [--wgpu-experimental]\n' "$0"
      printf '\n'
      printf 'Runs bounded package-level checks, guidance consistency checks, and Web wasm-gc example builds.\n'
      printf 'Pass --platform-examples-test to also run current-platform backend tests.\n'
      printf 'Pass --platform-examples-build to also build current-platform native examples.\n'
      printf 'Pass --skia-real-smoke to run the opt-in real Skia smoke when local Skia link flags are configured.\n'
      printf 'Pass --wgpu-experimental to also run native WGPU diagnostic package/provider checks.\n'
      printf 'On macOS, scripts/macos-skia-renderer-smoke.sh can resolve JetBrains/source/existing Skia providers and temporarily configure those flags; pass that helper --run-gpu-smoke for the explicit Metal GPU route marker.\n'
      printf 'Native example builds use the Skia mainline by default; WGPU example builds are experimental diagnostics.\n'
      printf 'Deprecated alias: --platform-examples behaves like --platform-examples-test.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--platform-examples-test] [--platform-examples-build] [--skia-real-smoke] [--wgpu-experimental]\n' "$0" >&2
      exit 2
      ;;
  esac
done

if ! "$RUN_SKIA_REAL_SMOKE"; then
  export MOUI_SKIA_DISABLE_PREBUILD_SKIA="${MOUI_SKIA_DISABLE_PREBUILD_SKIA:-1}"
fi

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

run_built_executable() {
  executable="$1"
  if [ ! -x "$executable" ]; then
    printf 'Built executable is missing or not executable: %s\n' "$executable" >&2
    exit 1
  fi
  run "$executable"
}

run sh scripts/check-local-deps.sh
run node scripts/validate-guidance-consistency.mjs
run node scripts/validate-renderer-provider-manifests.mjs
run node scripts/validate-skia-entrypoints.mjs
run node scripts/test-validate-skia-entrypoints.mjs
run node scripts/test-validate-conformance-capture-manifest.mjs
run node scripts/test-validate-platform-evidence-manifest.mjs
run node scripts/test-record-platform-evidence-manifest.mjs
run node --check scripts/record-native-ime-evidence.mjs
run node scripts/test-record-native-ime-evidence.mjs
run node scripts/test-record-native-skia-evidence.mjs
run node --check scripts/record-macos-platform-runtime-evidence.mjs
run node scripts/test-record-macos-platform-runtime-evidence.mjs
run sh -n scripts/record-macos-local-runtime-evidence.sh
run node --check scripts/generate-grapheme-break-fixtures.mjs
run node scripts/generate-grapheme-break-fixtures.mjs --check
run node --check scripts/validate-renderer-proof-manifest.mjs
run node scripts/test-validate-renderer-proof-manifest.mjs
run node --check scripts/record-renderer-proof-manifest.mjs
run node scripts/test-record-renderer-proof-manifest.mjs
run node --check scripts/record-web-renderer-proof-manifest.mjs
run node scripts/test-record-web-renderer-proof-manifest.mjs
run node --check scripts/ci-renderer-proof-native.mjs
run node scripts/test-validate-web-runtime-handoff-manifest.mjs
run node scripts/test-record-web-runtime-presentation.mjs
run node scripts/test-validate-web-runtime-presentation-manifest.mjs
run node --check scripts/validate-checked-conformance-artifacts.mjs
run node scripts/validate-checked-conformance-artifacts.mjs
run sh -n scripts/ci-moon-update.sh
run sh -n scripts/ci-web-runtime-presentation.sh
run sh -n scripts/ci-renderer-proof-native.sh
run sh -n scripts/ci-renderer-proof-summary.sh

run moon check

run moon test moui/core --target native
run moon test moui/views --target native
run moon test moui/render --target native
run moon test moui/render/skia --target native
run moon test moui/backend/host --target native

run moon test moui_skia --target native

run moon test moui/render/webgpu_adapter --target wasm-gc
run moon test moui/backend/web --target wasm-gc

run moon test examples/showcase/app --target native
run moon test examples/markdown_editor/app --target native

run moon build examples/showcase/web_wasm --target wasm-gc
run moon build examples/markdown_editor/web_wasm --target wasm-gc
run node scripts/test-validate-web-runtime-handoff.mjs
run node scripts/validate-web-runtime-handoff.mjs

if "$RUN_WGPU_EXPERIMENTAL"; then
  run moon test moui/render/wgpu --target native
else
  printf '\nSkipping native WGPU renderer diagnostics. Pass --wgpu-experimental to run them.\n'
fi

if "$RUN_PLATFORM_EXAMPLES_TEST" || "$RUN_PLATFORM_EXAMPLES_BUILD"; then
  case "$(uname -s)" in
    Darwin)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test moui/backend/macos --target native
        run moon test moui/backend/macos/skia --target native
        if "$RUN_WGPU_EXPERIMENTAL"; then
          run moon test moui/backend/macos/wgpu --target native
        fi
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding selected current-platform Skia native example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/showcase/macos_skia --target native
        run moon build examples/markdown_editor/macos_skia --target native
        if "$RUN_WGPU_EXPERIMENTAL"; then
          run moon build examples/showcase/macos_wgpu --target native
          run moon build examples/markdown_editor/macos_wgpu --target native
        fi
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test moui/backend/windows --target native
        run moon test moui/backend/windows/skia --target native
        if "$RUN_WGPU_EXPERIMENTAL"; then
          run moon test moui/backend/windows/wgpu --target native
        fi
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding selected current-platform Skia native example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/showcase/windows_skia --target native
        run moon build examples/markdown_editor/windows_skia --target native
        if "$RUN_WGPU_EXPERIMENTAL"; then
          run moon build examples/showcase/windows_wgpu --target native
          run moon build examples/showcase/windows_wgpu_cosmic --target native
          run moon build examples/markdown_editor/windows_wgpu --target native
        fi
      fi
      ;;
    Linux)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test moui/backend/linux --target native
        run moon test moui/backend/linux/skia --target native
        if "$RUN_WGPU_EXPERIMENTAL"; then
          run moon test moui/backend/linux/wgpu --target native
        fi
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding selected current-platform Skia native example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/showcase/linux_skia --target native
        run moon build examples/markdown_editor/linux_skia --target native
        if "$RUN_WGPU_EXPERIMENTAL"; then
          run moon build examples/showcase/linux_wgpu --target native
          run moon build examples/showcase/linux_wgpu_cosmic --target native
        fi
      fi
      ;;
    *)
      printf '\nSkipping platform checks for unsupported host: %s\n' "$(uname -s)"
      ;;
  esac
else
  printf '\nSkipping native platform checks. Pass --platform-examples-test for backend tests or --platform-examples-build for slow example builds.\n'
fi

if "$RUN_SKIA_REAL_SMOKE"; then
  run moon -C moui_skia/scripts/native_smoke build --target native
  run_built_executable "./moui_skia/scripts/native_smoke/_build/native/debug/build/moui_skia_native_smoke.exe"
  run moon build moui/tests/skia_renderer_smoke/native --target native
  run_built_executable "./_build/native/debug/build/wzzc-dev/moui/tests/skia_renderer_smoke/native/native.exe"
else
  printf '\nSkipping real Skia smoke. Pass --skia-real-smoke when local Skia link flags are configured.\n'
fi

printf '\nDaily development checks passed.\n'
