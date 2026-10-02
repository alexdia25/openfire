#!/usr/bin/env bash
# Exports the "Open Fire" presets and packs them into dist/, ready to attach to a GitHub release.
#
#   GODOT=<Godot 4.7 binary> tools/package_release.sh v0.1.0
#
# Needs the Godot export templates for the same version installed, and the engine submodule checked out
# (git submodule update --init). Produces dist/OpenFire-<version>-windows-x86_64.zip and
# dist/OpenFire-<version>-linux-x86_64.tar.gz. Neither contains any Return Fire content: the player's own game
# files are imported on first run (README, "Release builds").
set -eu
cd "$(dirname "$0")/.."
VERSION=${1:?usage: tools/package_release.sh <version, e.g. v0.1.0>}
GODOT=${GODOT:-godot}

rm -rf export dist
mkdir -p export/windows export/linux dist

# A fresh checkout has no .godot/ cache; the export needs the project imported first.
"$GODOT" --headless --path . --import --audio-driver Dummy || true

for preset in "Open Fire (Windows)" "Open Fire (Linux)"; do
	log=$("$GODOT" --headless --path . --audio-driver Dummy --export-release "$preset" 2>&1) || { echo "$log"; exit 1; }
	# Godot exits 0 on some failed exports; its "ERROR:" lines are the reliable signal.
	if echo "$log" | grep -q "^ERROR:"; then echo "$log"; exit 1; fi
done
[ -s export/windows/OpenFire.exe ] && [ -s export/windows/OpenFire.pck ] || { echo "Windows export incomplete"; exit 1; }
[ -s export/linux/OpenFire.x86_64 ] && [ -s export/linux/OpenFire.pck ] || { echo "Linux export incomplete"; exit 1; }

for d in windows linux; do cp tools/release_readme.txt "export/$d/README.txt"; done

NAME=OpenFire-$VERSION
(cd export/windows && python3 -m zipfile -c "../../dist/$NAME-windows-x86_64.zip" OpenFire.exe OpenFire.pck README.txt)
chmod +x export/linux/OpenFire.x86_64
tar -C export/linux -czf "dist/$NAME-linux-x86_64.tar.gz" OpenFire.x86_64 OpenFire.pck README.txt
ls -la dist
