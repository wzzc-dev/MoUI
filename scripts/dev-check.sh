#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_PLATFORM_EXAMPLES_TEST=false
RUN_PLATFORM_EXAMPLES_BUILD=false
RUN_SKIA_REAL_SMOKE=false

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
    --help|-h)
      printf 'Usage: %s [--platform-examples-test] [--platform-examples-build] [--skia-real-smoke]\n' "$0"
      printf '\n'
      printf 'Runs bounded package-level checks and Web wasm-gc example builds.\n'
      printf 'Pass --platform-examples-test to also run current-platform backend tests.\n'
      printf 'Pass --platform-examples-build to also build current-platform native examples.\n'
      printf 'Pass --skia-real-smoke to run the opt-in real Skia smoke when local Skia link flags are configured.\n'
      printf 'On macOS, scripts/macos-skia-renderer-smoke.sh can resolve JetBrains/source/existing Skia providers and temporarily configure those flags.\n'
      printf 'Native example builds link platform stubs and wgpu-native, so cold builds can be slow.\n'
      printf 'Deprecated alias: --platform-examples behaves like --platform-examples-test.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--platform-examples-test] [--platform-examples-build] [--skia-real-smoke]\n' "$0" >&2
      exit 2
      ;;
  esac
done

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
run node scripts/validate-renderer-provider-manifests.mjs

run moon check

run moon test moui/core --target native
run moon test moui/views --target native
run moon test moui/render --target native
run moon test moui/render/wgpu --target native
run moon test moui/render/skia --target native
run moon test moui/backend/host --target native

run moon test .local_repos/skia_mbt --target native

run moon test moui/render/webgpu_adapter --target wasm-gc
run moon test moui/backend/web --target wasm-gc

run moon test examples/showcase/app --target native
run moon test examples/markdown_editor/app --target native

run moon build examples/showcase/web_wasm --target wasm-gc
run moon build examples/markdown_editor/web_wasm --target wasm-gc

if "$RUN_PLATFORM_EXAMPLES_TEST" || "$RUN_PLATFORM_EXAMPLES_BUILD"; then
  case "$(uname -s)" in
    Darwin)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test moui/backend/macos --target native
        run moon test moui/backend/macos/wgpu --target native
        run moon test moui/backend/macos/skia --target native
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding native platform example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/showcase/macos --target native
        run moon build examples/showcase/macos_skia --target native
        run moon build examples/markdown_editor/macos --target native
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test moui/backend/windows --target native
        run moon test moui/backend/windows/wgpu --target native
        run moon test moui/backend/windows/skia --target native
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding native platform example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/markdown_editor/windows --target native
      fi
      ;;
    Linux)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test moui/backend/linux --target native
        run moon test moui/backend/linux/wgpu --target native
        run moon test moui/backend/linux/skia --target native
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding native platform example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/showcase/linux --target native
        run moon build examples/showcase/linux_cosmic --target native
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
  run moon build .local_repos/skia_mbt/scripts/native_smoke --target native
  run_built_executable "./.local_repos/skia_mbt/scripts/native_smoke/_build/native/debug/build/skia_mbt_native_smoke.exe"
  run moon build moui/tests/skia_renderer_smoke/native --target native
  run_built_executable "./_build/native/debug/build/wzzc-dev/moui/tests/skia_renderer_smoke/native/native.exe"
else
  printf '\nSkipping real Skia smoke. Pass --skia-real-smoke when local Skia link flags are configured.\n'
fi

printf '\nDaily development checks passed.\n'
