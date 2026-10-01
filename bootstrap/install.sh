#!/usr/bin/env sh
# Web entry point for jig-init: clones the harness to a temp dir and runs
# bootstrap/jig-init with the given arguments (jig-init needs its templates).
#
#   curl -fsSL <raw-url>/bootstrap/install.sh | sh -s -- [jig-init args]
#
# JIG_HARNESS_URL overrides the repo to clone; JIG_HARNESS_REF pins a tag/branch.
set -eu

url="${JIG_HARNESS_URL:-https://github.com/xgourmandin/jig.git}"
ref="${JIG_HARNESS_REF:-}"

command -v git >/dev/null 2>&1 || { echo "jig: git is required" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ -n "$ref" ]; then
  git clone --quiet --depth 1 --branch "$ref" "$url" "$tmp/harness"
else
  git clone --quiet --depth 1 "$url" "$tmp/harness"
fi

# Default the marketplace URL to the one we cloned from.
JIG_MARKETPLACE_URL="${JIG_MARKETPLACE_URL:-$url}" "$tmp/harness/bootstrap/jig-init" "$@"
