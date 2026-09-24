#!/usr/bin/env python3
"""Shrinks the APK exported by Godot by deflating the textures (.ctex) and scenes (.scn).

Godot stores those two types uncompressed in the APK so they can be memory-mapped, which makes
this game's APK ~350 MB; deflated it is ~200 MB, a much safer download for a phone. Android and
Godot read compressed assets transparently (Godot already ships its scripts and other resources
that way). Everything else is copied untouched (resources.arsc must stay stored), and the old
signature is dropped: the output has to be zipaligned and signed again with apksigner.

usage: compress_apk.py exported.apk unsigned_out.apk
"""
import sys
import zipfile

DEFLATE_EXT = (".ctex", ".scn")


def main(src: str, dst: str) -> None:
    before = after = 0
    with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            name = info.filename
            if name.startswith("META-INF/") and name.rsplit(".", 1)[-1] in ("SF", "RSA", "DSA", "EC", "MF"):
                continue
            data = zin.read(name)
            out = zipfile.ZipInfo(name, date_time=info.date_time)
            out.external_attr = info.external_attr
            out.create_system = info.create_system
            out.compress_type = info.compress_type
            if name.startswith("assets/") and name.endswith(DEFLATE_EXT):
                out.compress_type = zipfile.ZIP_DEFLATED
            zout.writestr(out, data, compresslevel=9 if out.compress_type == zipfile.ZIP_DEFLATED else None)
            before += info.compress_size
    with zipfile.ZipFile(dst) as z:
        after = sum(i.compress_size for i in z.infolist())
        assert z.testzip() is None
    print(f"{src}: {before / 1e6:.1f} MB -> {dst}: {after / 1e6:.1f} MB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
