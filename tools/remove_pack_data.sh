#!/usr/bin/env bash
# Deletes the game data Open Fire converted from your Return Fire install. Settings are kept.
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Return Fire/packs/original_pc"
if [ ! -d "$DIR" ]; then echo "Nothing to remove: $DIR does not exist."; exit 0; fi
echo "This will delete:"
echo "  $DIR"
echo "Your Return Fire install is not touched; Open Fire will offer the import again on next launch."
read -r -p "Type y to continue: " ok
[ "$ok" = "y" ] || [ "$ok" = "Y" ] || { echo "Cancelled."; exit 1; }
rm -rf -- "$DIR" && echo "Removed."
