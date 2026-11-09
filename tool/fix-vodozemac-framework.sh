#!/usr/bin/env bash
# The flutter_vodozemac pub.dev archive ships its macOS xcframework with the
# versioned-bundle symlinks dereferenced (pub.dev's publish pipeline flattens
# symlinks). Xcode embeds and codesigns this framework directly under Swift
# Package Manager, and codesign rejects a versioned framework whose
# Versions/Current is a real directory:
#
#   .../protea.app: code object is not signed at all
#   In subcomponent: .../Frameworks/flutter_vodozemac.framework
#
# Recreate the symlinks in the pub cache. Idempotent; safe to run every build.
set -euo pipefail

pkg_dir=$(find "${PUB_CACHE:-$HOME/.pub-cache}/hosted" -maxdepth 2 -type d \
  -name 'flutter_vodozemac-*' 2>/dev/null | sort | tail -1)

if [[ -z "$pkg_dir" ]]; then
  echo "fix-vodozemac-framework: flutter_vodozemac not in pub cache, nothing to do"
  exit 0
fi

fw="$pkg_dir/macos/flutter_vodozemac/flutter_vodozemac.xcframework/macos-arm64_x86_64/flutter_vodozemac.framework"

if [[ ! -d "$fw" ]]; then
  echo "fix-vodozemac-framework: $fw not found, nothing to do"
  exit 0
fi

if [[ -L "$fw/Versions/Current" ]]; then
  echo "fix-vodozemac-framework: already repaired"
  exit 0
fi

echo "fix-vodozemac-framework: repairing $fw"

# Versions/Current is a duplicate of Versions/A -- drop it, symlink to A.
rm -rf "$fw/Versions/Current"
ln -s A "$fw/Versions/Current"

# Top level entries are duplicates of the ones in Versions/Current.
for entry in Headers Modules Resources flutter_vodozemac; do
  if [[ -e "$fw/Versions/Current/$entry" ]]; then
    rm -rf "$fw/$entry"
    ln -s "Versions/Current/$entry" "$fw/$entry"
  fi
done

echo "fix-vodozemac-framework: done"
