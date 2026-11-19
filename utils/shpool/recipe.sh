# shpool -- persistent shell sessions that survive a dropped connection

# Class 3 (convenience): Homebrew's formula depends on nothing but rust,
# at build time. There is no dependency tree to escape.
#
# shpool is a lighter alternative to tmux or screen for the one thing
# most people use them for over ssh: reattaching to a shell after the
# connection drops. It does no windowing or splitting, so the terminal's
# own scrollback, copy-paste and tabs keep working.
#
# Homebrew also offers a launchd service for the daemon. It ships here
# only as a sample plist under share/shpool, with instructions in the
# post-install notes: unflab doesn't install services, and shpool
# doesn't need one -- `shpool attach` forks a daemon itself if none is
# running. The plist's paths are placeholders, because launchd expands
# neither ~ nor $HOME and the binary's location depends on --prefix.
#
# libproc's build script runs bindgen against the macOS SDK's
# libproc.h, so building needs libclang. The Command Line Tools ship
# one, which is what clang-sys finds.

UNFLAB_NAME=shpool
UNFLAB_VERSION=0.11.7
UNFLAB_VERSION_FLAG=version
UNFLAB_HOMEPAGE=https://github.com/shell-pool/shpool
UNFLAB_LICENSE=Apache-2.0
UNFLAB_SOURCE=https://github.com/shell-pool/shpool/archive/refs/tags/v0.11.7.tar.gz
UNFLAB_CHECK=github:shell-pool/shpool
UNFLAB_SHA256=a521a6fc38434c6f881145b726ad4101e4bd1dc06f6f17260fdb881b52f172b6
UNFLAB_ATTEST='none:GitHub auto-generated tag archive; upstream publishes no checksum or signature'
UNFLAB_TOOLCHAIN="rust cargo"
UNFLAB_CLASS=3
UNFLAB_PACKAGES=shpool

unflab_build() {
  # Upstream reads its config only from ~/Library/Application Support on
  # macOS, though its docs say ~/.config throughout and its runtime files
  # already live under ~/.local/run. The patch prefers
  # $XDG_CONFIG_DIR/shpool or ~/.config/shpool when that directory exists,
  # falling back to Application Support, so existing configs keep working.
  # It is offered upstream; drop it once a release carries it.
  #
  # --fuzz=0 so a hunk that no longer matches fails the build rather than
  # landing somewhere nearby.
  patch -p1 --forward --fuzz=0 < "$RECIPE_DIR/config-dir.patch"

  # The workspace also holds libshpool and shpool-protocol; only the
  # binary crate is wanted. rust-toolchain.toml pins the compiler, which
  # rustup honours.
  cargo build --release --locked --package shpool
}

unflab_stage() {
  install -d "$STAGE_DIR/bin"
  install -m 755 target/release/shpool "$STAGE_DIR/bin/shpool"
  install -m 644 LICENSE "$STAGE_DIR/LICENSE"
  install -m 644 CONFIG.md "$STAGE_DIR/CONFIG.md"
  install -m 644 "$RECIPE_DIR/README.md" "$STAGE_DIR/README.md"
  install -m 644 "$RECIPE_DIR/shpool.plist" "$STAGE_DIR/shpool.plist"
  install -m 644 "$RECIPE_DIR/post-install.txt" "$STAGE_DIR/.unflab/post-install.txt"
}
