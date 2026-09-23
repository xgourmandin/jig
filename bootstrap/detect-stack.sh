#!/usr/bin/env bash
# Deterministically detect which ACME stack plugins a repo needs.
# Usage: detect-stack.sh [repo-dir]  -> prints one stack per line
set -euo pipefail
cd "${1:-.}"
files="$(git ls-files 2>/dev/null || find . -type f -not -path './.git/*')"
has() { grep -Eq "$1" <<<"$files"; }
has '(^|/)pyproject\.toml$|(^|/)requirements[^/]*\.txt$|(^|/)setup\.py$|\.py$' && echo python
has '(^|/)package\.json$|\.tsx?$' && echo typescript
has '(^|/)go\.mod$' && echo go
has '\.tf$' && echo terraform
exit 0
