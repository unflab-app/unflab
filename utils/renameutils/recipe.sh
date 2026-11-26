# renameutils -- rename and copy files by editing their names: qmv, imv and friends

# Class 1 (dependency escape): `brew install renameutils` pulls in the
# whole of coreutils and GNU readline. This build links only libedit and
# libSystem from /usr/lib.
#
# coreutils is there because renameutils calls mv, cp and ls and expects
# GNU's. macos.patch removes most of that need:
#
#   - mv and cp: qmv and qcp already run `mv -- OLD NEW`, which BSD mv is
#     fine with. imv and icp put `--` after the source file, which only
#     GNU's argument permutation accepts, so the patch moves it in front.
#   - ls: qmv and qcp list files with `ls --quoting-style=c`, which has
#     no BSD equivalent. The patch makes them use gls when it is on PATH,
#     and plain ls otherwise -- so they work with unflab's `ls` package,
#     Homebrew's coreutils, or a GNU ls that is first on PATH as `ls`.
#     Without one, qmv and qcp fail on ls's usage error; the post-install
#     notes say what to install.
#
# readline is there because imv pre-fills the prompt with the old name
# through rl_startup_hook and rl_insert_text. macOS's libedit accepts
# both but clears the line after calling the hook, so the name never
# appears. The patch drives libedit directly and queues the name with
# el_push, which survives the reset.

UNFLAB_NAME=renameutils
UNFLAB_VERSION=0.12.0
# Every command takes --version, but the site shows `<package> <flag>`
# and no binary is called renameutils.
UNFLAB_VERSION_FLAG=-
UNFLAB_HOMEPAGE=https://www.nongnu.org/renameutils/
UNFLAB_LICENSE=GPL-3.0-or-later
UNFLAB_SOURCE=https://download.savannah.gnu.org/releases/renameutils/renameutils-0.12.0.tar.gz
UNFLAB_CHECK=html:https://download.savannah.gnu.org/releases/renameutils/:renameutils
UNFLAB_SHA256=cbd2f002027ccf5a923135c3f529c6d17fabbca7d85506a394ca37694a9eb4a3
# The project's release keyring is empty; its member keyring holds the
# maintainer's key (4E6E 6521 EF30 0E30 457D 7AFB 8AAA C30E 7088 EFCB),
# which is the one the .sig is made with.
UNFLAB_ATTEST='gnupg:https://savannah.nongnu.org/project/memberlist-gpgkeys.php?group=renameutils&download=1'
UNFLAB_TOOLCHAIN="c make"
UNFLAB_CLASS=1
UNFLAB_PACKAGES=renameutils
UNFLAB_ALT_NAMES="qmv qcp imv icp deurlname"

unflab_build() {
  # --fuzz=0 so a hunk that no longer matches fails the build rather than
  # landing somewhere nearby.
  patch -p1 --forward --fuzz=0 < "$RECIPE_DIR/macos.patch"

  # The SDK declares lstat64 but not struct stat64 for arm64, so
  # configure finds the function and io-utils.c then fails to compile.
  # --disable-nls: translation catalogues are the only use for gettext.
  ac_cv_func_lstat64=no ./configure --disable-nls >/dev/null
  make
}

unflab_stage() {
  install -d "$STAGE_DIR/bin" "$STAGE_DIR/share/man/man1" "$STAGE_DIR/.unflab"
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
  install -m 644 "$RECIPE_DIR/post-install.txt" "$STAGE_DIR/.unflab/post-install.txt"
}
