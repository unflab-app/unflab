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

`qmv` and `qcp` need GNU `ls`; `unflab ls` installs it as `gls`.

## About this build

Homebrew's renameutils depends on coreutils and GNU readline. This one
links only `libedit` and `libSystem`, which macOS provides in
`/usr/lib`. Getting there takes a small patch:

- `qmv` and `qcp` list files with `ls --quoting-style=c`, which macOS's
  `ls` doesn't support. They use `gls` if it is on your `PATH`, and
  plain `ls` otherwise, so a GNU `ls` installed under either name
  works. `--ls=PROGRAM` still overrides it.
- `imv` and `icp` use macOS's `mv` and `cp`. Their arguments are
  reordered so that BSD `mv` and `cp`, which stop reading options at
  the first file name, see them correctly.
- `imv` and `icp` use libedit's own interface to pre-fill the prompt,
  since its readline emulation discards the pre-filled text. Line
  editing follows libedit's emacs bindings and reads `~/.editrc`.

Upstream's man page for `imv` still says it uses GNU readline.

Two things work differently from a GNU/readline build:

- In `qmv`'s interactive mode (`qmv -i`, or when a rename conflicts),
  Ctrl-C doesn't clear a half-typed command. Use Ctrl-U.
- Options for `imv` and `icp` are passed straight to macOS's `mv` and
  `cp`, so GNU-only ones like `--backup` aren't available.

Upstream's `qcmd` and `icmd`, which only work when told which command to
be, aren't installed. renameutils has had no release since 0.12.0 in
2012.
