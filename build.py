"""Generate per-dimension program stubs and package Tengu Aurora into a zip.

usage: python build.py [--install]
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
SHADERS = os.path.join(ROOT, "shaders")
VERSION = "2.1.0"
PACK_NAME = f"Tengu-Aurora-v{VERSION}"

DIMENSIONS = {"world0": "OVERWORLD", "world-1": "NETHER", "world1": "END"}

# program name -> (source file, extra defines)
PROGRAMS = {
    "shadow":                    ("shadow", []),
    "gbuffers_skybasic":         ("gbuffers_discard", []),
    "gbuffers_skytextured":      ("gbuffers_discard", []),
    "gbuffers_clouds":           ("gbuffers_discard", []),
    "gbuffers_terrain":          ("gbuffers_main", ["GB_TERRAIN"]),
    "gbuffers_damagedblock":     ("gbuffers_main", ["GB_DAMAGE"]),
    "gbuffers_entities":         ("gbuffers_main", ["GB_ENTITIES"]),
    "gbuffers_entities_glowing": ("gbuffers_main", ["GB_ENTITIES"]),
    "gbuffers_block":            ("gbuffers_main", ["GB_BLOCK"]),
    "gbuffers_hand":             ("gbuffers_main", ["GB_HAND"]),
    "gbuffers_hand_water":       ("gbuffers_main", ["GB_HAND"]),
    "gbuffers_textured":         ("gbuffers_main", ["GB_TEXTURED"]),
    "gbuffers_textured_lit":     ("gbuffers_main", ["GB_TEXTURED"]),
    "gbuffers_basic":            ("gbuffers_main", ["GB_BASIC"]),
    "gbuffers_line":             ("gbuffers_main", ["GB_BASIC"]),
    "gbuffers_lightning":        ("gbuffers_main", ["GB_BASIC", "GB_LIGHTNING"]),
    "gbuffers_spidereyes":       ("gbuffers_main", ["GB_ADDITIVE"]),
    "gbuffers_beaconbeam":       ("gbuffers_main", ["GB_ADDITIVE"]),
    "gbuffers_armor_glint":      ("gbuffers_main", ["GB_GLINT"]),
    "gbuffers_water":            ("gbuffers_water", []),
    "gbuffers_weather":          ("gbuffers_weather", []),
    "deferred":                  ("deferred", []),
    "composite":                 ("composite", []),
    "composite1":                ("composite1", []),
    "composite2":                ("composite2", []),
    "composite3":                ("composite3", []),
    "composite4":                ("composite4", []),
    "final":                     ("final", []),
}


def stub(dim_define, stage, source, defines):
    lines = ["#version 330 compatibility", "", f"#define {dim_define}", f"#define {stage}"]
    lines += [f"#define {d}" for d in defines]
    lines += ["", f'#include "/program/{source}.glsl"', ""]
    return "\n".join(lines)


def generate():
    for folder, dim in DIMENSIONS.items():
        out = os.path.join(SHADERS, folder)
        os.makedirs(out, exist_ok=True)
        for name in os.listdir(out):
            os.remove(os.path.join(out, name))
        for prog, (src, defs) in PROGRAMS.items():
            for ext, stage in (("vsh", "VSH"), ("fsh", "FSH")):
                with open(os.path.join(out, f"{prog}.{ext}"), "w", newline="\n") as f:
                    f.write(stub(dim, stage, src, defs))


def package(install):
    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)
    zpath = os.path.join(dist, PACK_NAME + ".zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _, files in os.walk(SHADERS):
            for fn in files:
                full = os.path.join(base, fn)
                z.write(full, os.path.relpath(full, ROOT).replace(os.sep, "/"))
    print("built", zpath)
    if install:
        target = os.path.join(os.environ["APPDATA"], ".minecraft", "shaderpacks", PACK_NAME + ".zip")
        with open(zpath, "rb") as src, open(target, "wb") as dst:
            dst.write(src.read())
        print("installed", target)


if __name__ == "__main__":
    generate()
    package("--install" in sys.argv)
