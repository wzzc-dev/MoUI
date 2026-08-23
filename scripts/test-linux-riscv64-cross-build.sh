#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_root/scripts/linux-riscv64-cross-build.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/moui-riscv64-helper-test.XXXXXX")"
cleanup() {
  rm -rf -- "$fixture"
}
trap cleanup EXIT

bin_dir="$fixture/bin"
sysroot="$fixture/sysroot"
log_dir="$fixture/logs"
mkdir -p \
  "$bin_dir" \
  "$log_dir" \
  "$sysroot/lib" \
  "$sysroot/usr/include/glib-2.0" \
  "$sysroot/usr/include/fontconfig" \
  "$sysroot/usr/include/freetype2" \
  "$sysroot/usr/include/harfbuzz" \
  "$sysroot/usr/lib/riscv64-linux-gnu/pkgconfig" \
  "$sysroot/usr/share/wayland-protocols"

touch \
  "$sysroot/lib/ld-linux-riscv64-lp64d.so.1" \
  "$sysroot/usr/include/wayland-client.h" \
  "$sysroot/usr/include/glib-2.0/glib.h" \
  "$sysroot/usr/include/fontconfig/fontconfig.h" \
  "$sysroot/usr/include/freetype2/ft2build.h" \
  "$sysroot/usr/include/harfbuzz/hb.h"
for library in gio-2.0 glib-2.0 wayland-client fontconfig freetype harfbuzz z stdc++; do
  touch "$sysroot/usr/lib/riscv64-linux-gnu/lib${library}.so.0"
  ln -s "lib${library}.so.0" "$sysroot/usr/lib/riscv64-linux-gnu/lib${library}.so"
done

cat > "$bin_dir/zig" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "0.16.0"
  exit 0
fi
exit 0
EOF

cat > "$bin_dir/file" <<'EOF'
#!/usr/bin/env bash
echo "${*: -1}: ELF 64-bit LSB shared object, UCB RISC-V"
EOF

cat > "$bin_dir/readelf" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -h)
    echo "  Class:                             ELF64"
    echo "  Machine:                           ${FAKE_READELF_MACHINE:-RISC-V}"
    echo "  Flags:                             ${FAKE_READELF_FLAGS:-0x5, RVC, double-float ABI}"
    ;;
  -l)
    echo "      [Requesting program interpreter: /lib/ld-linux-riscv64-lp64d.so.1]"
    ;;
  -d) ;;
esac
EOF

cat > "$bin_dir/pkg-config" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --exists)
    [[ "${2:-}" != "${FAKE_PKG_MISSING:-}" ]]
    ;;
  --variable=pkgdatadir)
    echo "$PKG_CONFIG_SYSROOT_DIR/usr/share/wayland-protocols"
    ;;
  --cflags)
    echo "-I$PKG_CONFIG_SYSROOT_DIR/usr/include"
    ;;
  --libs)
    echo "-L$PKG_CONFIG_SYSROOT_DIR/usr/lib/riscv64-linux-gnu -lfixture"
    ;;
  *)
    echo "unsupported fake pkg-config invocation: $*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$bin_dir/zig" "$bin_dir/file" "$bin_dir/readelf" "$bin_dir/pkg-config"

common_env=(
  "PATH=$bin_dir:$PATH"
  "ZIG=$bin_dir/zig"
  "FILE=$bin_dir/file"
  "READELF=$bin_dir/readelf"
  "PKG_CONFIG=$bin_dir/pkg-config"
)
common_args=(
  "$helper"
  --sysroot "$sysroot"
  --lock "$repo_root/checks/toolchains/linux-riscv64.json"
  --log-dir "$log_dir"
  --dry-run
)

expect_failure() {
  local label="$1"
  local expected="$2"
  shift 2
  local output="$fixture/$label.log"
  if "$@" >"$output" 2>&1; then
    echo "$label unexpectedly succeeded" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    echo "$label did not report the expected diagnostic: $expected" >&2
    cat "$output" >&2
    exit 1
  fi
}

env "${common_env[@]}" bash "${common_args[@]}" >/dev/null

expect_failure non-riscv-sysroot \
  "sysroot loader is not an ELF64 RISC-V LP64D glibc loader" \
  env "${common_env[@]}" FAKE_READELF_MACHINE=X86-64 bash "${common_args[@]}"

expect_failure wrong-lp64d-sysroot \
  "sysroot loader is not an ELF64 RISC-V LP64D glibc loader" \
  env "${common_env[@]}" FAKE_READELF_FLAGS="0x1, RVC, soft-float ABI" bash "${common_args[@]}"

expect_failure missing-wayland-pc \
  "target pkg-config package is missing: wayland-client" \
  env "${common_env[@]}" FAKE_PKG_MISSING=wayland-client bash "${common_args[@]}"

bad_lock="$fixture/bad-abi.json"
sed 's/"abi": "gnu"/"abi": "musl"/' \
  "$repo_root/checks/toolchains/linux-riscv64.json" > "$bad_lock"
expect_failure wrong-abi \
  "toolchain lock is not riscv64-linux-gnu" \
  env "${common_env[@]}" bash "$helper" --sysroot "$sysroot" --lock "$bad_lock" --dry-run

expect_failure vulkan-enabled \
  "MOUI_SKIA_ENABLE_GPU_VULKAN must be disabled" \
  env "${common_env[@]}" MOUI_SKIA_ENABLE_GPU_VULKAN=1 bash "${common_args[@]}"

# Include-order contract: the GCC installation include dir must be injected
# before the libstdc++ dirs. glibc (Ubuntu noble) no longer ships
# <stdatomic.h>, so the libgcc-13-dev header directory is the only C-mode
# provider; native clang auto-detects it, the zig cc wrapper must add it.
gcc_include_line="$(grep -n 'isystem.*usr/lib/gcc/riscv64-linux-gnu' "$helper" | head -1 | cut -d: -f1)"
cxx_include_line="$(grep -n 'isystem.*usr/include/c++' "$helper" | head -1 | cut -d: -f1)"
if [[ -z "$gcc_include_line" || -z "$cxx_include_line" ]]; then
  echo "cross-build wrapper is missing the sysroot include layout injections" >&2
  exit 1
fi
if (( gcc_include_line >= cxx_include_line )); then
  echo "cross-build wrapper must inject the GCC include dir before libstdc++ headers" >&2
  exit 1
fi

echo "Linux RISC-V64 cross-build helper self-test passed"
