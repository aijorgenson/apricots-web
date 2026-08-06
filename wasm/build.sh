#!/usr/bin/env bash
# Build Apricots as a self-contained single-file WebAssembly page.
set -e

# The local wrapper script (build.local.sh, gitignored) sets up machine
# specific paths (emscripten toolchain, python) before running this script.
EMCC=$(command -v emcc || true)
if [ -z "$EMCC" ]; then
  echo "error: emcc not found in PATH" >&2
  exit 1
fi
PYTHON=${PYTHON:-}
if [ -z "$PYTHON" ]; then
  PYTHON=$(command -v python3 || command -v python || true)
fi
if [ -z "$PYTHON" ]; then
  echo "error: python3 not found in PATH" >&2
  exit 1
fi

SRC_DIR="$(cd "$(dirname "$0")/../apricots" && pwd)"
WASM_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="apricots.html"

# -fmacro-prefix-map makes __FILE__ expand to a relative path instead of the
# build machine's absolute path, so no /home/<user>/... leaks into the wasm.
COMMON_FLAGS=(
  -std=c++17
  -O2
  -fmacro-prefix-map="$SRC_DIR"=apricots
  -fmacro-prefix-map="$WASM_DIR"=wasm
  -Wno-enum-compare-switch
  -sUSE_SDL=2
  -sTOTAL_MEMORY=134217728
  -sALLOW_MEMORY_GROWTH=0
  -sEXIT_RUNTIME=1
  -sMODULARIZE=1
  -sEXPORT_NAME=ApricotsFactory
  -sSINGLE_FILE=1
  -sFILESYSTEM=1
  -sASSERTIONS=0
  -sEXPORTED_RUNTIME_METHODS=FS,UTF8ToString
  -sEXPORTED_FUNCTIONS=_main
  -sSTACK_SIZE=1048576
  -sASYNCIFY
  -DAP_PATH='"/share/apricots/"'
  -DSYSCONFIG_PATH='"/share/apricots/"'
  -I"$SRC_DIR"
  -I"$WASM_DIR"
)

SOURCES=(
  "$SRC_DIR/ai.cpp"
  "$SRC_DIR/all.cpp"
  "$SRC_DIR/apricots.cpp"
  "$SRC_DIR/collide.cpp"
  "$SRC_DIR/drak.cpp"
  "$SRC_DIR/drawall.cpp"
  "$SRC_DIR/fall.cpp"
  "$SRC_DIR/finish.cpp"
  "$SRC_DIR/game.cpp"
  "$SRC_DIR/init.cpp"
  "$SRC_DIR/sampleio.cpp"
  "$SRC_DIR/SDLfont.cpp"
  "$SRC_DIR/setup.cpp"
  "$SRC_DIR/shape.cpp"
  "$WASM_DIR/alure.cpp"
)

DATA_FILES=(apricots.shapes alt-8x16.psf apricots.cfg engine.wav jet.wav explode.wav groundhit.wav
  fuelexplode.wav shot.wav gunshot.wav bomb.wav splash.wav laser.wav stall.wav gunshot2.wav
  afterburner.wav finish.wav)

EMBED=()
for f in "${DATA_FILES[@]}"; do
  EMBED+=(--embed-file "$SRC_DIR/data/$f@/share/apricots/$f")
done

# Inject the license text verbatim into the shell template.
SHELL_TMP="$(mktemp --suffix=.html)"
LICENSE_FILE="$(dirname "$SRC_DIR")/LICENSE"
"$PYTHON" - "$WASM_DIR/shell.html" "$LICENSE_FILE" "$SHELL_TMP" <<'PYEOF'
import sys
tpl = open(sys.argv[1], encoding='utf-8').read()
license = open(sys.argv[2], encoding='utf-8').read()
open(sys.argv[3], 'w', encoding='utf-8').write(tpl.replace('__LICENSE_TEXT__', license))
PYEOF
trap 'rm -f "$SHELL_TMP"' EXIT

"$EMCC" "${COMMON_FLAGS[@]}" "${EMBED[@]}" -lal -lSDL2 \
  --shell-file "$SHELL_TMP" \
  -o "$WASM_DIR/$OUT" "${SOURCES[@]}"

echo "Build complete: $WASM_DIR/$OUT"