#!/usr/bin/env bash
# releng.sh [command] -- maintainer release engineering: bump PRs to release.
#
#   releng.sh                  the whole round, interactively (`make releng`)
#   releng.sh list             open PRs, oldest first, and what each is waiting on
#   releng.sh merge [-y]       merge the green ones after one confirmation
#   releng.sh recheck <N>...   re-run the failed and cancelled checks on PRs
#   releng.sh recheck-fails    ...on every PR whose checks failed
#   releng.sh check-updates    propose bumps now instead of at the nightly run
#   releng.sh release [-y]     tag and release main, Y or Z worked out for you
#
# The round: list the PRs; re-run any red ones and wait (most reds are a
# runner that went away, not the bump); merge the green ones oldest
# first; wait for main's Build; then offer a release, recommending Y or Z
# from release-plan.sh, and wait for that too. Every step that changes
# anything asks first, and saying no to one still offers the next.
#
# Merging takes each PR on its own checks, not re-checked against the
# ones merged before it. Sound for bumps, which each touch only their own
# utils/<recipe>/; the touched paths are listed, and two green PRs on the
# same recipe are flagged, so one that reaches further stands out. The
# Build on main afterwards is the check that they build together.
#
# Merges are left without --delete-branch: the repo deletes merged
# branches itself, and gh's flag also deletes the local branch, switching
# away from it if it's checked out.
#
# A cut-down `merge` as a gh alias, for use without a checkout:
#
#   gh alias set --clobber --shell merge-green - <<'EOF'
#   prs=$(gh pr list --state open --limit 100 \
#     --json number,title,isDraft,mergeable,statusCheckRollup --jq '
#       sort_by(.number)[]
#       | select((.isDraft | not) and .mergeable == "MERGEABLE"
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

POLL=30

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "releng.sh: $*"; exit 1; }

# ask <prompt> <default>: the answer, lowercased. Reads the terminal, so
# it works under make.
ask() {
  local a
  printf '%s ' "$1" >/dev/tty
  read -r a </dev/tty || a=
  a="$(printf '%s' "${a:-$2}" | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$a"
}

# Rewrites the current terminal line, for a wait that would otherwise
# print a line every poll.
status() { printf '\r\033[K%s' "$*" >/dev/tty; }
status_done() { printf '\r\033[K' >/dev/tty; }

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# nums "80 81": "#80 #81"
nums() { local n out=""; for n in $1; do out="$out #$n"; done; printf "%s" "${out# }"; }

# --- the PR table ----------------------------------------------------------

# One row per open PR, oldest first:
#   number verdict detail title paths head-sha
# verdict is green, red, pending, conflicting, draft or no-checks. A check
# run carries `conclusion` ("" while it runs); a commit status only
# `state`. A PR with no checks yet is pending for its first few minutes,
# since CI takes a moment to register, and after that is reported, not
# waited on forever. mergeable is UNKNOWN while GitHub works it out,
# which is a wait too.
# shellcheck disable=SC2016  # jq, not shell
PR_JQ='
  def st: if (.conclusion // "") != "" then .conclusion
          elif (.state // "") != "" then .state
          else "PENDING" end;
  def ok: IN("SUCCESS", "SKIPPED", "NEUTRAL");
  def waiting: IN("PENDING", "EXPECTED", "QUEUED", "IN_PROGRESS",
                  "WAITING", "REQUESTED");
  sort_by(.number)[]
  | [.statusCheckRollup[] | st] as $c
  | [$c[] | select(ok | not)] as $bad
  | (if .isDraft then "draft"
     elif .mergeable == "CONFLICTING" then "conflicting"
     elif ($c | length) == 0 then
       (if (.createdAt | fromdate) > (now - 300) then "pending"
        else "no-checks" end)
     elif any($bad[]; waiting) then "pending"
     elif ($bad | length) > 0 then "red"
     elif .mergeable != "MERGEABLE" then "pending"
     else "green" end) as $v
  | ($bad | group_by(.) | map("\(length) \(.[0] | ascii_downcase)")
     | join(", ")) as $why
  | [.number, $v, (if $why == "" then "-" else $why end), .title,
     ([.files[].path | split("/") | .[0:2] | join("/")] | unique
      | join(" ")),
     .headRefOid]
  | @tsv'

ROWS=""
load() {
  ROWS="$(gh pr list --state open --limit 100 \
    --json number,title,isDraft,mergeable,statusCheckRollup,files,createdAt,headRefOid \
    --jq "$PR_JQ")"
}

# with <verdict>: the PR numbers in it, space-separated.
with() {
  printf '%s\n' "$ROWS" | awk -F'\t' -v v="$1" '$2 == v { printf "%s ", $1 }'
}

show() {
  if [ -z "$ROWS" ]; then say "No open PRs."; return; fi
  printf '%s\n' "$ROWS" | while IFS=$'\t' read -r num v why title paths _; do
    case "$v" in
      green) detail="$paths" ;;
      red)   detail="$why" ;;
      *)     detail="$paths" ;;
    esac
    printf '  #%-4s %-11s %-34s %s\n' "$num" "$v" "$title" "$detail"
  done

  # Two green PRs on one recipe: merging both is rarely what's meant.
  local dup
  dup="$(printf '%s\n' "$ROWS" |
         awk -F'\t' '$2 == "green" { print $5 }' | tr ' ' '\n' |
         grep '^utils/' | sort | uniq -d || true)"
  if [ -n "$dup" ]; then
    say ""
    say "  More than one green PR touches: $(printf '%s\n' "$dup" | paste -sd' ' -)"
  fi
}

cmd_list() { load; show; }

# --- re-running checks -----------------------------------------------------

# Re-run whatever failed on a PR's current head. --failed re-runs only
# the jobs that failed or were cancelled, not the whole matrix; a run
# GitHub won't do that for gets re-run in full.
recheck_one() {
  local n="$1" sha runs id
  sha="$(gh pr view "$n" --json headRefOid --jq .headRefOid)"
  runs="$(gh run list --commit "$sha" --limit 50 \
            --json databaseId,conclusion,workflowName \
            --jq '.[] | select(.conclusion | IN("failure", "cancelled",
                    "timed_out", "startup_failure")) | .databaseId')"
  if [ -z "$runs" ]; then
    say "  #$n: nothing failed to re-run"
    return
  fi
  for id in $runs; do
    if gh run rerun "$id" --failed >/dev/null 2>&1 ||
       gh run rerun "$id" >/dev/null; then
      say "  #$n: re-running run $id"
    else
      warn "  #$n: couldn't re-run run $id"
    fi
  done
}

cmd_recheck() {
  [ $# -gt 0 ] || die "recheck: which PR?"
  local n
  for n in "$@"; do recheck_one "${n#\#}"; done
}

cmd_recheck_fails() {
  load
  local reds; reds="$(with red)"
  if [ -z "$reds" ]; then say "No failed PRs."; return; fi
  # shellcheck disable=SC2086
  cmd_recheck $reds
}

# Until nothing is pending. A re-run takes a few seconds to show up on
# the PR, so the first poll is delayed rather than immediate.
wait_checks() {
  sleep 10
  while :; do
    load
    local p; p="$(with pending)"
    [ -n "$p" ] || break
    status "Waiting on checks: $(nums "$p")  (Ctrl-C to stop)"
    sleep "$POLL"
  done
  status_done
}

# --- merging ---------------------------------------------------------------

MERGED=0
cmd_merge() {
  local yes=0
  [ "${1:-}" = -y ] && yes=1
  [ -n "$ROWS" ] || load
  local green; green="$(with green)"
  if [ -z "$green" ]; then say "No green PRs to merge."; return 0; fi

  if [ "$yes" -eq 0 ]; then
    local a
    a="$(ask "Merge $(nums "$green")? [y/N, or numbers to leave out]" n)"
    case "$a" in
      y) ;;
      n) say "Nothing merged."; return 0 ;;
      *)
        local keep="" n
        for n in $green; do
          case " $(echo "$a" | tr -d '#,') " in
            *" $n "*) ;;
            *) keep="$keep $n" ;;
          esac
        done
        green="$keep"
        ;;
    esac
  fi

  # Carry on past a failure: an earlier merge can make a later PR
  # conflict, and that one shouldn't stop the rest.
  local n merged="" failed=""
  for n in $green; do
    if gh pr merge "$n" --merge >/dev/null; then
      merged="$merged #$n"; MERGED=$((MERGED + 1))
    else
      failed="$failed #$n"
    fi
  done
  say "Merged:${merged:- none}"
  if [ -n "$failed" ]; then warn "Not merged:$failed"; return 1; fi
}

# --- main's Build ----------------------------------------------------------

# Build on main at its current head. Merging in quick succession cancels
# all but the last push's run, which is fine: a push build covers
# everything since the last green commit.
wait_main() {
  local sha id="" state tries=0
  sha="$(gh api "repos/{owner}/{repo}/commits/main" --jq .sha)"
  while [ -z "$id" ]; do
    id="$(gh run list --workflow build.yml --branch main --commit "$sha" \
            --limit 5 --json databaseId,event \
            --jq '[.[] | select(.event != "pull_request")][0].databaseId // empty')"
    [ -n "$id" ] && break
    tries=$((tries + 1))
    [ "$tries" -le 12 ] || { status_done; warn "No Build run on main at ${sha:0:7}."; return 1; }
    status "Waiting for main's Build at ${sha:0:7} to start"
    sleep 10
  done
  while :; do
    state="$(gh run view "$id" --json status,conclusion --jq '"\(.status) \(.conclusion)"')"
    case "$state" in completed*) break ;; esac
    status "main's Build at ${sha:0:7}: ${state% *}  (Ctrl-C to stop)"
    sleep "$POLL"
  done
  status_done
  if [ "$state" = "completed success" ]; then
    say "main's Build at ${sha:0:7}: green"
  else
    warn "main's Build at ${sha:0:7}: ${state#completed } -- $(gh run view "$id" --json url --jq .url)"
    return 1
  fi
}

# --- releasing -------------------------------------------------------------

cmd_check_updates() {
  gh workflow run bump.yml
  say "Dispatched: Propose upstream bumps. New PRs appear in a few minutes."
}

# watch_release <run-id>: wait for a Release run; on a failure, offer to
# re-run its failed jobs and wait again. Most failures are a macOS
# runner that never turned up, and the publish job only runs once every
# recipe has built, so a re-run finishes the same release against the
# same tag rather than making another.
watch_release() {
  local id="$1" state
  while :; do
    while :; do
      state="$(gh run view "$id" --json status,conclusion --jq '"\(.status) \(.conclusion)"')"
      case "$state" in completed*) break ;; esac
      status "Release run $id: ${state% *}  (Ctrl-C leaves it running)"
      sleep "$POLL"
    done
    status_done
    [ "$state" != "completed success" ] || return 0

    warn "Release ${state#completed }: $(gh run view "$id" --json url --jq .url)"
    gh run view "$id" --json jobs --jq '.jobs[]
      | select(.conclusion | IN("failure", "cancelled", "timed_out"))
      | "  \(.name): \(.conclusion)"' >&2
    [ "$(ask "Re-run the failed jobs? [Y/n]" y)" = y ] || return 1
    gh run rerun "$id" --failed
    sleep 10
  done
}

# A tag with no release behind it: the run that pushed it failed after
# tagging. release-plan.sh counts from the newest tag, so without this
# the next release would skip straight past it as "nothing to release".
# Returns 1 if there was one and it still isn't released.
finish_stranded() {
  local tag sha id
  tag="$(git tag -l 'v*' --sort=-v:refname | head -1)"
  [ -n "$tag" ] || return 0
  gh release view "$tag" >/dev/null 2>&1 && return 0

  sha="$(git rev-list -n 1 "$tag")"
  id="$(gh run list --workflow release.yml --limit 30 \
          --json databaseId,headSha \
          --jq "[.[] | select(.headSha == \"$sha\")][0].databaseId // empty")"
  say ""
  if [ -z "$id" ]; then
    warn "$tag is tagged but not released, and no Release run for it was found."
    return 1
  fi
  say "$tag is tagged but not released (run $id)."
  watch_release "$id" || return 1
  say "Released $tag: $(gh release view "$tag" --json url --jq .url)"
}

cmd_release() {
  local yes=0
  [ "${1:-}" = -y ] && yes=1
  git fetch -q --tags origin main

  finish_stranded || return 1

  local prev bump next recipes shared
  eval "$(scripts/release-plan.sh origin/main)"
  if [ "$bump" = none ]; then
    say "Nothing since $prev changes an artefact: no release needed."
    return 0
  fi

  say ""
  say "Release $next ($bump) -- rebuilds: $recipes"
  [ -n "$shared" ] && say "  Y because these changed: $shared"

  local choice="$bump"
  if [ "$yes" -eq 0 ]; then
    choice="$(ask "Release? [Enter = $bump, or y/z/x to override, n to stop]" "$bump")"
    case "$choice" in
      n) say "Not released."; return 0 ;;
      y|z) choice="$(echo "$choice" | tr '[:lower:]' '[:upper:]')" ;;
      x)
        # Deliberately not one keystroke: X stays 0 (AGENTS.md), and
        # release.yml doesn't offer it.
        local x; x="${prev#v}"; x="${x%%.*}"
        say "release.yml doesn't do X. Tag by hand if you mean it:"
        say "  git tag -a v$((x + 1)).0.0 origin/main -m 'v$((x + 1)).0.0' && git push origin v$((x + 1)).0.0"
        return 0 ;;
      *) choice="$(echo "$choice" | tr '[:lower:]' '[:upper:]')" ;;
    esac
    case "$choice" in Y|Z) ;; *) die "not a bump: $choice" ;; esac
  fi

  local since; since="$(now_utc)"
  gh workflow run release.yml -f bump="$choice" >/dev/null
  say "Dispatched Release ($choice)."

  # gh doesn't hand back the run it started; it's the newest dispatch
  # since we asked.
  local id="" tries=0
  while [ -z "$id" ]; do
    sleep 5
    id="$(gh run list --workflow release.yml --event workflow_dispatch \
            --limit 5 --json databaseId,createdAt \
            --jq "[.[] | select(.createdAt >= \"$since\")][0].databaseId // empty")"
    tries=$((tries + 1))
    [ -n "$id" ] || [ "$tries" -le 12 ] || die "can't find the Release run"
  done
  watch_release "$id" || exit 1
  git fetch -q --tags origin
  local tag; tag="$(git tag -l 'v*' --sort=-v:refname | head -1)"
  say "Released $tag: $(gh release view "$tag" --json url --jq .url 2>/dev/null || echo "$tag")"
}

# --- the round -------------------------------------------------------------

cmd_cycle() {
  load
  show
  [ -n "$ROWS" ] || { cmd_release; return; }

  while :; do
    if [ -n "$(with pending)" ]; then
      wait_checks; say ""; show
      continue
    fi
    local reds; reds="$(with red)"
    [ -n "$reds" ] || break
    say ""
    [ "$(ask "Re-run the failed checks on $(nums "$reds")? [Y/n]" y)" = y ] || break
    # shellcheck disable=SC2086
    cmd_recheck $reds
    wait_checks; say ""; show
  done

  say ""
  cmd_merge || true
  if [ "$MERGED" -gt 0 ]; then
    wait_main || return 1
  fi
  cmd_release
}

case "${1:-cycle}" in
  cycle)          cmd_cycle ;;
  list)           cmd_list ;;
  merge)          shift; cmd_merge "$@" ;;
  recheck)        shift; cmd_recheck "$@" ;;
  recheck-fails)  cmd_recheck_fails ;;
  check-updates)  cmd_check_updates ;;
  release)        shift; cmd_release "$@" ;;
  *) sed -n '2,10s/^# \{0,1\}//p' "$0"; exit 2 ;;
esac
