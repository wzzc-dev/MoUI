#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/prepare-linux-riscv64-sysroot.sh [options]

Prepare the locked Ubuntu RISC-V64 glibc sysroot used by the Linux Skia
cross-build helper. The output directory is created atomically and is never
removed or overwritten when it already contains a valid marker.

Options:
  --output PATH       Sysroot directory. Default: .cache/moui/riscv64/sysroot.
  --lock PATH         Toolchain lock. Default: checks/toolchains/linux-riscv64.json.
  --dry-run           Print the resolved fixture and required host tools.
  -h, --help          Show this help.
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$repo_root/.cache/moui/riscv64/sysroot"
lock="$repo_root/checks/toolchains/linux-riscv64.json"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="${2:-}"; shift 2 ;;
    --lock) lock="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$output" in
  /*) ;;
  *) output="$repo_root/$output" ;;
esac
case "$lock" in
  /*) ;;
  *) lock="$repo_root/$lock" ;;
esac

if [[ ! -f "$lock" ]]; then
  echo "toolchain lock was not found: $lock" >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "node is required to read the JSON toolchain lock" >&2
  exit 1
fi

lock_value() {
  node - "$lock" "$1" <<'NODE'
const fs = require("node:fs");
const [lockPath, key] = process.argv.slice(2);
const value = JSON.parse(fs.readFileSync(lockPath, "utf8"))[key];
if (Array.isArray(value)) {
  for (const item of value) console.log(item);
} else if (value !== undefined) {
  console.log(String(value));
}
NODE
}

base_url="$(lock_value baseUrl)"
base_sha256="$(lock_value baseSha256)"
suite="$(lock_value suite)"
base_version="$(lock_value baseVersion)"
architecture="$(lock_value architecture)"
abi="$(lock_value abi)"
target_triple="$(lock_value targetTriple)"
glibc_abi="$(lock_value glibcAbi)"
packages=()
while IFS= read -r package; do
  [[ -n "$package" ]] && packages+=("$package")
done <<<"$(lock_value packages)"

if [[ "$architecture" != "riscv64" || "$abi" != "gnu" ||
  "$target_triple" != "riscv64-linux-gnu" || "$glibc_abi" != "lp64d" ]]; then
  echo "unsupported toolchain lock: architecture=$architecture abi=$abi target=$target_triple glibc_abi=$glibc_abi" >&2
  exit 1
fi
if [[ -z "$base_url" || ! "$base_sha256" =~ ^[0-9a-fA-F]{64}$ || -z "$suite" || -z "$base_version" || ${#packages[@]} -eq 0 ]]; then
  echo "toolchain lock is incomplete: $lock" >&2
  exit 1
fi

echo "Linux RISC-V64 sysroot fixture:"
echo "  output=$output"
echo "  suite=$suite"
echo "  base_version=$base_version"
echo "  architecture=$architecture"
echo "  abi=$abi"
echo "  target_triple=$target_triple"
echo "  glibc_abi=$glibc_abi"
echo "  base_url=$base_url"
echo "  packages=${packages[*]}"

if [[ $dry_run -eq 1 ]]; then
  for tool in curl tar sha256sum qemu-riscv64-static chroot node; do
    if command -v "$tool" >/dev/null 2>&1; then
      echo "  tool:$tool=present"
    else
      echo "  tool:$tool=missing"
    fi
  done
  exit 0
fi

for tool in curl tar node; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "required host tool is missing: $tool" >&2
    exit 1
  }
done
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
  echo "sha256sum or shasum is required" >&2
  exit 1
fi
qemu_bin="$(command -v qemu-riscv64-static || true)"
if [[ -z "$qemu_bin" ]]; then
  echo "qemu-riscv64-static is required; install qemu-user-static first" >&2
  exit 1
fi

if [[ "$output" == "$repo_root" || "$output" == "/" || -z "$output" ]]; then
  echo "refusing to use a broad directory as sysroot output: $output" >&2
  exit 2
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

marker_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$output/.moui-riscv64-sysroot" | tail -n 1
}

if [[ -e "$output/.moui-riscv64-sysroot" ]]; then
  if [[ "$(marker_value id)" == "linux-riscv64-gnu" &&
    "$(marker_value base_sha256)" == "$base_sha256" &&
    "$(marker_value base_version)" == "$base_version" &&
    "$(marker_value architecture)" == "riscv64" &&
    "$(marker_value abi)" == "gnu" &&
    "$(marker_value target_triple)" == "riscv64-linux-gnu" &&
    "$(marker_value glibc_abi)" == "lp64d" &&
    -f "$output/.moui-riscv64-packages" &&
    -f "$output/.moui-riscv64-files.sha256" &&
    "$(marker_value packages_sha256)" == "$(sha256_file "$output/.moui-riscv64-packages")" &&
    "$(marker_value files_manifest_sha256)" == "$(sha256_file "$output/.moui-riscv64-files.sha256")" ]]; then
    echo "valid sysroot already exists: $output"
    exit 0
  fi
  echo "sysroot marker does not match the locked RISC-V64 fixture: $output" >&2
  exit 1
fi
if [[ -e "$output" ]]; then
  echo "sysroot output exists without a valid marker: $output" >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  root_cmd=()
else
  command -v sudo >/dev/null 2>&1 || {
    echo "sudo is required when preparing a sysroot as a non-root user" >&2
    exit 1
  }
  root_cmd=(sudo)
fi

cache_dir="$(dirname "$output")"
mkdir -p "$cache_dir"
archive="$cache_dir/${base_url##*/}"
if [[ ! -f "$archive" ]]; then
  echo "downloading Ubuntu Base fixture"
  partial="$archive.partial"
  rm -f "$partial"
  curl -fL --retry 3 --retry-delay 2 "$base_url" -o "$partial"
  mv "$partial" "$archive"
fi

actual_sha256="$(sha256_file "$archive")"
if [[ "${actual_sha256,,}" != "${base_sha256,,}" ]]; then
  echo "Ubuntu Base checksum mismatch" >&2
  echo "  expected=$base_sha256" >&2
  echo "  actual=$actual_sha256" >&2
  rm -f "$archive"
  exit 1
fi

temp_root="$(mktemp -d "${cache_dir}/.sysroot.XXXXXX")"
cleanup() {
  if [[ -d "$temp_root" ]]; then
    "${root_cmd[@]}" rm -rf -- "$temp_root"
  fi
}
trap cleanup EXIT

tar -xzf "$archive" -C "$temp_root"
"${root_cmd[@]}" cp "$qemu_bin" "$temp_root/usr/bin/qemu-riscv64-static"
"${root_cmd[@]}" mkdir -p "$temp_root/proc" "$temp_root/sys" "$temp_root/dev"
"${root_cmd[@]}" rm -f "$temp_root/etc/resolv.conf"
"${root_cmd[@]}" cp /etc/resolv.conf "$temp_root/etc/resolv.conf"

printf '%s\n' \
  "deb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports ${suite} main universe" \
  "deb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports ${suite}-updates main universe" \
  "deb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports ${suite}-security main universe" \
  | "${root_cmd[@]}" tee "$temp_root/etc/apt/sources.list" >/dev/null
"${root_cmd[@]}" rm -f "$temp_root/etc/apt/sources.list.d"/*.list 2>/dev/null || true

chroot_target() {
  "${root_cmd[@]}" chroot "$temp_root" /usr/bin/qemu-riscv64-static /bin/sh -c "$1"
}

echo "installing target development packages"
chroot_target 'export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y --no-install-recommends ca-certificates '"${packages[*]}"

# Package indexes and archives are not part of the reusable target rootfs
# evidence. Removing them also keeps the checksum manifest focused on files
# that affect compilation and QEMU execution.
chroot_target 'apt-get clean; rm -rf /var/lib/apt/lists/* /var/cache/apt/*'

chroot_target 'dpkg-query -W -f="${Package}\t${Version}\n"' \
  | "${root_cmd[@]}" tee "$temp_root/.moui-riscv64-packages" >/dev/null

"${root_cmd[@]}" bash -c '
  cd "$1"
  find . -xdev -type f \
    ! -path "./.moui-riscv64-files.sha256" \
    ! -path "./etc/resolv.conf" \
    -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 -r sha256sum
' bash "$temp_root" \
  | "${root_cmd[@]}" tee "$temp_root/.moui-riscv64-files.sha256" >/dev/null

printf '%s\n' \
  "id=linux-riscv64-gnu" \
  "distribution=ubuntu" \
  "suite=$suite" \
  "base_version=$base_version" \
  "base_url=$base_url" \
  "base_sha256=$base_sha256" \
  "architecture=riscv64" \
  "abi=gnu" \
  "target_triple=riscv64-linux-gnu" \
  "glibc_abi=lp64d" \
  "packages_sha256=$(sha256_file "$temp_root/.moui-riscv64-packages")" \
  "files_manifest_sha256=$(sha256_file "$temp_root/.moui-riscv64-files.sha256")" \
  "prepared_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  | "${root_cmd[@]}" tee "$temp_root/.moui-riscv64-sysroot" >/dev/null

"${root_cmd[@]}" chown -R "$(id -u):$(id -g)" "$temp_root" 2>/dev/null || true
mv "$temp_root" "$output"
trap - EXIT
echo "prepared Linux RISC-V64 sysroot: $output"
