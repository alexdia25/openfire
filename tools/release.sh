#!/usr/bin/env bash
# Release: builds, tags, pushes the tag and uploads the archives to a GitHub release.
#
#   GODOT=<Godot 4.7 binary> tools/release.sh v0.1.0 [--publish]
#
# The release is a draft unless --publish is given, matching the Release workflow. Needs the `gh` CLI
# (logged in) and everything tools/build.sh needs. Refuses to run from a dirty tree, from a commit that is not
# pushed (the engine submodule pointer must be fetchable), or if the tag already exists.
# Pushing the tag also starts the Release workflow; both paths create-or-update the same release, so
# whichever finishes second just re-uploads the archives.
set -eu
cd "$(dirname "$0")/.."
VERSION=${1:?usage: tools/release.sh <version, e.g. v0.1.0> [--publish]}
MODE=--draft
[ "${2:-}" = "--publish" ] && MODE=

[[ $VERSION == v* ]] || { echo "Version must start with v (the workflow triggers on v* tags)"; exit 1; }
command -v gh >/dev/null || { echo "gh CLI not found"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in: gh auth login"; exit 1; }

[ -z "$(git status --porcelain)" ] || { echo "Working tree is dirty; commit or stash first"; exit 1; }
git fetch origin --tags --quiet
git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null && { echo "Tag $VERSION already exists"; exit 1; }
upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null) || { echo "Current branch has no upstream; push it first"; exit 1; }
[ "$(git rev-parse HEAD)" = "$(git rev-parse "$upstream")" ] || { echo "HEAD is not pushed to $upstream; push first"; exit 1; }
git submodule status | grep -q '^[+-U]' && { echo "Submodule is not at the committed pointer: git submodule update --init"; exit 1; }

bash tools/build.sh "$VERSION"

git tag -a "$VERSION" -m "Open Fire $VERSION"
git push origin "$VERSION"

if gh release view "$VERSION" >/dev/null 2>&1; then
	gh release upload "$VERSION" dist/* --clobber
else
	gh release create "$VERSION" dist/* $MODE --generate-notes --title "Open Fire $VERSION"
fi
gh release view "$VERSION" --json url -q .url
