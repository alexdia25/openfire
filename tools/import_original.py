"""Import a Return Fire install into a content pack in one step (issue #61, stage 2).

The dev pipeline used to be a hand-run sequence of separate scripts. This runs the same scripts, in
order, against an install the caller names, and writes the pack to a directory the caller names.
Nothing defaults to the developer's machine. It is also the reference that "Open Fire" mode's in-game
importer (importer/, a GDScript port of the runtime-needed subset) must reproduce: the parity check
runs both on the same install and diffs the packs.

    python tools/import_original.py <returnfire_dir> <out_dir> [--work DIR] [--keep-work] [--no-music]

<returnfire_dir> is the PC (Windows 95) release's install folder: RFIRE.BIN, ART/ART.CAR, SOUND/*.SDT,
WORLDS/, TITLE/. The music and the victory jingles come from the game CD's image, "RFIRE US.iso" in the
same folder (or RF_ISO=<path>), and are encoded with ffmpeg (libvorbis). Without either one, the pack
is built without music and a warning says so; the game runs silently in that case rather than not at
all. --no-music skips that part deliberately.

The pack is assembled in <out_dir>.partial and moved into place only when every step has succeeded, so
a failed or interrupted import never leaves a half-built pack where the game looks for one, and never
touches a good pack that is already there.

Validation is deliberately loose for now (issue #61, decision 2): the expected files must exist and be
roughly the right size. There is no hash check against known releases. It all lives in
validate_install(), so tightening it later does not touch the rest.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile

TOOLS = os.path.dirname(os.path.abspath(__file__))


class ImportError_(Exception):
    """A problem with the player's files, worded for the player."""


# path relative to the install -> minimum plausible size in bytes (loose: "roughly the right size")
REQUIRED_FILES = {
    "RFIRE.BIN": 300_000,
    os.path.join("ART", "ART.CAR"): 1_000_000,
}
REQUIRED_GLOBS = {
    os.path.join("SOUND", "*.SDT"): 30,      # the PC release has 40
    os.path.join("WORLDS", "**", "*.RFM"): 100,   # WORLDS/<1PLAYER|2PLAYER>/LEVELn/*.RFM, 204 in all
    os.path.join("TITLE", "*.BMP"): 4,
}


def validate_install(game_dir):
    """Raise ImportError_ with a player-facing message if game_dir is not a usable PC install."""
    if not os.path.isdir(game_dir):
        raise ImportError_("%s is not a folder." % game_dir)
    present = {name.upper() for name in os.listdir(game_dir)}
    if "RFIRE.BIN" not in present and (glob.glob(os.path.join(game_dir, "*.cue")) or glob.glob(os.path.join(game_dir, "*", "*.cue"))):
        raise ImportError_("This looks like the 3DO version of Return Fire (a disc image). Only the PC "
                           "(Windows 95) release is supported for now: point this at the folder it was installed to.")
    for rel, min_size in REQUIRED_FILES.items():
        path = os.path.join(game_dir, rel)
        if not os.path.isfile(path):
            raise ImportError_("%s is missing. Is this the folder Return Fire (PC) was installed to?" % rel)
        if os.path.getsize(path) < min_size:
            raise ImportError_("%s is smaller than expected (%d bytes); the install may be damaged." % (rel, os.path.getsize(path)))
    for pattern, min_count in REQUIRED_GLOBS.items():
        found = glob.glob(os.path.join(game_dir, pattern), recursive=True)
        if len(found) < min_count:
            raise ImportError_("Expected at least %d files matching %s, found %d; the install may be incomplete."
                               % (min_count, pattern, len(found)))


def music_source(game_dir):
    """(iso_path, None) if music can be imported, else (None, the reason it can't)."""
    iso = os.environ.get("RF_ISO", os.path.join(game_dir, "RFIRE US.iso"))
    if not os.path.isfile(iso):
        return None, "no CD image at %s (set RF_ISO to point at one)" % iso
    if shutil.which("ffmpeg") is None:
        return None, "ffmpeg is not on PATH"
    return iso, None


def run(step, n, total, args, env):
    print("[%d/%d] %s" % (n, total, step), flush=True)
    result = subprocess.run([sys.executable] + args, env=env, cwd=TOOLS)
    if result.returncode != 0:
        raise RuntimeError("%s failed (exit %d)" % (step, result.returncode))


def import_original(game_dir, out_dir, work_dir=None, keep_work=False, music=True):
    game_dir = os.path.abspath(game_dir)
    out_dir = os.path.abspath(out_dir)
    validate_install(game_dir)
    iso, why_no_music = music_source(game_dir) if music else (None, "--no-music")

    work = work_dir or tempfile.mkdtemp(prefix="rf_import_")
    partial = out_dir + ".partial"
    if os.path.exists(partial):
        shutil.rmtree(partial)
    env = dict(os.environ, RF_GAME_DIR=game_dir, PYTHONIOENCODING="utf-8")
    if iso:
        env["RF_ISO"] = iso
    car, rfm, sound = (os.path.join(work, d) for d in ("car", "rfm", "sound"))

    steps = [
        ("convert ART.CAR (sprites)", ["convert_car.py", game_dir, car]),
        ("convert WORLDS/*.RFM (levels)", ["convert_rfm.py", game_dir, rfm]),
        ("convert SOUND/*.SDT (sound effects)", ["convert_sdt.py", game_dir, sound]),
        ("assemble the pack", ["build_pack.py", car, partial, "--build-rfm-dir", rfm, "--build-sound-dir", sound]),
        ("extract the HUD backdrop strip", ["extract_hud_strip.py", partial]),
        ("extract the compass lamps", ["extract_compass_lamps.py", partial]),
        ("extract the victory banners", ["extract_win_banners.py", partial]),
    ]
    if iso:
        steps += [
            ("extract the music (CD image)", ["extract_music.py", partial]),
            ("extract the victory jingles (CD image)", ["extract_win_jingles.py", partial]),
        ]
    steps.append(("validate the pack", ["validate_pack.py", partial]))

    try:
        for i, (step, args) in enumerate(steps, 1):
            run(step, i, len(steps), args, env)
        if os.path.exists(out_dir):
            shutil.rmtree(out_dir)
        os.replace(partial, out_dir)
    except BaseException:
        if os.path.exists(partial):
            shutil.rmtree(partial)
        raise
    finally:
        if not keep_work and not work_dir:
            shutil.rmtree(work, ignore_errors=True)
    if why_no_music:
        print("warning: the pack has no music: %s" % why_no_music)
    print("imported %s -> %s" % (game_dir, out_dir))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("game_dir", help="the Return Fire (PC) install folder")
    ap.add_argument("out_dir", help="where the pack goes, e.g. packs/original_pc")
    ap.add_argument("--work", help="keep intermediate converter output here instead of a temp folder")
    ap.add_argument("--keep-work", action="store_true", help="don't delete the temp folder afterwards")
    ap.add_argument("--no-music", action="store_true", help="skip the music and jingles (CD image + ffmpeg)")
    args = ap.parse_args()
    try:
        import_original(args.game_dir, args.out_dir, args.work, args.keep_work, not args.no_music)
    except ImportError_ as e:
        print("error: %s" % e, file=sys.stderr)
        sys.exit(2)
    except RuntimeError as e:
        print("error: %s; nothing was written to %s" % (e, args.out_dir), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
