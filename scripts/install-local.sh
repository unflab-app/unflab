#!/usr/bin/env bash
# Install a locally-staged utility straight from out/, without building a
# release archive first. This is what `make <util>.install` uses.
#
# It generates the same install.sh a real package gets and runs it, so the
# local path exercises exactly the code users run -- a local install that
# worked while the real one was broken would be worse than useless.
#
# Usage: scripts/install-local.sh <package> <prefix> [extra install.sh args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PKG="${1:?usage: install-local.sh <package> <prefix> [args...]}"
PREFIX="${2:?usage: install-local.sh <package> <prefix> [args...]}"
shift 2

STAGE="$ROOT_DIR/out/$PKG"
[[ -d "$STAGE" ]] || { echo "install-local.sh: nothing staged at out/$PKG -- run 'make $PKG.build'" >&2; exit 1; }

version="$(cat "$STAGE/.unflab/version")"
manifest="$STAGE/.unflab/manifest.tsv"

# Every placeholder package.sh fills must be filled here too, or the
# template's literal text is read as data.
post_install="$STAGE/.unflab/post-install.txt"
[[ -f "$post_install" ]] || post_install=/dev/null
fetch="$STAGE/.unflab/fetch.tsv"
[[ -f "$fetch" ]] || fetch=/dev/null

sed -e "/{{MANIFEST}}/r $manifest" \
    -e "/{{MANIFEST}}/d" \
    -e "/{{POST_INSTALL}}/r $post_install" \
    -e "/{{POST_INSTALL}}/d" \
    -e "/{{FETCH}}/r $fetch" \
    -e "/{{FETCH}}/d" \
    -e "s|{{UTIL}}|$PKG|g" \
    -e "s|{{VERSION}}|$version|g" \
    "$SCRIPT_DIR/templates/install.sh" > "$STAGE/install.sh"
chmod +x "$STAGE/install.sh"

exec sh "$STAGE/install.sh" --prefix "$PREFIX" "$@"
