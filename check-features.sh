#!/usr/bin/env bash
# The gate: everything Svid uses must be in this ffmpeg, read from the
# configure result (ffbuild/config.mak). A build missing one stops here,
# before anything is packed or published.
#
# usage: check-features.sh path/to/ffbuild/config.mak
set -euo pipefail
MAK=${1:?config.mak}
missing=0
need() { # kind name...
  local kind=$1; shift
  for n in "$@"; do
    local key="CONFIG_$(echo "${n}_${kind}" | tr 'a-z' 'A-Z')"
    [ "$kind" = lib ] && key="CONFIG_$(echo "$n" | tr 'a-z' 'A-Z')"
    if ! grep -qx "$key=yes" "$MAK"; then echo "MISSING $kind: $n ($key)"; missing=1; fi
  done
}

# Studio's outputs, yt-dlp's MP3, frame grabs, -f null runs.
need encoder libx264 aac libmp3lame gif mjpeg png pcm_s16le wrapped_avframe
# What downloads are: the common video and sound codecs, and thumbnails.
need decoder h264 hevc vp8 vp9 libdav1d av1 mpeg4 aac aac_latm opus vorbis mp3 flac alac pcm_s16le png mjpeg webp gif
need demuxer mov matroska hls mpegts flv mp3 aac ogg wav flac image2 gif concat ffmetadata
need indev lavfi
need muxer mp4 mov ipod matroska webm mp3 adts ogg wav gif image2 mpegts null ffmetadata
need parser h264 hevc aac mpegaudio vp9 av1 opus
need bsf aac_adtstoasc h264_mp4toannexb hevc_mp4toannexb extract_extradata
need protocol file pipe http https tcp tls hls crypto data concat
need filter null anull format aformat scale aresample \
  trim atrim setpts asetpts tpad fps pad setparams concat split asplit apad anullsrc color \
  volume loudnorm dynaudnorm ebur128 ametadata alimiter arnndn afftdn highpass atempo asetrate \
  palettegen paletteuse thumbnail showinfo zscale tonemap
need lib gpl version3 libx264 libmp3lame libdav1d libzimg mbedtls zlib

if [ "$missing" != 0 ]; then echo "feature gate FAILED" >&2; exit 1; fi
echo "feature gate passed"
