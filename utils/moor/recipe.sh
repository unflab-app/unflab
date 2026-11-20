# moor -- a pager, like less, that needs no configuration to look right
#
# Class 3 (convenience): a CGO_ENABLED=0 Go binary with no Homebrew
# dependencies, and upstream publishes prebuilt macOS binaries too.
# Nothing is escaped here; it's packaged so it installs the same way as
# everything else.
#
# moor was called moar until 2.0.0. `moar` is shipped as an alias of
# the binary rather than upstream's scripts/moar, which prints a
# rename notice on every run before exec'ing moor -- noise on every
# page view for anyone whose PAGER or scripts still say moar.
#
# Setting PAGER or MANPAGER is left to the user: it changes what every
# program that pages output does, so the post-install notes say how.

UNFLAB_NAME=moor
UNFLAB_VERSION=2.19.7
UNFLAB_VERSION_FLAG=--version
UNFLAB_HOMEPAGE=https://github.com/walles/moor
UNFLAB_LICENSE=BSD-2-Clause
UNFLAB_SOURCE=https://github.com/walles/moor/archive/refs/tags/v2.19.7.tar.gz
UNFLAB_CHECK=github:walles/moor
UNFLAB_SHA256=940547b19cd7307b93572739fbc9b71dcb196a191f05fb941e472295d9389f3a
UNFLAB_ATTEST='none:GitHub auto-generated tag archive; upstream publishes no checksum for it'
UNFLAB_TOOLCHAIN="go"
UNFLAB_CLASS=3
UNFLAB_PACKAGES=moor
UNFLAB_ALT_NAMES="moar"

unflab_build() {
  # CGO_ENABLED=0 for a binary that links nothing outside libSystem.
  # main.versionString is what `moor --version` prints; upstream's own
  # build.sh and Homebrew both set it with the leading v.
  CGO_ENABLED=0 go build \
    -trimpath \
    -buildvcs=false \
    -ldflags "-s -w -X main.versionString=v$UNFLAB_VERSION" \
    -o moor \
    ./cmd/moor
}

unflab_stage() {
  install -d "$STAGE_DIR/bin" "$STAGE_DIR/share/man/man1" "$STAGE_DIR/.unflab"
  install -m 755 moor "$STAGE_DIR/bin/moor"
  install -m 644 moor.1 "$STAGE_DIR/share/man/man1/moor.1"
  install -m 644 LICENSE "$STAGE_DIR/LICENSE"
  install -m 644 "$RECIPE_DIR/README.md" "$STAGE_DIR/README.md"
  install -m 644 "$RECIPE_DIR/post-install.txt" "$STAGE_DIR/.unflab/post-install.txt"
}
