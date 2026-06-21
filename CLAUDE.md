# CLAUDE.md

This is a **fork of [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp)**
(`jpillora/whisper.cpp`). It tracks upstream and adds a self-contained
`whisper-server` distribution for macOS (Apple Silicon / arm64).

Upstream conventions, build options, examples, bindings, and tests are unchanged.
The fork's deltas are intentionally small and confined to the files listed below —
prefer upstream conventions when working anywhere else.

## Differences from upstream

### 1. On-demand model download — `examples/server/server.cpp`
The server downloads models itself, so no download script or pre-staged model
file is required (the previous `run-server.sh` helper was removed).

- `-m`/`--model` accepts **either a path or a model name** (e.g. `small.en`).
  The default is now `small.en` (upstream default was `models/ggml-base.en.bin`).
- A model *name* resolves to `<state>/models/ggml-<name>.bin`; if missing it is
  downloaded on first use (via `curl`, to a `.part` temp file then renamed) and
  reused on later starts.
- The `/load` endpoint also accepts model names and downloads on demand.
- New helpers added in the anonymous namespace: `k_known_models`, `state_dir()`,
  `models_dir()`, `model_url()`, `shell_quote()`, `download_file()`,
  `resolve_model()`. `resolve_model()` is called once at startup and inside `/load`.

**State directory** (honors the XDG Base Directory spec), resolved in order:
1. `$WHISPER_SERVER_STATE` (explicit override)
2. `$XDG_STATE_HOME/whisper-server`
3. `$HOME/.local/state/whisper-server`

Models are cached under `<state-dir>/models/`. `HF_TOKEN` is forwarded to `curl`
if set.

### 2. OpenAI-compatible STT endpoints — `examples/server/server.cpp`
The server speaks the OpenAI audio API, so OpenAI clients work by pointing
`base_url` at `http://<host>:<port>/v1`.

- `POST /v1/audio/transcriptions` and `POST /v1/audio/translations` share the
  native `/inference` handler (factored into a `handle_inference(req, res,
  force_translate)` lambda); `translations` forces `translate=true`.
- The `model` field is accepted and ignored — the served model is fixed at
  startup via `-m`/`--model`. Standard fields (`file`, `language`, `prompt`,
  `temperature`, `response_format`) and formats (`json`, `text`, `srt`,
  `verbose_json`, `vtt`) already match OpenAI.
- `timestamp_granularities[]=word` adds a top-level `words[]` array to
  `verbose_json` (helper `wants_word_timestamps()`); per-segment `words` are
  retained as an extension.
- No API-key enforcement (any/no `Authorization` is accepted).
- **Audio formats:** wav/mp3/flac decode natively (miniaudio); mp4/m4a/webm
  auto-convert via ffmpeg when it is installed. Genuinely undecodable input
  returns a JSON `400` (the `error_handler` no longer clobbers handler-set error
  bodies). `--convert` forces ffmpeg for every request.

### 3. Static build script — `build-server.sh`
Builds a portable `dist/whisper-server` for macOS arm64 (whisper + ggml + the
Metal shader library are linked *in*; only system frameworks stay dynamic).

- Configures CMake into `build-static/` (Release, arm64, `BUILD_SHARED_LIBS=OFF`,
  `GGML_METAL=ON`, `GGML_METAL_EMBED_LIBRARY=ON`, server enabled).
- **Re-signs the copied binary** with `codesign --force --sign -`. This is
  required: a plain `cp` invalidates the linker's ad-hoc signature on Apple
  Silicon and the kernel then SIGKILLs the copy as *"Code Signature Invalid"*.
  Any workflow that copies/moves the binary must re-sign it.

### 4. Ignored build output — `.gitignore`
`/dist/` is ignored; the binary is distributed via GitHub Releases, not committed.

### 5. Distribution via GitHub Releases
`dist/whisper-server` is published as a release asset (e.g. tag `v1.1.0`). Build
with `./build-server.sh`, then attach `dist/whisper-server` to a GitHub Release.

## Build & run (this fork)

```sh
./build-server.sh                  # -> dist/whisper-server (built + re-signed)
./dist/whisper-server              # downloads small.en on first run, serves :8080
./dist/whisper-server -m base.en   # other model, downloaded on demand
./dist/whisper-server --convert    # force ffmpeg every request (mp4/m4a/webm already auto-convert when ffmpeg is present)

curl http://127.0.0.1:8080/inference -F file=@samples/jfk.wav -F response_format=vtt

# OpenAI-compatible (point any OpenAI client's base_url at .../v1):
curl http://127.0.0.1:8080/v1/audio/transcriptions \
  -F file=@samples/jfk.wav -F model=whisper-1 -F response_format=verbose_json \
  -F 'timestamp_granularities[]=word'
```

Everything else (CMake targets, other examples, bindings, tests) follows upstream.
