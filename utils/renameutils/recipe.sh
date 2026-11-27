# renameutils -- rename and copy files by editing their names: qmv, imv and friends

# Class 1 (dependency escape): `brew install renameutils` pulls in the
# whole of coreutils and GNU readline. This build links only libedit and
# libSystem from /usr/lib.
#
# Upstream's last release was 0.12.0, in 2012, and on macOS it needed GNU
# ls at run time (qmv listed files with `ls --quoting-style=c`) and GNU
# readline to pre-fill imv's prompt. This builds the unflab-app fork,
# which lists files itself, drives libedit directly for imv, and works
# with BSD mv and cp; see its NEWS for the rest. It needs nothing beyond
# the system at run time.

UNFLAB_NAME=renameutils
UNFLAB_VERSION=0.13.0
# Every command takes --version, but the site shows `<package> <flag>`
# and no binary is called renameutils.
UNFLAB_VERSION_FLAG=-
UNFLAB_HOMEPAGE=https://github.com/unflab-app/renameutils
UNFLAB_LICENSE=GPL-3.0-or-later
UNFLAB_SOURCE=https://github.com/unflab-app/renameutils/releases/download/0.13.0/renameutils-0.13.0.tar.gz
UNFLAB_CHECK=github:unflab-app/renameutils
UNFLAB_SHA256=9b8ba87bd53f00ed7c181cc597af00a369985d6bc19c3a9d07e13f314ca9bb96
UNFLAB_ATTEST='sha256:https://github.com/unflab-app/renameutils/releases/download/$V/SHA256SUMS'
UNFLAB_TOOLCHAIN="c make"
UNFLAB_CLASS=1
UNFLAB_PACKAGES=renameutils
UNFLAB_ALT_NAMES="qmv qcp imv icp deurlname"

unflab_build() {
  # --disable-nls: translation catalogues are the only use for gettext.
  # --with-readline=libedit: macOS's own, rather than whatever GNU
  # readline configure might find on the build machine.
  ./configure --disable-nls --with-readline=libedit >/dev/null
  make
}

unflab_stage() {
  install -d "$STAGE_DIR/bin" "$STAGE_DIR/share/man/man1"
  # qcmd and icmd decide what they do from argv[0], so each name is
  # staged as its own copy rather than relying on an alias symlink that
  # install.sh might not create.
  local name
  for name in qmv qcp; do
    install -m 755 src/qcmd "$STAGE_DIR/bin/$name"
    install -m 644 src/qcmd.1 "$STAGE_DIR/share/man/man1/$name.1"
  done
  for name in imv icp; do
    install -m 755 src/icmd "$STAGE_DIR/bin/$name"
    install -m 644 src/icmd.1 "$STAGE_DIR/share/man/man1/$name.1"
  done
  install -m 755 src/deurlname "$STAGE_DIR/bin/deurlname"
  install -m 644 src/deurlname.1 "$STAGE_DIR/share/man/man1/deurlname.1"
  install -m 644 COPYING "$STAGE_DIR/LICENSE"
  install -m 644 "$RECIPE_DIR/README.md" "$STAGE_DIR/README.md"
}
