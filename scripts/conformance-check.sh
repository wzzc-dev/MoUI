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

if "$RUN_DEFAULT"; then
  run moon test core --target native
  run moon test backend/host --target native
  run moon test render --target native
  run moon test render/webgpu_adapter --target wasm-gc
  run moon test backend/web --target wasm-gc
  run moon test examples/showcase/app --target native
fi

if "$RUN_INPUT"; then
  run moon test core --target native
  run moon test backend/host --target native
fi

if "$RUN_LAYOUT"; then
  run moon test core --target native
fi

if "$RUN_RENDER"; then
  run moon test render --target native
  run moon test render/wgpu --target native
  run moon test render/webgpu_adapter --target wasm-gc
fi

if "$RUN_PLATFORM_SERVICES"; then
  run moon test backend/host --target native
  run moon test backend/web --target wasm-gc
  if [ -f ".local_repos/window/linux/generated/xdg-decoration-protocol.c" ]; then
    run moon test backend/linux --target native
  else
    printf '\nSkipping backend/linux platform-service tests because .local_repos/window/linux/generated/xdg-decoration-protocol.c is missing.\n'
  fi
  if [ "$(uname -s)" = "Darwin" ]; then
    run moon test backend/macos --target native
  fi
fi

if "$RUN_TEXT"; then
  run moon test core --target native
  run moon test render/wgpu --target native
  run moon test render/webgpu_adapter --target wasm-gc
  run moon test backend/web --target wasm-gc
fi

if "$RUN_TEXT_DIAGNOSTIC"; then
  run moon test tests/text_conformance/native --target native
  run moon test tests/text_conformance/web --target wasm-gc
fi

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
