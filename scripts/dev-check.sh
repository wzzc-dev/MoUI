#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_PLATFORM_EXAMPLES=false

for arg in "$@"; do
  case "$arg" in
    --platform-examples)
      RUN_PLATFORM_EXAMPLES=true
      ;;
    --help|-h)
      printf 'Usage: %s [--platform-examples]\n' "$0"
      printf '\n'
      printf 'Runs bounded package-level checks and Web wasm-gc example builds.\n'
      printf 'Pass --platform-examples to also build current-platform native examples.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--platform-examples]\n' "$0" >&2
      exit 2
      ;;
  esac
done

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

run moon check

run moon test core --target native
run moon test views --target native
run moon test render --target native
run moon test backend/host --target native

run moon test render/webgpu --target wasm-gc
run moon test backend/web --target wasm-gc

run moon test examples/counter/app --target native
run moon test examples/todo/app --target native
run moon test examples/showcase/app --target native
run moon test examples/markdown_editor/app --target native

run moon build examples/counter/web_wasm --target wasm-gc
run moon build examples/todo/web_wasm --target wasm-gc
run moon build examples/showcase/web_wasm --target wasm-gc
run moon build examples/markdown_editor/web_wasm --target wasm-gc

if "$RUN_PLATFORM_EXAMPLES"; then
  case "$(uname -s)" in
    Darwin)
      run moon test backend/macos --target native
      run moon build examples/counter/macos --target native
      run moon build examples/todo/macos --target native
      run moon build examples/showcase/macos --target native
      run moon build examples/markdown_editor/macos --target native
      ;;
    MINGW*|MSYS*|CYGWIN*)
      run moon test backend/windows --target native
      run moon build examples/counter/windows --target native
      run moon build examples/todo/windows --target native
      run moon build examples/markdown_editor/windows --target native
      ;;
    Linux)
      run moon test backend/linux --target native
      ;;
    *)
      printf '\nSkipping platform example builds for unsupported host: %s\n' "$(uname -s)"
      ;;
  esac
else
  printf '\nSkipping native platform example builds. Pass --platform-examples to include them.\n'
fi

printf '\nDaily development checks passed.\n'
