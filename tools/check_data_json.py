"""Checks every hand-maintained JSON file this repo's build tools read is at least syntactically valid, before anyone
runs build_pack.py against it. No game install or ART.CAR needed -- this only ever parses files already in the repo.

Written after a real regression: an edit to tools/data/tank_turret_tip_linkage.json's own "applied_in" note wrote a
literal unescaped quote, making the file invalid JSON. build_pack.py's build_render() reads it for the Tank's render
descriptor, so build_pack.py crashed partway through emit_vehicle_definitions() -- which, at the time, had already
cleared packs/original_pc/vehicles/ before regenerating it, so the crash left that directory completely empty. Since
packs/ is gitignored, nothing caught this until tools/tests/vehicle_behaviour_trace_check.gd happened to be run.
emit_vehicle_definitions() itself now computes every vehicle in memory before touching disk (so a crash there no longer
deletes anything), but a syntax error in one of these files is still worth catching in under a second, standalone,
rather than only via a full rebuild or a Godot test run.

Usage:
    python tools/check_data_json.py
Exit code 0 if every file parses; 1 (with each broken file's exact line/column) otherwise.
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    paths = sorted(glob.glob(os.path.join(ROOT, "tools", "data", "*.json")))
    paths += sorted(glob.glob(os.path.join(ROOT, "packs", "registry", "*.json")))
    errors = []
    for path in paths:
        rel = os.path.relpath(path, ROOT)
        try:
            with open(path, encoding="utf-8") as f:
                json.load(f)
        except json.JSONDecodeError as e:
            errors.append("%s: %s (line %d, column %d)" % (rel, e.msg, e.lineno, e.colno))
        except OSError as e:
            errors.append("%s: %s" % (rel, e))
    print("checked %d files" % len(paths))
    if errors:
        print("%d invalid:" % len(errors))
        for e in errors:
            print("  " + e)
        return 1
    print("all valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
