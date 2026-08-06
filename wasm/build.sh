#!/run/current-system/sw/bin/bash
# Build Apricots as a self-contained single-file WebAssembly page.
set -e

export PATH="/nix/store/9xnqfrllp81xg4r4vpwr6kiiarzj1zd7-emscripten-6.0.2/bin:$PATH"
export PYTHON=/home/deadbeef/.lmstudio/extensions/backends/vendor/_amphibian/cpython3.11-linux-x86@3/bin/python3.11

EMCC=$(command -v emcc)
SRC_DIR="$(cd "$(dirname "$0")/../apricots" && pwd)"
WASM_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="apricots.html"

COMMON_FLAGS=(
  -std=c++17
  -O2
  -sUSE_SDL=2
  -sTOTAL_MEMORY=134217728
  -sALLOW_MEMORY_GROWTH=0
  -sEXIT_RUNTIME=1
  -sMODULARIZE=1
  -sEXPORT_NAME=ApricotsFactory
  -sSINGLE_FILE=1
  -sFILESYSTEM=1
  -sASSERTIONS=0
  -sEXPORTED_RUNTIME_METHODS=FS,allocateUTF8,UTF8ToString
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