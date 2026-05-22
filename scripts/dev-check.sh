#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_PLATFORM_EXAMPLES_TEST=false
RUN_PLATFORM_EXAMPLES_BUILD=false

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
    --help|-h)
      printf 'Usage: %s [--platform-examples-test] [--platform-examples-build]\n' "$0"
      printf '\n'
      printf 'Runs bounded package-level checks and Web wasm-gc example builds.\n'
      printf 'Pass --platform-examples-test to also run current-platform backend tests.\n'
      printf 'Pass --platform-examples-build to also build current-platform native examples.\n'
      printf 'Native example builds link platform stubs and wgpu-native, so cold builds can be slow.\n'
      printf 'Deprecated alias: --platform-examples behaves like --platform-examples-test.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--platform-examples-test] [--platform-examples-build]\n' "$0" >&2
      exit 2
      ;;
  esac
done

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

run sh scripts/check-local-deps.sh

run moon check

run moon test core --target native
run moon test views --target native
run moon test render --target native
run moon test render/wgpu --target native
run moon test backend/host --target native

run moon test render/webgpu_adapter --target wasm-gc
run moon test backend/web --target wasm-gc

run moon test examples/showcase/app --target native
run moon test examples/markdown_editor/app --target native

run moon build examples/showcase/web_wasm --target wasm-gc
run moon build examples/markdown_editor/web_wasm --target wasm-gc

if "$RUN_PLATFORM_EXAMPLES_TEST" || "$RUN_PLATFORM_EXAMPLES_BUILD"; then
  case "$(uname -s)" in
    Darwin)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test backend/macos --target native
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding native platform example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/showcase/macos --target native
        run moon build examples/markdown_editor/macos --target native
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test backend/windows --target native
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nIncluding native platform example builds. These builds may be slow on a cold cache.\n'
        run moon build examples/markdown_editor/windows --target native
      fi
      ;;
    Linux)
      if "$RUN_PLATFORM_EXAMPLES_TEST"; then
        run moon test backend/linux --target native
      fi
      if "$RUN_PLATFORM_EXAMPLES_BUILD"; then
        printf '\nNo native example builds are configured for Linux yet.\n'
      fi
      ;;
    *)
      printf '\nSkipping platform checks for unsupported host: %s\n' "$(uname -s)"
      ;;
  esac
else
  printf '\nSkipping native platform checks. Pass --platform-examples-test for backend tests or --platform-examples-build for slow example builds.\n'
fi

printf '\nDaily development checks passed.\n'
