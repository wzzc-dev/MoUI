#!/usr/bin/env bash

normalize_bool() {
  local name="$1"
  local value="$2"
  case "$value" in
    1|true|TRUE|yes|YES|on|ON) printf '1\n' ;;
    ""|0|false|FALSE|no|NO|off|OFF) printf '0\n' ;;
    *)
      echo "unsupported boolean value for $name: $value" >&2
      exit 2
      ;;
  esac
}

reject_legacy_link_mode_env() {
  if [[ -n "${MOUI_SKIA_SKIA_LINK_MODE+x}" || -n "${MOUI_SKIA_MACOS_LINK_MODE+x}" ]]; then
    echo "MOUI_SKIA_SKIA_LINK_MODE and MOUI_SKIA_MACOS_LINK_MODE are no longer supported; use MOUI_SKIA_LINK_MODE=dynamic|static|auto." >&2
    exit 2
  fi
}

resolve_path() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$repo_root/$path" ;;
  esac
}

resolve_existing_dir() {
  local label="$1"
  local path="$2"
  if [[ ! -d "$path" ]]; then
    echo "$label does not exist or is not a directory: $path" >&2
    exit 1
  fi
  cd "$path" && pwd
}

relative_to_repo() {
  local path="$1"
  case "$path" in
    "$repo_root"/*) printf '%s\n' "${path#"$repo_root"/}" ;;
    *)
      echo "path is outside repository root: $path" >&2
      exit 2
      ;;
  esac
}

get_assignment_value() {
  local input="$1"
  local key="$2"
  printf '%s\n' "$input" | sed -n "s/^${key}=//p" | tail -n 1
}

require_log_marker() {
  local log_path="$1"
  local marker="$2"
  local error_message="$3"
  if ! grep -Fq "$marker" "$log_path"; then
    echo "$error_message" >&2
    exit 1
  fi
}

reject_log_marker() {
  local log_path="$1"
  local marker="$2"
  local error_message="$3"
  if grep -Fq "$marker" "$log_path"; then
    echo "$error_message" >&2
    exit 1
  fi
}
