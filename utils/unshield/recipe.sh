# unshield -- extract files from InstallShield cabinet files
#
# Class 1 (dependency escape), though a small one. Homebrew's formula
# depends on openssl@4, which it uses for nothing but MD5 checks on
# extracted files. Upstream carries its own MD5 for exactly this case,
# so turning that on drops the TLS stack entirely. What remains is zlib
# and iconv, both of which macOS provides.

UNFLAB_NAME=unshield
UNFLAB_VERSION=1.6.2
UNFLAB_VERSION_FLAG=-V
UNFLAB_HOMEPAGE=https://github.com/twogood/unshield
UNFLAB_LICENSE=MIT
UNFLAB_SOURCE=https://github.com/twogood/unshield/archive/refs/tags/1.6.2.tar.gz
UNFLAB_CHECK=github-tags:twogood/unshield
UNFLAB_SHA256=a937ef596ad94d16e7ed2c8553ad7be305798dcdcfd65ae60210b1e54ab51a2f
UNFLAB_ATTEST='none:GitHub auto-generated tag archive; upstream publishes no checksum'
UNFLAB_TOOLCHAIN="c cmake make"
UNFLAB_CLASS=1
UNFLAB_PACKAGES=unshield

unflab_build() {
  # iconv lives in libiconv on macOS, not libc, so CMake's
  # check_symbol_exists(iconv) fails without it on the link line, and
  # the -e (filename encoding) option is silently compiled out.
  #
  # BUILD_STATIC links libunshield into the binary; the default is a
  # shared libunshield.dylib reached by an rpath into the install prefix.
  # src/CMakeLists.txt sets that rpath whatever the library type, so
  # install rpaths are skipped too; with nothing to find, it's dead weight
  # pointing into the build tree, and the gate rejects it.
  #
  # OpenSSL is disabled outright rather than just bypassed with
  # USE_OUR_OWN_MD5, so a Homebrew copy on the build machine can't be
  # picked up by any other route.
  LDFLAGS="-liconv${LDFLAGS:+ $LDFLAGS}" cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/../install" \
    -DBUILD_STATIC=ON \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DUSE_OUR_OWN_MD5=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON \
    -DBUILD_TESTING=OFF \
    >/dev/null
  cmake --build build -j "$(sysctl -n hw.ncpu)"
  cmake --install build >/dev/null
}

unflab_stage() {
  local pfx="$BUILD_DIR/../install"

  # Only `unshield` ships. The library, headers and pkg-config file are
  # for linking against libunshield, which nothing here does.
  install -d "$STAGE_DIR/bin" "$STAGE_DIR/share/man/man1"
  install -m 755 "$pfx/bin/unshield" "$STAGE_DIR/bin/unshield"
  install -m 644 "$pfx/share/man/man1/unshield.1" "$STAGE_DIR/share/man/man1/unshield.1"
  install -m 644 LICENSE "$STAGE_DIR/LICENSE"
  install -m 644 "$RECIPE_DIR/README.md" "$STAGE_DIR/README.md"
}
