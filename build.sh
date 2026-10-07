#!/usr/bin/env bash
# Builds ffmpeg for one Android ABI, the way Svid uses it.
#
# usage: ANDROID_NDK_HOME=/path/to/ndk ./build.sh arm64-v8a|armeabi-v7a
#
# Writes dist/<abi>/: libffmpeg.so and libffprobe.so (the two programs) and
# libffmpeg.zip.so (the shared libraries under usr/lib/), the three files
# youtubedl-android's ffmpeg package puts in an app, so Svid runs them as it
# does that package's. Sources are fetched and checked against versions.sh.
#
# Every decoder, demuxer, muxer, parser, bitstream filter and protocol of
# ffmpeg stays in: whatever a download turns out to be must still be read.
# Encoders and filters are only those Svid uses; the external libraries are
# x264, LAME, dav1d, zimg and mbedTLS, each static inside the libraries.
set -euo pipefail

ABI=${1:?usage: build.sh arm64-v8a|armeabi-v7a}
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=versions.sh
. "$HERE/versions.sh"

case "$ABI" in
  arm64-v8a)   TRIPLE=aarch64-linux-android;    CLANG_TRIPLE=aarch64-linux-android;    ARCH=aarch64; CPU=armv8-a; MESON_CPU=aarch64 ;;
  armeabi-v7a) TRIPLE=arm-linux-androideabi;    CLANG_TRIPLE=armv7a-linux-androideabi; ARCH=arm;     CPU=armv7-a; MESON_CPU=arm ;;
  *) echo "unknown ABI $ABI" >&2; exit 2 ;;
esac

NDK=${ANDROID_NDK_HOME:?set ANDROID_NDK_HOME}
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64
SYSROOT=$TC/sysroot
export CC=$TC/bin/${CLANG_TRIPLE}${ANDROID_API}-clang
export CXX=$TC/bin/${CLANG_TRIPLE}${ANDROID_API}-clang++
export AR=$TC/bin/llvm-ar
export RANLIB=$TC/bin/llvm-ranlib
export STRIP=$TC/bin/llvm-strip
export NM=$TC/bin/llvm-nm
# 16 KB pages (Android 15+ devices may use them); r28 aligns by default, said
# here so a different NDK cannot quietly undo it.
export LDFLAGS="-Wl,-z,max-page-size=16384"
export CFLAGS="-O2 -fPIC"
export CXXFLAGS="-O2 -fPIC"

WORK=$HERE/work/$ABI
SRC=$HERE/work/src
PREFIX=$WORK/prefix
OUT=$HERE/dist/$ABI
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$SRC" "$PREFIX" "$OUT"
export PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
JOBS=$(nproc)

fetch() { # url sha256 -> path of the checked download
  local url=$1 sha=$2 f
  f=$SRC/$(basename "${url%%\?*}")
  [ -f "$f" ] || curl -fsSL --retry 3 -o "$f" "$url"
  echo "$sha  $f" | sha256sum -c --quiet - || { echo "SHA-256 mismatch: $url" >&2; rm -f "$f"; exit 1; }
  echo "$f"
}

unpack() { # archive -> fresh dir under $WORK
  local a=$1 d=$WORK/$2
  rm -rf "$d"; mkdir -p "$d"
  tar -xf "$a" -C "$d" --strip-components=1
  echo "$d"
}

# --- x264 (H.264 encoder) -------------------------------------------------
if [ ! -d "$SRC/x264/.git" ]; then git clone --quiet "$X264_REPO" "$SRC/x264"; fi
git -C "$SRC/x264" fetch --quiet origin "$X264_COMMIT" 2>/dev/null || true
git -C "$SRC/x264" checkout --quiet --force "$X264_COMMIT"
[ "$(git -C "$SRC/x264" rev-parse HEAD)" = "$X264_COMMIT" ] || { echo "x264 commit mismatch" >&2; exit 1; }
rm -rf "$WORK/x264"; cp -r "$SRC/x264" "$WORK/x264"
( cd "$WORK/x264"
  ./configure --prefix="$PREFIX" --host="$TRIPLE" --cross-prefix="$TC/bin/llvm-" \
    --sysroot="$SYSROOT" --enable-static --enable-pic --disable-cli --disable-opencl \
    --disable-lavf --disable-swscale --disable-ffms --disable-gpac --disable-lsmash \
    --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS"
  make -j"$JOBS" && make install )

# --- LAME (MP3 encoder) -----------------------------------------------------
d=$(unpack "$(fetch "$LAME_URL" "$LAME_SHA256")" lame)
cp /usr/share/misc/config.sub /usr/share/misc/config.guess "$d/"  # 2017's do not know Android
( cd "$d"
  ./configure --host="$TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static \
    --with-pic --disable-frontend --disable-decoder --disable-gtktest --disable-analyzer-hooks
  make -j"$JOBS" && make install )

# --- dav1d (AV1 decoder) ----------------------------------------------------
d=$(unpack "$(fetch "$DAV1D_URL" "$DAV1D_SHA256")" dav1d)
cat > "$WORK/cross.meson" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
pkg-config = 'pkg-config'
[host_machine]
system = 'android'
cpu_family = '$MESON_CPU'
cpu = '$MESON_CPU'
endian = 'little'
EOF
( cd "$d"
  meson setup build --cross-file "$WORK/cross.meson" --prefix="$PREFIX" --libdir=lib \
    --default-library=static --buildtype=release -Denable_tools=false -Denable_tests=false
  ninja -C build install )

# --- zimg (zscale: HDR to SDR) ------------------------------------------------
d=$(unpack "$(fetch "$ZIMG_URL" "$ZIMG_SHA256")" zimg)
( cd "$d"
  ./autogen.sh >/dev/null
  ./configure --host="$TRIPLE" --prefix="$PREFIX" --disable-shared --enable-static --with-pic
  make -j"$JOBS" && make install )
# zimg.pc asks for libstdc++, which the NDK does not have: libc++ is linked
# in by ffmpeg's configure below.
sed -i 's/-lstdc++//g' "$PREFIX/lib/pkgconfig/zimg.pc"

# --- mbedTLS (https, for yt-dlp's ffmpeg downloader) --------------------------
d=$(unpack "$(fetch "$MBEDTLS_URL" "$MBEDTLS_SHA256")" mbedtls)
( cd "$d"
  cmake -S . -B build -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="android-$ANDROID_API" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF \
    -DUSE_SHARED_MBEDTLS_LIBRARY=OFF -DUSE_STATIC_MBEDTLS_LIBRARY=ON
  cmake --build build --target install )

# --- ffmpeg -------------------------------------------------------------------
d=$(unpack "$(fetch "$FFMPEG_URL" "$FFMPEG_SHA256")" ffmpeg)
ENCODERS=libx264,aac,libmp3lame,gif,mjpeg,png,pcm_s16le,wrapped_avframe
FILTERS=$(tr -d ' \n' < "$HERE/filters.txt")
CXXRT="-L$SYSROOT/usr/lib/$TRIPLE -lc++_static -lc++abi"  # zimg is C++
( cd "$d"
  ./configure --prefix="$WORK/ffmpeg-out" \
    --enable-cross-compile --target-os=android --arch="$ARCH" --cpu="$CPU" \
    --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" --strip="$STRIP" --nm="$NM" \
    --sysroot="$SYSROOT" --pkg-config=pkg-config --pkg-config-flags=--static \
    --extra-cflags="$CFLAGS -I$PREFIX/include" \
    --extra-ldflags="$LDFLAGS -L$PREFIX/lib" --extra-libs="$CXXRT -lm" \
    --enable-gpl --enable-version3 --enable-shared --disable-static --enable-pic \
    --disable-autodetect --enable-pthreads --enable-zlib \
    --enable-libx264 --enable-libmp3lame --enable-libdav1d --enable-libzimg --enable-mbedtls \
    --disable-doc --disable-ffplay --disable-postproc \
    --disable-jni --disable-mediacodec --disable-hwaccels \
    --disable-indevs --enable-indev=lavfi --disable-outdevs \
    --disable-encoders --enable-encoder="$ENCODERS" \
    --disable-filters --enable-filter="$FILTERS" \
    --disable-debug
  make -j"$JOBS" && make install )

# The gate: what Svid needs must be in, before anything is packed.
"$HERE/check-features.sh" "$WORK/ffmpeg/ffbuild/config.mak"

# --- the three files ----------------------------------------------------------
STAGE=$WORK/stage/usr/lib
mkdir -p "$STAGE"
for lib in "$WORK"/ffmpeg-out/lib/lib*.so; do
  # Each library under its SONAME (libavcodec.so.61): the name the programs ask for.
  soname=$("$TC/bin/llvm-readelf" -d "$lib" | sed -n 's/.*Library soname: \[\(.*\)\]/\1/p')
  cp -L "$lib" "$STAGE/$soname"
  "$STRIP" --strip-unneeded "$STAGE/$soname"
done
cp "$WORK/ffmpeg-out/bin/ffmpeg" "$OUT/libffmpeg.so"
cp "$WORK/ffmpeg-out/bin/ffprobe" "$OUT/libffprobe.so"
"$STRIP" --strip-unneeded "$OUT/libffmpeg.so" "$OUT/libffprobe.so"
python3 "$HERE/pack.py" "$WORK/stage" "$OUT/libffmpeg.zip.so"

# What went in, for the release notes and for the next audit.
{
  echo "ABI $ABI, NDK $NDK_VERSION, API $ANDROID_API"
  for f in "$OUT"/* "$STAGE"/*; do echo "$(stat -c %s "$f") $(basename "$f")"; done
  echo "NEEDED:"
  for f in "$OUT/libffmpeg.so" "$STAGE"/*; do
    echo "  $(basename "$f"): $("$TC/bin/llvm-readelf" -d "$f" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | tr '\n' ' ')"
  done
} | tee "$OUT/BUILDINFO.txt"
