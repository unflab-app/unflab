#!/usr/bin/env bash
# release-plan.sh [ref] -- what releasing <ref> (default origin/main)
# would mean: the last tag, the bump it calls for, and what it rebuilds.
#
# Prints shell-readable lines:
#
#   prev=v0.9.1
#   bump=Z            Y, Z, or none
#   next=v0.9.2       empty when bump=none
#   recipes="ant apfel"
#   shared="scripts/build.sh"   the across-the-board files that changed
#
# The rule is AGENTS.md's table, computed rather than remembered: a file
# in every recipe's build key (build.sh, package.sh, verify.sh,
# templates/install.sh today) is the installer or the build driver, and
# changing one rebuilds everything -- a Y. Anything narrower that moves
# a key is a Z. Nothing moving a key is no release at all. The shared
# set is taken from build-key.sh, so it can't fall out of step with what
# the release cache actually hashes.
#
# X is never recommended; it stays 0 until someone decides otherwise.
#
# The key inputs are read from <ref>'s own tree, not the working tree,
# so a branch checked out locally doesn't change the answer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

REF="${1:-origin/main}"
git rev-parse -q --verify "$REF^{commit}" >/dev/null ||
  { echo "release-plan.sh: no such ref: $REF" >&2; exit 1; }

prev="$(git tag -l 'v*' --merged "$REF" --sort=-v:refname | head -1)"
[ -n "$prev" ] || { echo "release-plan.sh: no v* tag behind $REF" >&2; exit 1; }

tree="$(mktemp -d)"
trap 'rm -rf "$tree"' EXIT
git archive "$REF" | tar -x -C "$tree"

recipes=""
all_inputs=""
n=0
for r in $("$tree/scripts/resolve.sh" list-recipes); do
  inputs="$("$tree/scripts/build-key.sh" --inputs "$r")"
  all_inputs="$all_inputs$inputs"$'\n'
  n=$((n + 1))
  # shellcheck disable=SC2086
  if ! git diff --quiet "$prev" "$REF" -- $inputs; then
    recipes="$recipes $r"
  fi
done
recipes="${recipes# }"

# In every recipe's inputs, so in none of them by accident.
shared_files="$(printf '%s' "$all_inputs" | sort | uniq -c |
                awk -v n="$n" '$1 == n { print $2 }')"
shared=""
for f in $shared_files; do
  git diff --quiet "$prev" "$REF" -- "$f" || shared="$shared $f"
done
shared="${shared# }"

IFS=. read -r x y z <<EOF
${prev#v}
EOF
if [ -z "$recipes" ]; then
  bump=none; next=
elif [ -n "$shared" ]; then
  bump=Y; next="v$x.$((y + 1)).0"
else
  bump=Z; next="v$x.$y.$((z + 1))"
fi

printf 'prev=%s\nbump=%s\nnext=%s\nrecipes="%s"\nshared="%s"\n' \
  "$prev" "$bump" "$next" "$recipes" "$shared"
