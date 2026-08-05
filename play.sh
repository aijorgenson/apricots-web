#!/usr/bin/env nix-shell
#!nix-shell -i bash -p autoconf automake libtool pkg-config SDL2 openal alure gcc
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

PREFIX="$REPO_DIR/.local-install"
BINARY="$PREFIX/bin/apricots"

if [ ! -x ./configure ]; then
  echo "==> No configure script found, running bootstrap..."
  ./bootstrap
fi

CONFIGURED_PREFIX=""
if [ -f Makefile ]; then
  CONFIGURED_PREFIX="$(sed -n 's/^prefix = //p' Makefile | head -1)"
fi

NEEDS_CLEAN=0
if [ -f Makefile ] && [ "$CONFIGURED_PREFIX" != "$PREFIX" ]; then
  NEEDS_CLEAN=1
fi

if [ ! -f Makefile ] || [ "$CONFIGURED_PREFIX" != "$PREFIX" ]; then
  echo "==> Running configure (prefix: $PREFIX)..."
  ./configure --prefix="$PREFIX"
fi

if [ "$NEEDS_CLEAN" = "1" ]; then
  # object files are compiled with -DAP_PATH baked to the old prefix; make's
  # timestamp check won't notice that, so force a full rebuild
  echo "==> Prefix changed, cleaning stale build objects..."
  make clean
fi

echo "==> Building..."
make -j"$(nproc)"

echo "==> Installing to $PREFIX..."
make install

echo "==> Launching Apricots..."
exec "$BINARY"
