#!/usr/bin/env bash
#
# Works out the version for an automatic release from the existing version
# tags (read from stdin, one per line, e.g. from `git tag -l 'v*'`) and
# pubspec.yaml. Prints the version without the leading v.
#
#   tool/release-version.sh stable        next stable version (pushes to main)
#   tool/release-version.sh dev RUN       next dev pre-release (pushes to development)
#
# stable: pubspec.yaml's version if it is newer than every stable tag (so
#         bumping it there starts a new minor/major), otherwise the newest
#         stable tag with its patch number raised by one.
# dev:    the next stable version plus `-dev.RUN` — above the current stable
#         release, so the beta channel picks it up, and below the next one,
#         so beta users move back to stable once main releases it.
#
# Example: git tag -l 'v*' | tool/release-version.sh dev 57   ->  1.2.1-dev.57

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
RUN="${2:-}"

case "${MODE}" in
  stable) ;;
  dev) [[ "${RUN}" =~ ^[0-9]+$ ]] || { echo "Error: dev needs a run number." >&2; exit 1; } ;;
  *) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

sort_versions() { sort -t. -k1,1n -k2,2n -k3,3n; }

# Is $1 newer than $2? (both MAJOR.MINOR.PATCH)
newer() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort_versions | tail -n1)" == "$1" ]]
}

pubspec="$(sed -n 's/^version: *\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "${REPO_DIR}/pubspec.yaml")"
[[ -n "${pubspec}" ]] || { echo "Error: no MAJOR.MINOR.PATCH version in pubspec.yaml." >&2; exit 1; }

# Newest stable (no pre-release suffix) tag.
latest="$( (grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true) | sed 's/^v//' | sort_versions | tail -n1)"

if [[ -z "${latest}" ]] || newer "${pubspec}" "${latest}"; then
  next="${pubspec}"
else
  IFS=. read -r major minor patch <<< "${latest}"
  next="${major}.${minor}.$((patch + 1))"
fi

if [[ "${MODE}" == dev ]]; then
  echo "${next}-dev.${RUN}"
else
  echo "${next}"
fi
