#!/usr/bin/env bash
#
# Works out the version for an automatic release and prints it without the
# leading v. Reads the existing version tags from stdin (one per line, e.g.
# from `git tag -l 'v*'`) and the commits since the newest stable tag from
# the git history.
#
#   tool/release-version.sh stable        next stable version (pushes to main)
#   tool/release-version.sh dev RUN       next dev pre-release (pushes to development)
#
# stable: the newest stable tag, bumped according to the Conventional Commits
#         since it — `type!:` or a `BREAKING CHANGE:` footer bumps the major,
#         `feat:` the minor, anything else the patch version. pubspec.yaml's
#         version is the floor: when it is higher, it is used as is. Without
#         any stable tag, pubspec.yaml's version is the first release.
# dev:    the next stable version plus `-dev.RUN` — above the current stable
#         release, so the beta channel picks it up, and below the next one,
#         so beta users move back to stable once main releases it.
#
# Example: git tag -l 'v*' | tool/release-version.sh dev 57   ->  1.3.0-dev.57

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
RUN="${2:-}"

case "${MODE}" in
  stable) ;;
  dev) [[ "${RUN}" =~ ^[0-9]+$ ]] || { echo "Error: dev needs a run number." >&2; exit 1; } ;;
  *) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 1 ;;
esac

sort_versions() { sort -t. -k1,1n -k2,2n -k3,3n; }

# Is $1 newer than $2? (both MAJOR.MINOR.PATCH)
newer() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort_versions | tail -n1)" == "$1" ]]
}

# How far the commits in $1 (a git revision range) move the version:
# prints major, minor or patch.
bump_level() {
  local level=patch message subject
  while IFS= read -r -d $'\x1e' message; do
    message="${message#$'\n'}"
    subject="${message%%$'\n'*}"
    if [[ "${subject}" =~ ^[a-zA-Z]+(\([^\)]*\))?!: ]] ||
       grep -qE '^BREAKING[ -]CHANGE:' <<< "${message}"; then
      echo major
      return
    fi
    [[ "${subject}" =~ ^feat(\([^\)]*\))?: ]] && level=minor
  done < <(git -C "${REPO_DIR}" log --format='%B%x1e' "$1")
  echo "${level}"
}

pubspec="$(sed -n 's/^version: *\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "${REPO_DIR}/pubspec.yaml")"
[[ -n "${pubspec}" ]] || { echo "Error: no MAJOR.MINOR.PATCH version in pubspec.yaml." >&2; exit 1; }

# Newest stable (no pre-release suffix) tag.
latest="$( (grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || true) | sed 's/^v//' | sort_versions | tail -n1)"

if [[ -z "${latest}" ]]; then
  next="${pubspec}"
else
  IFS=. read -r major minor patch <<< "${latest}"
  case "$(bump_level "v${latest}..HEAD")" in
    major) next="$((major + 1)).0.0" ;;
    minor) next="${major}.$((minor + 1)).0" ;;
    *)     next="${major}.${minor}.$((patch + 1))" ;;
  esac
  newer "${pubspec}" "${next}" && next="${pubspec}"
fi

if [[ "${MODE}" == dev ]]; then
  echo "${next}-dev.${RUN}"
else
  echo "${next}"
fi
