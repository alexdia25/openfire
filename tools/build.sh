#!/usr/bin/env bash
# Production build: exports the Windows and Linux "Open Fire" presets and packs them into dist/.
#
#   GODOT=<Godot 4.7 binary> tools/build.sh [version]
#
# version defaults to `git describe` (e.g. v0.1.0 or v0.1.0-3-gabc1234). Needs the Godot export templates and the
# engine submodule; checks both up front. Output: dist/OpenFire-<version>-{windows,linux}-x86_64.{zip,tar.gz}.
set -eu
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
VERSION=${1:-$(git describe --tags --always --dirty)}

command -v "$GODOT" >/dev/null || { echo "Godot not found: set GODOT=<path to Godot 4.7 binary>"; exit 1; }
[ -f addons/openfire_engine/plugin.cfg ] || { echo "Engine submodule missing: git submodule update --init"; exit 1; }

echo "Building Open Fire $VERSION with $("$GODOT" --version)"
exec bash tools/package_release.sh "$VERSION"
