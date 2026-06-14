#!/usr/bin/env bash
#
# build-server.sh — build a self-contained whisper-server for macOS (Apple Silicon / arm64).
#
# "Static" on macOS: whisper + ggml + the Metal shader library are linked *into*
# the binary, so it depends on none of the build dir's .dylib files. A 100% static
# binary is not possible on macOS (libSystem, libc++ and system frameworks such as
# Metal/Accelerate are always linked dynamically), but those ship with every Mac,
# so the resulting dist/whisper-server is portable across Apple Silicon machines.
#
set -euo pipefail

cd "$(dirname "$0")"

BUILD_DIR="build-static"
JOBS="$(sysctl -n hw.ncpu)"

echo "==> Configuring $BUILD_DIR (Release, arm64, static libs, Metal embedded)"
cmake -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DWHISPER_BUILD_SERVER=ON \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DWHISPER_BUILD_TESTS=OFF

echo "==> Building whisper-server (-j$JOBS)"
cmake --build "$BUILD_DIR" --target whisper-server -j"$JOBS" --config Release

mkdir -p dist
cp "$BUILD_DIR/bin/whisper-server" dist/whisper-server

echo
echo "==> Built dist/whisper-server"
ls -lh dist/whisper-server | awk '{print "    size: " $5}'
echo
echo "==> Linkage (note: no libwhisper / libggml dylibs — they are baked in):"
otool -L dist/whisper-server | sed '1d;s/^/    /'
echo
echo "Done. Run it with: ./run-server.sh"
