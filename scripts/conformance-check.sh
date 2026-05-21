#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_GOLDEN=false
RUN_BENCH=false
RUN_PLATFORM=false

usage() {
  printf 'Usage: %s [--golden] [--bench] [--platform]\n' "$0"
  printf '\n'
  printf 'Runs MoUI conformance-oriented package checks. Optional modes add screenshot golden scaffolds, performance smoke builds, or current-platform backend checks.\n'
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

run moon test core --target native
run moon test backend/host --target native
run moon test render --target native
run moon test render/webgpu_adapter --target wasm-gc
run moon test backend/web --target wasm-gc
run moon test examples/showcase/app --target native

if "$RUN_GOLDEN"; then
  run moon build examples/showcase/web_wasm --target wasm-gc
  printf '\nGolden scaffold complete. Capture browser screenshots from examples/showcase/web_wasm and compare against approved artifacts when a screenshot runner is configured.\n'
fi

if "$RUN_BENCH"; then
  run moon build examples/showcase/web_wasm --target wasm-gc
  run moon build examples/markdown_editor/web_wasm --target wasm-gc
  printf '\nBenchmark scaffold complete. Record startup, frame time, dirty-count, draw-command count, and memory from the built examples.\n'
fi

if "$RUN_PLATFORM"; then
  run sh scripts/dev-check.sh --platform-examples-test
fi

printf '\nConformance checks passed.\n'
