#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/linux-riscv64-cross-build.sh --sysroot PATH [options]

Cross-build the canonical Linux Skia Showcase and run the offscreen Skia
renderer/text smokes for riscv64-linux-gnu. The helper never rewrites tracked
MoonBit package files.

Options:
  --sysroot PATH       Ubuntu/glibc RISC-V64 sysroot (required).
  --target-dir PATH    Isolated Moon target directory.
                       Default: _build/riscv64-linux-gnu.
  --log-dir PATH       Logs and ELF reports. Default: artifacts/linux-riscv64.
  --run-qemu           Execute renderer/text smokes through QEMU.
  --dry-run            Resolve and validate the cross configuration only.
  --lock PATH          Toolchain lock. Default: checks/toolchains/linux-riscv64.json.
  -h, --help           Show this help.

Required host tools: zig, moon, node, python3, pkg-config, file, readelf or
llvm-readelf.
QEMU is required only with --run-qemu.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sysroot=""
target_dir="$repo_root/_build/riscv64-linux-gnu"
log_dir="$repo_root/artifacts/linux-riscv64"
lock="$repo_root/checks/toolchains/linux-riscv64.json"
run_qemu=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sysroot) sysroot="${2:-}"; shift 2 ;;
    --target-dir) target_dir="${2:-}"; shift 2 ;;
    --log-dir) log_dir="${2:-}"; shift 2 ;;
    --run-qemu) run_qemu=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --lock) lock="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$sysroot" ]]; then
  echo "--sysroot is required" >&2
  usage >&2
  exit 2
fi
case "$sysroot" in
  /*) ;;
  *) sysroot="$repo_root/$sysroot" ;;
esac
case "$target_dir" in
  /*) ;;
  *) target_dir="$repo_root/$target_dir" ;;
esac
case "$log_dir" in
  /*) ;;
  *) log_dir="$repo_root/$log_dir" ;;
esac
case "$lock" in
  /*) ;;
  *) lock="$repo_root/$lock" ;;
esac

if [[ ! -d "$sysroot" ]]; then
  echo "sysroot does not exist: $sysroot" >&2
  exit 1
fi
if [[ ! -f "$lock" ]]; then
  echo "toolchain lock does not exist: $lock" >&2
  exit 1
fi

reject_non_raster_environment() {
  local name="$1"
  local expected="$2"
  local value="${!name-}"
  if [[ -n "${!name+x}" && "$value" != "$expected" ]]; then
    echo "$name must be $expected for the RISC-V64 raster route (got: $value)" >&2
    exit 2
  fi
}

reject_non_raster_environment MOUI_SKIA_PLATFORM linux
reject_non_raster_environment MOUI_SKIA_ARCH riscv64
reject_non_raster_environment MOUI_SKIA_CONFIG Release
reject_non_raster_environment MOUI_SKIA_LINK_MODE static
reject_non_raster_environment MOUI_SKIA_RENDERER skia-raster
for provider_name in MOUI_SKIA_PROVIDER MOUI_SKIA_SKIA_PROVIDER; do
  reject_non_raster_environment "$provider_name" release
done
for paragraph_name in MOUI_SKIA_ENABLE_SKPARAGRAPH MOUI_SKIA_REQUIRE_SKPARAGRAPH; do
  if [[ -n "${!paragraph_name+x}" ]]; then
    case "${!paragraph_name}" in
      1|true|TRUE|yes|YES|on|ON) ;;
      *)
        echo "$paragraph_name must be enabled for the RISC-V64 text smoke" >&2
        exit 2
        ;;
    esac
  fi
done
if [[ -n "${MOUI_SKIA_ENABLE_GPU_VULKAN+x}" ]]; then
  case "${MOUI_SKIA_ENABLE_GPU_VULKAN}" in
    0|false|FALSE|no|NO|off|OFF) ;;
    *)
      echo "MOUI_SKIA_ENABLE_GPU_VULKAN must be disabled for the RISC-V64 raster route" >&2
      exit 2
      ;;
  esac
fi

lock_value() {
  node - "$lock" "$1" <<'NODE'
const fs = require("node:fs");
const [lockPath, key] = process.argv.slice(2);
const value = JSON.parse(fs.readFileSync(lockPath, "utf8"))[key];
if (value !== undefined) console.log(String(value));
NODE
}

zig_version="$(lock_value zigVersion)"
if [[ "$(lock_value architecture)" != "riscv64" ||
  "$(lock_value abi)" != "gnu" ||
  "$(lock_value targetTriple)" != "riscv64-linux-gnu" ||
  "$(lock_value glibcAbi)" != "lp64d" ]]; then
  echo "toolchain lock is not riscv64-linux-gnu: $lock" >&2
  exit 1
fi

for tool in node python3 moon pkg-config file; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "required host tool is missing: $tool" >&2
    exit 1
  }
done
zig_bin="${ZIG:-$(command -v zig || true)}"
if [[ -z "$zig_bin" || ! -x "$zig_bin" ]]; then
  echo "zig is required; install the locked Zig $zig_version first" >&2
  exit 1
fi
if [[ "$("$zig_bin" version)" != "$zig_version" ]]; then
  echo "Zig version mismatch: expected $zig_version, got $("$zig_bin" version)" >&2
  exit 1
fi

if [[ -n "${READELF:-}" ]]; then
  readelf_bin="$READELF"
elif command -v readelf >/dev/null 2>&1; then
  readelf_bin="$(command -v readelf)"
elif command -v llvm-readelf >/dev/null 2>&1; then
  readelf_bin="$(command -v llvm-readelf)"
else
  echo "readelf or llvm-readelf is required for ELF architecture verification" >&2
  exit 1
fi
file_bin="${FILE:-$(command -v file || true)}"
if [[ -z "$file_bin" || ! -x "$file_bin" ]]; then
  echo "file is required for ELF architecture verification" >&2
  exit 1
fi

loader=""
for candidate in \
  "$sysroot/lib/ld-linux-riscv64-lp64d.so.1" \
  "$sysroot/lib/riscv64-linux-gnu/ld-linux-riscv64-lp64d.so.1" \
  "$sysroot/lib64/ld-linux-riscv64-lp64d.so.1" \
  "$sysroot/usr/lib/riscv64-linux-gnu/ld-linux-riscv64-lp64d.so.1"; do
  if [[ -e "$candidate" ]]; then
    loader="$candidate"
    break
  fi
done
if [[ -z "$loader" ]]; then
  echo "RISC-V64 glibc loader is missing from sysroot: $sysroot" >&2
  exit 1
fi

required_headers=(
  "$sysroot/usr/include/wayland-client.h"
  "$sysroot/usr/include/glib-2.0/glib.h"
  "$sysroot/usr/include/fontconfig/fontconfig.h"
  "$sysroot/usr/include/freetype2/ft2build.h"
  "$sysroot/usr/include/harfbuzz/hb.h"
)
for header in "${required_headers[@]}"; do
  [[ -f "$header" ]] || {
    echo "required target header is missing: $header" >&2
    exit 1
  }
done

loader_file_report="$("$file_bin" -L "$loader")"
loader_header_report="$("$readelf_bin" -h "$loader")"
if ! grep -Eq 'ELF 64-bit' <<<"$loader_file_report" ||
  ! grep -Eq 'Class:[[:space:]]+ELF64' <<<"$loader_header_report" ||
  ! grep -Eq 'Machine:[[:space:]]+RISC-V' <<<"$loader_header_report" ||
  ! grep -Eq 'Flags:.*double-float ABI' <<<"$loader_header_report"; then
  echo "sysroot loader is not an ELF64 RISC-V LP64D glibc loader: $loader" >&2
  exit 1
fi

pkg_config_libdir="$sysroot/usr/lib/riscv64-linux-gnu/pkgconfig:$sysroot/usr/share/pkgconfig:$sysroot/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$sysroot"
export PKG_CONFIG_LIBDIR="$pkg_config_libdir"
export PKG_CONFIG_PATH=""
pkg_config="${PKG_CONFIG:-pkg-config}"
if [[ "$pkg_config" == */* && ! -x "$pkg_config" ]]; then
  echo "pkg-config helper is not executable: $pkg_config" >&2
  exit 1
fi

pkg_flags() {
  "$pkg_config" "$@"
}

for package in glib-2.0 wayland-client fontconfig freetype2 harfbuzz; do
  if ! pkg_flags --exists "$package"; then
    echo "target pkg-config package is missing: $package" >&2
    echo "  PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR" >&2
    exit 1
  fi
done
protocol_dir="$(pkg_flags --variable=pkgdatadir wayland-protocols 2>/dev/null || true)"
if [[ "$protocol_dir" == /* && "$protocol_dir" != "$sysroot"/* ]]; then
  protocol_dir="$sysroot$protocol_dir"
fi
if [[ -z "$protocol_dir" || ! -d "$protocol_dir" ]]; then
  echo "target wayland-protocols pkgdatadir is missing: $protocol_dir" >&2
  exit 1
fi

glib_stub_flags="$(pkg_flags --cflags glib-2.0)"
glib_link_flags="$(pkg_flags --libs glib-2.0)"
native_stub_flags="$(pkg_flags --cflags fontconfig freetype2 harfbuzz wayland-client)"
native_link_flags="$(pkg_flags --libs fontconfig freetype2 harfbuzz wayland-client)"
if [[ -z "$glib_stub_flags" || -z "$glib_link_flags" || -z "$native_link_flags" ]]; then
  echo "target pkg-config did not resolve required compile/link flags" >&2
  exit 1
fi

require_target_library() {
  local name="$1"
  local found=""
  for root in \
    "$sysroot/lib/riscv64-linux-gnu" \
    "$sysroot/usr/lib/riscv64-linux-gnu" \
    "$sysroot/usr/lib"; do
    if [[ -d "$root" ]]; then
      found="$(find "$root" -maxdepth 1 \( -type f -o -type l \) \( -name "lib${name}.so*" -o -name "lib${name}.a" \) -print -quit 2>/dev/null || true)"
      [[ -n "$found" ]] && break
    fi
  done
  if [[ -z "$found" ]]; then
    echo "required target library is missing: lib${name}" >&2
    exit 1
  fi
}

for library in glib-2.0 wayland-client fontconfig freetype harfbuzz z stdc++; do
  require_target_library "$library"
done

mkdir -p "$log_dir"
for manifest in .moui-riscv64-sysroot .moui-riscv64-packages .moui-riscv64-files.sha256; do
  if [[ -f "$sysroot/$manifest" ]]; then
    cp "$sysroot/$manifest" "$log_dir/$manifest"
  fi
done
config_log="$log_dir/cross-build-config.log"
{
  echo "sysroot=$sysroot"
  echo "target_dir=$target_dir"
  echo "log_dir=$log_dir"
  echo "zig=$zig_bin"
  echo "zig_version=$zig_version"
  echo "readelf=$readelf_bin"
  echo "file=$file_bin"
  echo "loader=$loader"
  echo "PKG_CONFIG_SYSROOT_DIR=$PKG_CONFIG_SYSROOT_DIR"
  echo "PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR"
  echo "glib_stub_flags=$glib_stub_flags"
  echo "glib_link_flags=$glib_link_flags"
  echo "native_stub_flags=$native_stub_flags"
  echo "native_link_flags=$native_link_flags"
  echo "MOUI_SKIA_PLATFORM=linux"
  echo "MOUI_SKIA_ARCH=riscv64"
  echo "MOUI_SKIA_CONFIG=Release"
  echo "MOUI_SKIA_LINK_MODE=static"
  echo "MOUI_SKIA_ENABLE_GPU_VULKAN=0"
  echo "MOUI_SKIA_REQUIRE_SKPARAGRAPH=1"
  echo "MOUI_SKIA_RENDERER=skia-raster"
} | tee "$config_log"

if [[ $dry_run -eq 1 ]]; then
  echo "cross-build dry run: configuration is valid"
  exit 0
fi

wrapper_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-riscv64-wrappers.XXXXXX")"
cleanup() {
  rm -rf "$wrapper_dir"
}
trap cleanup EXIT

# Align the zig target glibc version with the sysroot (libstdc++ headers
# require glibc >= 2.32 features) and resolve the libstdc++ include layout.
glibc_major="$(awk '/^#define __GLIBC__/ { print $3; exit }' \
  "$sysroot/usr/include/features.h" 2>/dev/null)"
glibc_minor="$(awk '/^#define __GLIBC_MINOR__/ { print $3; exit }' \
  "$sysroot/usr/include/features.h" 2>/dev/null)"
: "${glibc_major:=2}"
: "${glibc_minor:=39}"
cxx_ver="$(ls "$sysroot/usr/include/c++/" 2>/dev/null | head -1)"
: "${cxx_ver:=13}"
target_triple="riscv64-linux-gnu.${glibc_major}.${glibc_minor}"

cat > "$wrapper_dir/moui-riscv64-cc" <<EOF
#!/usr/bin/env bash
set -euo pipefail
sysroot="$sysroot"
target_triple="$target_triple"
cxx_ver="$cxx_ver"
has_c=0
has_o=0
args=()
for arg in "\$@"; do
  case "\$arg" in
    "-c") has_c=1; args+=("\$arg") ;;
    "-o") has_o=1; args+=("\$arg") ;;
    "-DMOONBIT_ALLOW_STACKTRACE"|"-DMOONBIT_USE_SIMDUTF")
      # moon compiles its runtime with stacktrace/simdutf enabled and then
      # links host-prebuilt objects (~/.moon/lib) that are not available for
      # the riscv64 target. Drop the macros so the runtime neither references
      # them nor extracts the incompatible host archives.
      continue
      ;;
    "-lstdc++"|"-lc++")
      # moui_skia/build.js appends -lstdc++ for Linux; zig would recognize
      # it as a request for its bundled libc++ and mix two incompatible
      # C++ runtimes into the link. The sysroot libstdc++.so is provided
      # explicitly on link invocations instead.
      continue
      ;;
    "-L\$sysroot"/*)
      # zig cc prefixes every absolute -L with --sysroot; strip the
      # already-prefixed sysroot path so zig rebuilds the correct one.
      args+=("-L/\${arg#-L\$sysroot/}")
      ;;
    -L/*)
      # Host-absolute library dirs outside the sysroot (e.g. the Skia
      # release cache) would also get the sysroot prefix. Map them into
      # the sysroot with a stable symlink so lld can resolve them.
      target="\${arg#-L}"
      digest="\$(printf '%s' "\$target" | cksum | awk '{print \$1}')"
      link_dir="\$sysroot/.moui-lib-\$digest"
      if [[ ! -e "\$link_dir" ]]; then
        mkdir -p "\$(dirname "\$link_dir")"
        ln -s "\$target" "\$link_dir" 2>/dev/null || true
      fi
      args+=("-L/.moui-lib-\$digest")
      ;;
    *)
      args+=("\$arg")
      ;;
  esac
done
if [[ \$has_c -eq 0 && \$has_o -eq 1 ]]; then
  # Link invocation: the Skia release archive is built against libstdc++
  # and needs the exception runtime; pass the sysroot libraries directly
  # (zig filters -lstdc++ and would substitute its own libc++ instead).
  args+=(
    "\$sysroot/usr/lib/gcc/riscv64-linux-gnu/\$cxx_ver/libstdc++.so"
    "\$sysroot/lib/riscv64-linux-gnu/libgcc_s.so.1"
  )
fi
# Use the sysroot libstdc++ (matching the Skia archive) instead of zig's
# bundled libc++, disable zig's default UBSan instrumentation, and expose
# the sysroot include layout (libstdc++ before /usr/include so that
# include_next resolves against the target glibc headers).
exec "$zig_bin" cc -target "\$target_triple" --sysroot "\$sysroot" \
  -fno-sanitize=all \
  -isystem "\$sysroot/usr/include/c++/\$cxx_ver" \
  -isystem "\$sysroot/usr/include/riscv64-linux-gnu/c++/\$cxx_ver" \
  -isystem "\$sysroot/usr/include/backward" \
  -isystem "\$sysroot/usr/include" \
  "\${args[@]}"
EOF
cat > "$wrapper_dir/moui-riscv64-ar" <<EOF
#!/usr/bin/env bash
exec "$zig_bin" ar "\$@"
EOF
chmod +x "$wrapper_dir/moui-riscv64-cc" "$wrapper_dir/moui-riscv64-ar"
export MOON_CC="$wrapper_dir/moui-riscv64-cc"
export MOON_AR="$wrapper_dir/moui-riscv64-ar"

# moon links host-prebuilt runtime objects from the toolchain lib dir when
# both simdutf objects exist; they are x86_64 and cannot link into the
# riscv64 target. Hide them for this cross build and restore afterwards.
toolchain_lib="$(cd "$(dirname "$(command -v moon)")/.." && pwd)/lib"
hidden_toolchain=()
for object in simdutf.o moonbit_simdutf.o libbacktrace.a; do
  if [[ -f "$toolchain_lib/$object" ]]; then
    mv "$toolchain_lib/$object" "$toolchain_lib/$object.moui-cross-hidden"
    hidden_toolchain+=("$object")
  fi
done
restore_toolchain() {
  local object
  for object in "${hidden_toolchain[@]:-}"; do
    [[ -f "$toolchain_lib/$object.moui-cross-hidden" ]] &&
      mv "$toolchain_lib/$object.moui-cross-hidden" "$toolchain_lib/$object"
  done
  return 0
}
trap 'restore_toolchain; cleanup' EXIT

# Provide a riscv64 libbacktrace substitute so the linker finds a
# compatible archive at the path moon always passes. Only replace the
# archive when the host one was actually hidden, so a failed lookup never
# leaves an incompatible archive on the host toolchain.
if [[ " ${hidden_toolchain[*]} " == *" libbacktrace.a "* ]]; then
  stub_src="$repo_root/scripts/moui-riscv64-libbacktrace-stub.c"
  stub_obj="$wrapper_dir/moui-riscv64-libbacktrace-stub.o"
  "$zig_bin" cc -target "$target_triple" --sysroot "$sysroot" \
    -fno-sanitize=all -O2 -c "$stub_src" -o "$stub_obj"
  "$zig_bin" ar rcs "$toolchain_lib/libbacktrace.a" "$stub_obj"
fi

export MOUI_LINUX_GLIB_STUB_CC_FLAGS="$glib_stub_flags"
export MOUI_LINUX_GLIB_CC_LINK_FLAGS="$glib_link_flags"
export MOUI_SKIA_PLATFORM=linux
export MOUI_SKIA_ARCH=riscv64
export MOUI_SKIA_CONFIG=Release
export MOUI_SKIA_LINK_MODE=static
export MOUI_SKIA_PROVIDER=release
export MOUI_SKIA_SKIA_PROVIDER=release
export MOUI_SKIA_ENABLE_GPU_VULKAN=0
export MOUI_SKIA_ENABLE_SKPARAGRAPH=1
export MOUI_SKIA_REQUIRE_SKPARAGRAPH=1
export MOUI_SKIA_RENDERER=skia-raster
export MOUI_SKIA_EXTRA_CC_FLAGS="$native_stub_flags"
export MOUI_SKIA_EXTRA_LINK_FLAGS="$native_link_flags -lz -ldl -lm -pthread"
export MOUI_PDFIUM_DISABLE_PREBUILD_PDFIUM=1

mkdir -p "$target_dir"
build_log="$log_dir/cross-build.log"
: > "$build_log"
run_build() {
  local package="$1"
  echo "=== moon build $package ===" | tee -a "$build_log"
  moon build "$package" --target native --release --target-dir "$target_dir" 2>&1 | tee -a "$build_log"
}

run_build examples/showcase/linux_skia
run_build moui_tests/skia_renderer_smoke/native
run_build moui_tests/skia_text_emoji_smoke/native

# All moon builds are done; put the host toolchain back immediately so a
# later crash (e.g. SIGKILL) cannot leave the user's moon install broken.
restore_toolchain

find_executable() {
  local package="$1"
  local package_leaf
  package_leaf="$(basename "$package")"
  local build_root="$target_dir/native/release/build"
  local candidate
  candidate="$(find "$build_root" -type f \
    \( -path "*/$package/native.exe" -o -path "*/$package/$package_leaf.exe" \) \
    -perm -111 -print -quit 2>/dev/null || true)"
  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  echo "built executable not found under $build_root for package $package" >&2
  return 1
}

showcase_exe="$(find_executable examples/showcase/linux_skia)"
renderer_exe="$(find_executable moui_tests/skia_renderer_smoke/native)"
text_exe="$(find_executable moui_tests/skia_text_emoji_smoke/native)"

verify_elf() {
  local name="$1"
  local executable="$2"
  local report="$log_dir/$name.elf.txt"
  "$file_bin" "$executable" | tee "$report"
  "$readelf_bin" -h "$executable" | tee -a "$report"
  "$readelf_bin" -l "$executable" | tee -a "$report"
  grep -Eq 'ELF 64-bit' "$report" &&
    grep -Eq 'Class:[[:space:]]+ELF64' "$report" || {
    echo "$name is not ELF64" >&2
    return 1
  }
  grep -Eq 'Machine:[[:space:]]+RISC-V' "$report" || {
    echo "$name is missing RISC-V machine evidence" >&2
    return 1
  }
  grep -Eq 'Flags:.*double-float ABI' "$report" || {
    echo "$name is not using the RISC-V LP64D ABI" >&2
    return 1
  }
  grep -Eq 'Requesting program interpreter:.*ld-linux-riscv64-lp64d\.so\.1' "$report" || {
    echo "$name is missing the glibc RISC-V interpreter" >&2
    return 1
  }
  if "$readelf_bin" -d "$executable" | tee -a "$report" | grep -Eq 'Shared library: \[lib(vulkan|skia)\.so'; then
    echo "$name unexpectedly depends on Vulkan or shared Skia" >&2
    return 1
  fi
}

verify_elf showcase "$showcase_exe"
verify_elf renderer-smoke "$renderer_exe"
verify_elf text-emoji-smoke "$text_exe"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$showcase_exe" "$renderer_exe" "$text_exe" | tee "$log_dir/elf-sha256sums.txt"
else
  shasum -a 256 "$showcase_exe" "$renderer_exe" "$text_exe" | tee "$log_dir/elf-sha256sums.txt"
fi

if [[ $run_qemu -eq 1 ]]; then
  qemu_static="$sysroot/usr/bin/qemu-riscv64-static"
  if [[ ! -x "$qemu_static" ]]; then
    echo "--run-qemu requires /usr/bin/qemu-riscv64-static inside the sysroot" >&2
    exit 1
  fi
  qemu_mode=chroot
  root_cmd=()
  if [[ "$qemu_mode" == chroot && "$(id -u)" -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || {
      echo "--run-qemu requires root or sudo for the target-rootfs chroot" >&2
      exit 1
    }
    root_cmd=(sudo)
  fi
  run_qemu_smoke() {
    local name="$1"
    local executable="$2"
    local log="$log_dir/$name-qemu.log"
    echo "=== qemu $name ($qemu_mode) ===" | tee "$log"
    if [[ "$qemu_mode" == chroot ]]; then
      local staged="/tmp/moui-riscv64-$name-$$"
      "${root_cmd[@]}" cp "$executable" "$sysroot$staged"
      "${root_cmd[@]}" chmod 755 "$sysroot$staged"
      set +e
      if [[ "$name" == "text-emoji-smoke" && -n "${MOUI_RISCV64_QEMU_GDB:-}" ]]; then
        # Diagnostic mode: run under gdb-multiarch via QEMU's gdbstub so an
        # abort yields a backtrace. Enable with MOUI_RISCV64_QEMU_GDB=1.
        "${root_cmd[@]}" env \
          HOME=/tmp \
          XDG_CACHE_HOME=/tmp/.cache \
          FONTCONFIG_FILE=/etc/fonts/fonts.conf \
          MOUI_SKIA_FONT_DIRS=/usr/share/fonts \
          MOUI_SKIA_RENDERER=skia-raster \
          chroot "$sysroot" /usr/bin/qemu-riscv64-static -g 1234 "$staged" \
          >"$log" 2>&1 &
        local qemu_pid=$!
        sleep 2
        gdb-multiarch -batch \
          -ex "set pagination off" \
          -ex "set sysroot $sysroot" \
          -ex "set solib-search-path $sysroot" \
          -ex "target remote :1234" \
          -ex "handle SIGABRT stop print" \
          -ex "continue" \
          -ex "bt 40" \
          -ex "info sharedlibrary" \
          "$executable" 2>&1 | tee -a "$log"
        local status=$?
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
        set -e
        "${root_cmd[@]}" rm -f "$sysroot$staged"
        return "$status"
      fi
      # Run under a pseudo-terminal so MoonBit's buffered stdout is flushed
      # per line; otherwise failure details printed right before abort() are
      # lost when the smoke fails and calls fail_smoke.
      local chroot_cmd="env \
HOME=/tmp \
XDG_CACHE_HOME=/tmp/.cache \
FONTCONFIG_FILE=/etc/fonts/fonts.conf \
MOUI_SKIA_FONT_DIRS=/usr/share/fonts \
MOUI_SKIA_RENDERER=skia-raster \
chroot \"$sysroot\" /usr/bin/qemu-riscv64-static \"$staged\""
      "${root_cmd[@]}" script -qec "$chroot_cmd" /dev/null 2>&1 | tee -a "$log"
      local status="${PIPESTATUS[0]}"
      set -e
      "${root_cmd[@]}" rm -f "$sysroot$staged"
      return "$status"
    fi
  }
  run_qemu_smoke renderer-smoke "$renderer_exe"
  grep -Fq "MoUI Skia renderer smoke passed" "$log_dir/renderer-smoke-qemu.log"
  grep -Fq "MoUI Skia async image second-frame smoke passed" "$log_dir/renderer-smoke-qemu.log"
  run_qemu_smoke text-emoji-smoke "$text_exe"
  grep -Fq "MoUI Skia text/emoji smoke passed" "$log_dir/text-emoji-smoke-qemu.log"
  grep -Fq "engine=skparagraph" "$log_dir/text-emoji-smoke-qemu.log"
  grep -Fq "native_paragraph_ready=true" "$log_dir/text-emoji-smoke-qemu.log"
fi

echo "Linux RISC-V64 cross-build completed successfully"
