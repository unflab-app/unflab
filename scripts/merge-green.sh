#!/usr/bin/env bash
# merge-green.sh [-n] [-y] -- merge every open PR whose checks all passed.
#
# Lists them with the paths each one touches, asks once, then merges each
# with a merge commit. A PR with any failed, cancelled or pending check,
# a draft, or one GitHub doesn't report as cleanly mergeable is left out
# and listed separately: those want looking at one by one.
#
#   -n   list only, merge nothing
#   -y   don't ask
#
# At the prompt, `y` merges them all; PR numbers instead merge all but
# those.
#
# Each PR is merged on its own checks, not queued and re-checked against
# the ones merged before it. That is sound for bumps, which each touch
# only their own utils/<recipe>/, and the touched paths are shown so a
# PR that reaches further stands out. The Build run on main afterwards
# is the check that they still build together (AGENTS.md, "Batch package
# changes into one Z").
#
# No --delete-branch: the repo already deletes merged branches, and gh's
# flag also deletes the local branch, switching away from it if it's
# checked out.
#
# The same thing, minus the path listing and the skip-by-number, works as
# a gh alias from any checkout:
#
#   gh alias set --clobber --shell merge-green - <<'EOF'
#   prs=$(gh pr list --state open --limit 100 \
#     --json number,title,isDraft,mergeable,statusCheckRollup --jq '
#       .[] | select((.isDraft | not) and .mergeable == "MERGEABLE"
#         and (.statusCheckRollup | length) > 0
#         and all(.statusCheckRollup[];
#               (.conclusion // .state) | IN("SUCCESS", "SKIPPED", "NEUTRAL")))
#       | "\(.number)\t\(.title)"')
#   [ -n "$prs" ] || { echo "No green PRs."; exit 0; }
#   printf '%s\n' "$prs"
#   printf 'Merge all of these? [y/N] '; read -r a </dev/tty
#   [ "$a" = y ] || exit 1
#   for n in $(printf '%s\n' "$prs" | cut -f1); do
#     gh pr merge "$n" --merge || echo "#$n: not merged" >&2
#   done
#   EOF

set -euo pipefail

LIST_ONLY=0
ASSUME_YES=0
while getopts ny opt; do
  case "$opt" in
    n) LIST_ONLY=1 ;;
    y) ASSUME_YES=1 ;;
    *) echo "usage: merge-green.sh [-n] [-y]" >&2; exit 2 ;;
  esac
done

# One row per open PR: number, verdict, title, touched paths. The verdict
# is "green" or the reason it isn't. A check run reports `conclusion`
# (null while it runs); a commit status reports only `state`.
rows="$(gh pr list --state open --limit 100 \
  --json number,title,isDraft,mergeable,statusCheckRollup,files --jq '
    .[]
    | ([.statusCheckRollup[] | .conclusion // .state // "PENDING"]) as $c
    | (if .isDraft then "draft"
       elif .mergeable != "MERGEABLE" then (.mergeable | ascii_downcase)
       elif ($c | length) == 0 then "no checks"
       elif all($c[]; IN("SUCCESS", "SKIPPED", "NEUTRAL")) then "green"
       else [$c[] | select(IN("SUCCESS", "SKIPPED", "NEUTRAL") | not)]
            | group_by(.) | map("\(length) \(.[0] | ascii_downcase)")
            | join(", ")
       end) as $verdict
    | [.number, $verdict, .title,
       ([.files[].path | split("/") | .[0:2] | join("/")] | unique
        | join(" "))]
    | @tsv')"

green=()
others=""
while IFS=$'\t' read -r num verdict title paths; do
  [ -n "$num" ] || continue
  if [ "$verdict" = green ]; then
    green+=("$num")
    printf '  #%-4s %-34s %s\n' "$num" "$title" "$paths"
  else
    others="$others$(printf '  #%-4s %-34s %s' "$num" "$title" "$verdict")"$'\n'
  fi
done <<EOF
$rows
EOF

if [ -n "$others" ]; then
  echo
  echo "Not green, left alone:"
  printf '%s' "$others"
fi

# bash 3.2 under set -u: an empty array can't be expanded, so test the
# count before anything touches "${green[@]}".
if [ "${#green[@]}" -eq 0 ]; then
  echo
  echo "No green PRs to merge."
  exit 0
fi

[ "$LIST_ONLY" -eq 0 ] || exit 0

if [ "$ASSUME_YES" -eq 0 ]; then
  echo
  printf 'Merge these %d? [y/N, or PR numbers to leave out] ' "${#green[@]}"
  read -r answer </dev/tty
  case "$answer" in
    y|Y) ;;
    ''|n|N) echo "Nothing merged."; exit 1 ;;
    *)
      keep=()
      for n in "${green[@]}"; do
        case " $(echo "$answer" | tr -d '#,') " in
          *" $n "*) ;;
          *) keep+=("$n") ;;
        esac
      done
      if [ "${#keep[@]}" -eq 0 ]; then echo "Nothing merged."; exit 1; fi
      green=("${keep[@]}")
      ;;
  esac
fi

# Carry on past a failure: an earlier merge can make a later PR conflict,
# and that one PR shouldn't stop the rest.
merged=()
failed=()
for n in "${green[@]}"; do
  if gh pr merge "$n" --merge; then
    merged+=("$n")
  else
    failed+=("$n")
  fi
done

echo
echo "Merged: ${#merged[@]}${merged[0]:+ (#$(IFS=' '; echo "${merged[*]}" | sed 's/ / #/g'))}"
if [ "${#failed[@]}" -gt 0 ]; then
  echo "Failed: #$(IFS=' '; echo "${failed[*]}" | sed 's/ / #/g')"
  exit 1
fi
