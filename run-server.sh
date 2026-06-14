#!/usr/bin/env bash
#
# run-server.sh — run the whisper-server built by ./build-server.sh
#
# Accepts media (wav/mp3/ogg/flac, and mp4/anything via --convert + ffmpeg) and
# returns transcripts. Request VTT with -F response_format=vtt.
#
# Env overrides:
#   MODEL   model file        (default: models/ggml-small.en.bin)
#   HOST    bind address      (default: 127.0.0.1)
#   PORT    port              (default: 8080)
# Any extra args are passed straight through to whisper-server, e.g.:
#   PORT=9000 ./run-server.sh --threads 8
#
set -euo pipefail

cd "$(dirname "$0")"

BIN="dist/whisper-server"
MODEL="${MODEL:-models/ggml-small.en.bin}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"

if [[ ! -x "$BIN" ]]; then
    echo "error: $BIN not found — build it first with ./build-server.sh" >&2
    exit 1
fi

if [[ ! -f "$MODEL" ]]; then
    echo "error: model not found: $MODEL" >&2
    echo "       download one, e.g.:  sh ./models/download-ggml-model.sh small.en" >&2
    echo "       or point at another: MODEL=/path/to/model.bin ./run-server.sh" >&2
    exit 1
fi

echo "==> whisper-server   http://$HOST:$PORT   (model: $MODEL)"
echo "    VTT example:"
echo "      curl http://$HOST:$PORT/inference -F file=@samples/jfk.wav -F response_format=vtt"
echo

# --convert lets the server accept mp4/etc. by transcoding with ffmpeg first.
exec "$BIN" \
    --model "$MODEL" \
    --host "$HOST" \
    --port "$PORT" \
    --convert \
    "$@"
