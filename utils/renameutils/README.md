# renameutils (unflab build)

Tools for renaming and copying files by editing their names, rather than
by typing them out twice.

- **`qmv`** / **`qcp`** open a list of file names in your editor
  (`$VISUAL`, then `$EDITOR`). Change the names, save and quit, and the
  files are renamed or copied to match. Swaps and cycles (`a`→`b`,
  `b`→`a`) are handled.
- **`imv`** / **`icp`** prompt for a new name with the old one already
  filled in, so you only edit the part that changes.
- **`deurlname`** decodes URL-encoded names: `my%20file.txt` becomes
  `my file.txt`.

```sh
qmv *.jpg                  # rename a batch in the editor
qmv -f do .                # one column: just the destination names
imv 'Long Report (final).pdf'
deurlname *%20*
```

`man qmv` and `man imv` have the rest.

## Install

```sh
./install.sh                      # into ~/.local/bin
./install.sh --prefix /usr/local/bin
./install.sh --uninstall
```

## About this build

This is the [unflab-app fork](https://github.com/unflab-app/renameutils)
of renameutils, whose last upstream release was 0.12.0 in 2012. The fork
exists so that renameutils works on macOS with nothing but the system:

- `qmv` and `qcp` read directories themselves instead of running GNU
  `ls`, ordering files the way GNU `ls` does for every listing option.
- `imv` and `icp` pre-fill the old name using libedit, which macOS
  provides, and work with macOS's own `mv` and `cp`.
- UTF-8 names appear as themselves in the editor, case-only renames
  work on macOS's case-insensitive file system, and `deurlname` never
  replaces an existing file.

Homebrew's renameutils depends on coreutils and GNU readline. This one
links only `libedit` and `libSystem`, which macOS provides in
`/usr/lib`. Line editing follows libedit's emacs bindings and reads
`~/.editrc`.

Options for `imv` and `icp` are passed straight to macOS's `mv` and
`cp`, so GNU-only ones like `--backup` aren't available. Messages are in
English: this build leaves out the translations.

Upstream's `qcmd` and `icmd`, which only work when told which command to
be, aren't installed.
