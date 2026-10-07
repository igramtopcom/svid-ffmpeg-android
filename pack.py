"""Packs a staged usr/lib into the zip Svid unpacks on the phone.

usage: python3 pack.py STAGE_DIR OUT_ZIP

Svid's Ytdlp.kt unpacks libffmpeg.zip.so into its files dir and reads each
entry's Unix mode from the zip's own directory, so every entry carries one
(0644 for libraries) and the zip says it was made on Unix. Entries are
sorted and dated 1980-01-01 so the same inputs make the same zip.
"""
import os
import sys
import zipfile


def main(stage, out):
    entries = []
    for root, _, files in os.walk(stage):
        for f in files:
            full = os.path.join(root, f)
            entries.append((os.path.relpath(full, stage).replace(os.sep, '/'), full))
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, full in sorted(entries):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (0o100644 & 0xFFFF) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(full, 'rb') as fh:
                z.writestr(info, fh.read())
    print(f'{out}: {len(entries)} files, {os.path.getsize(out)} bytes')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
