#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <linux|darwin> <command> [args...]" >&2
  exit 2
fi

platform="$1"
shift

case "$platform" in
  linux|darwin) ;;
  *)
    echo "invalid platform '$platform' (expected: linux or darwin)" >&2
    exit 2
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
base_lock="$repo_root/flake.lock"
platform_lock="$repo_root/flake.lock.$platform"

if [[ ! -f "$platform_lock" ]]; then
  if [[ -f "$base_lock" ]]; then
    cp "$base_lock" "$platform_lock"
  else
    echo "missing both $platform_lock and $base_lock" >&2
    exit 1
  fi
fi

tmp_backup=""
had_base_lock=0
if [[ -f "$base_lock" ]]; then
  had_base_lock=1
  tmp_backup="$(mktemp "${TMPDIR:-/tmp}/flake.lock.backup.XXXXXX")"
  cp "$base_lock" "$tmp_backup"
fi

restore_base_lock() {
  if [[ $had_base_lock -eq 1 ]]; then
    cp "$tmp_backup" "$base_lock"
    rm -f "$tmp_backup"
  else
    rm -f "$base_lock"
  fi
}

trap restore_base_lock EXIT

cp "$platform_lock" "$base_lock"

set +e
(
  cd "$repo_root"
  "$@"
)
status=$?
set -e

if [[ -f "$base_lock" ]]; then
  cp "$base_lock" "$platform_lock"
fi

exit "$status"
