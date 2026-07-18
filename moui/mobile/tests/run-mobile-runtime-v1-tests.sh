#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
moon_home="${MOON_HOME:-$HOME/.moon}"
cc="${CC:-clang}"
cxx="${CXX:-clang++}"

header_dir="$repo_root/moui/mobile/include"
adapter_source="$repo_root/moui/mobile/runtime/moui_mobile_runtime_v1.cpp"
header_test_source="$script_dir/mobile_runtime_v1_header_test.c"
test_source="$script_dir/mobile_runtime_v1_test.cpp"
runtime_source="$moon_home/lib/runtime.c"
moonbit_include="$moon_home/include"

if [[ ! -f "$runtime_source" || ! -f "$moonbit_include/moonbit.h" ]]; then
  echo "MoonBit native runtime not found under $moon_home; set MOON_HOME." >&2
  exit 1
fi
if ! command -v "$cc" >/dev/null 2>&1; then
  echo "C compiler not found: $cc" >&2
  exit 1
fi
if ! command -v "$cxx" >/dev/null 2>&1; then
  echo "C++ compiler not found: $cxx" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-mobile-runtime-v1.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

sanitize_flags=(-fno-omit-frame-pointer)
asan_enabled=0
if [[ "${MOUI_MOBILE_RUNTIME_ASAN:-1}" != "0" ]]; then
  sanitize_flags=(-fsanitize=address -fno-omit-frame-pointer)
  asan_enabled=1
fi

common_c_flags=(-O1 -g -I"$moonbit_include")
common_cxx_flags=(
  -std=c++17
  -O1
  -g
  -Wall
  -Wextra
  -Werror
  -fvisibility=hidden
  -I"$header_dir"
  -I"$moonbit_include"
)

"$cc" \
  -std=c11 \
  -Wall \
  -Wextra \
  -Werror \
  -pedantic \
  -I"$header_dir" \
  -c "$header_test_source" \
  -o "$tmp_dir/header-test.o"

"$cc" \
  "${common_c_flags[@]}" \
  "${sanitize_flags[@]}" \
  -c "$runtime_source" \
  -o "$tmp_dir/runtime.o"

"$cxx" \
  "${common_cxx_flags[@]}" \
  "${sanitize_flags[@]}" \
  -c "$adapter_source" \
  -o "$tmp_dir/adapter-default-symbols.o"

nm -u "$tmp_dir/adapter-default-symbols.o" \
  >"$tmp_dir/nm-adapter-default-symbols.txt"
default_app_symbols=(
  moui_mobile_attach_surface
  moui_mobile_resize
  moui_mobile_dispatch_pointer
  moui_mobile_dispatch_scroll
  moui_mobile_frame_tick
  moui_mobile_render_frame
  moui_mobile_detach_surface
  moui_mobile_destroy_application
  moui_mobile_renderer_configure
  moui_mobile_renderer_status_json
  moui_mobile_take_host_update_envelope_json
  moui_mobile_dispatch_host_response_envelope_json
  moui_mobile_dispatch_text_input
  moui_mobile_dispatch_command
  moui_mobile_dispatch_accessibility
  moui_mobile_complete_clipboard_v1
)
for symbol in "${default_app_symbols[@]}"; do
  if ! grep -Eq "(^|[[:space:]])_?${symbol}($|[[:space:]])" \
      "$tmp_dir/nm-adapter-default-symbols.txt"; then
    echo "default ABI adapter does not reference fixed app symbol: $symbol" >&2
    exit 1
  fi
done

adapter_defines=(
  -DMOUI_MOBILE_RUNTIME_INIT=mock_runtime_init
  -DMOUI_MOBILE_RUNTIME_APP_INIT=mock_app_init
  -DMOUI_MOBILE_RUNTIME_ATTACH_SURFACE=mock_attach_surface
  -DMOUI_MOBILE_RUNTIME_RESIZE=mock_resize
  -DMOUI_MOBILE_RUNTIME_DISPATCH_POINTER=mock_dispatch_pointer
  -DMOUI_MOBILE_RUNTIME_FRAME_TICK=mock_frame_tick
  -DMOUI_MOBILE_RUNTIME_RENDER_FRAME=mock_render_frame
  -DMOUI_MOBILE_RUNTIME_DETACH_SURFACE=mock_detach_surface
  -DMOUI_MOBILE_RUNTIME_DESTROY_APPLICATION=mock_destroy_application
  -DMOUI_MOBILE_RUNTIME_RENDERER_CONFIGURE=mock_renderer_configure
  -DMOUI_MOBILE_RUNTIME_RENDERER_STATUS_JSON=mock_renderer_status_json
  -DMOUI_MOBILE_RUNTIME_TAKE_HOST_UPDATE_ENVELOPE_JSON=mock_take_host_updates_json
  -DMOUI_MOBILE_RUNTIME_DISPATCH_HOST_RESPONSE_ENVELOPE=mock_dispatch_host_response_envelope
  -DMOUI_MOBILE_RUNTIME_DISPATCH_TEXT_INPUT=mock_dispatch_text_input
  -DMOUI_MOBILE_RUNTIME_DISPATCH_COMMAND=mock_dispatch_command
  -DMOUI_MOBILE_RUNTIME_DISPATCH_ACCESSIBILITY=mock_dispatch_accessibility
  -DMOUI_MOBILE_RUNTIME_COMPLETE_CLIPBOARD=mock_complete_clipboard
  -DMOUI_MOBILE_RUNTIME_DECREF=test_moonbit_decref
)

run_variant() {
  local variant="$1"
  local scroll_enabled="$2"
  local adapter_object="$tmp_dir/adapter-$variant.o"
  local test_object="$tmp_dir/test-$variant.o"
  local executable="$tmp_dir/mobile-runtime-v1-$variant"
  local variant_defines=(-DMOUI_MOBILE_RUNTIME_ENABLE_SCROLL="$scroll_enabled")

  if [[ "$scroll_enabled" == "1" ]]; then
    variant_defines+=(
      -DMOUI_MOBILE_RUNTIME_DISPATCH_SCROLL=mock_dispatch_scroll
    )
  fi

  "$cxx" \
    "${common_cxx_flags[@]}" \
    "${sanitize_flags[@]}" \
    "${adapter_defines[@]}" \
    "${variant_defines[@]}" \
    -c "$adapter_source" \
    -o "$adapter_object"

  "$cxx" \
    "${common_cxx_flags[@]}" \
    "${sanitize_flags[@]}" \
    "${variant_defines[@]}" \
    -c "$test_source" \
    -o "$test_object"

  "$cxx" \
    "${sanitize_flags[@]}" \
    "$adapter_object" \
    "$test_object" \
    "$tmp_dir/runtime.o" \
    -pthread \
    -o "$executable"

  nm -g "$adapter_object" >"$tmp_dir/nm-adapter-$variant.txt"
  if ! grep -Eq '[[:space:]][Tt][[:space:]]_?moui_mobile_get_runtime_api_v1$' \
      "$tmp_dir/nm-adapter-$variant.txt"; then
    echo "ABI getter is not a defined global symbol for $variant." >&2
    sed -n '1,120p' "$tmp_dir/nm-adapter-$variant.txt" >&2
    exit 1
  fi

  if [[ "$asan_enabled" == "1" ]]; then
    ASAN_OPTIONS="detect_leaks=0:halt_on_error=1" "$executable"
  else
    "$executable"
  fi
}

if grep -Eq 'moonbit_(string|bytes)_t' \
    "$header_dir/moui_mobile_runtime_v1.h"; then
  echo "Published ABI header leaks MoonBit object types." >&2
  exit 1
fi

run_variant no-scroll 0
run_variant scroll 1

if [[ "$asan_enabled" == "1" ]]; then
  echo "mobile runtime ABI v1 header, capability, ownership, ASan, and symbol audits passed"
else
  echo "mobile runtime ABI v1 header, capability, ownership, and symbol audits passed (ASan disabled)"
fi
