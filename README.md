# ffmpeg for Svid Android

The ffmpeg that [Svid](https://svid.app) for Android runs, and how it is built.

Svid downloads videos and edits them on the phone (Studio). Both run ffmpeg
as a program. This repository builds that ffmpeg for `arm64-v8a` and
`armeabi-v7a` from pinned, checked sources, and publishes each build with the
exact sources it used.

## What is in it

- **ffmpeg 7.1.5** with every decoder, demuxer, muxer, parser, bitstream
  filter and protocol, so whatever a download is can be read.
- **Encoders**: libx264, AAC, libmp3lame, GIF, MJPEG, PNG, PCM, wrapped_avframe.
- **Filters**: the ones Svid uses ([filters.txt](filters.txt)).
- **Libraries**, static inside ffmpeg's: x264, LAME, dav1d (AV1), zimg
  (HDR to SDR), mbedTLS (https).

Versions and SHA-256s: [versions.sh](versions.sh). The build:
[build.sh](build.sh). The check that stops a build missing anything Svid
uses: [check-features.sh](check-features.sh).

## Output

For each ABI, the three files Svid's app puts in its native library folder:
`libffmpeg.so` (ffmpeg), `libffprobe.so` (ffprobe) and `libffmpeg.zip.so`
(the shared libraries, unpacked by the app on first run).

## Licence

The ffmpeg built here is under the **GNU General Public License, version 3 or
later** (it is configured with `--enable-gpl --enable-version3`). Its
components keep their own licences: FFmpeg (LGPL-2.1+/GPL), x264 (GPL-2.0+),
LAME (LGPL-2.0+), dav1d (BSD-2-Clause), zimg (WTFPL), mbedTLS (Apache-2.0).
Each release attaches the complete sources it was built from together with
these scripts, which are themselves under the GPL-3.0-or-later.

## Building it yourself

On Linux with the Android NDK (version in `versions.sh`), meson, ninja,
autotools, cmake and pkg-config:

```bash
ANDROID_NDK_HOME=/path/to/ndk ./build.sh arm64-v8a
```
