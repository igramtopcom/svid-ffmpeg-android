# Every source this build uses, pinned. A download whose SHA-256 differs
# stops the build. x264 has no release tarballs: a pinned commit of its
# stable branch, checked after the clone.

FFMPEG_VERSION=7.1.5
FFMPEG_URL=https://ffmpeg.org/releases/ffmpeg-7.1.5.tar.xz
FFMPEG_SHA256=de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f
# Also checked against FFmpeg's release signing key (FCF9 86EA 15E6 E293 A564
# 4F10 B432 2F04 D676 58D8) when this pin was set, 2026-10-07.

X264_REPO=https://code.videolan.org/videolan/x264.git
X264_COMMIT=b35605ace3ddf7c1a5d67a2eb553f034aef41d55

LAME_VERSION=3.100
LAME_URL=https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e

DAV1D_VERSION=1.5.4
DAV1D_URL=https://downloads.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz
DAV1D_SHA256=686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5

ZIMG_VERSION=3.0.6
ZIMG_URL=https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz
ZIMG_SHA256=be89390f13a5c9b2388ce0f44a5e89364a20c1c57ce46d382b1fcc3967057577

MBEDTLS_VERSION=3.6.7
MBEDTLS_URL=https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.7/mbedtls-3.6.7.tar.bz2
MBEDTLS_SHA256=a7e8bcbec0e6f761b4af24f25677626b35f762f68eef79c08677a363212d11f6

# The NDK Svid's own build uses (installed by sdkmanager, which checks it).
NDK_VERSION=28.2.13676358
ANDROID_API=24
