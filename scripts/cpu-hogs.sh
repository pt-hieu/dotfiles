#!/usr/bin/env bash
#
# Find and kill runaway CPU processes — the orphans a dead tool session left
# spinning. Measures real CPU time burned over a sampling window rather than
# trusting the decaying average in `ps %cpu`, so a process that already calmed
# down is not reported.
#
# Modes:
#   check           Print the report and exit. No side effect. (default)
#   kill [pid...]   Kill the runaways, or exactly the pids you name.
#
# A process is a RUNAWAY only when all of these hold:
#   - it burns >= --threshold percent of one core across the sample window
#   - it belongs to you (never another user's, never a system daemon)
#   - its parent has died and it was reparented to init
#   - it holds no controlling terminal, so nothing is waiting on its output
#   - it is a shell or interpreter, not a GUI app — launchd parents every app,
#     so orphanhood alone would condemn your browser
#   - it has been alive for >= --min-age minutes
#
# Anything else that is merely busy is reported as BUSY and left alone. Kill
# those by naming their pids, or with --all.
#
# Exit codes:
#   0  nothing runaway (check) / everything killed (kill)
#   1  runaways found (check) / something survived (kill)
#
# Flags (or environment variable):
#   --threshold N   CPU_HOGS_THRESHOLD   min CPU%% of one core   default 50
#   --sample N      CPU_HOGS_SAMPLE      sample window seconds   default 3
#   --min-age N     CPU_HOGS_MIN_AGE     min minutes alive       default 2
#   --all           Treat your busy parented processes as killable too.
#   --full          Print whole command lines instead of truncating.
#   -y, --yes       Skip the confirmation prompt.

set -uo pipefail

THRESHOLD=${CPU_HOGS_THRESHOLD:-50}
SAMPLE=${CPU_HOGS_SAMPLE:-3}
MIN_AGE=${CPU_HOGS_MIN_AGE:-2}
MODE=check
INCLUDE_PARENTED=0
FULL=0
ASSUME_YES=0
NAMED_PIDS=""

FIELD_SEP=$'\x1f'

usage() {
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
}

die() {
  echo "cpu-hogs: $*" >&2
  exit 64
}

while [ $# -gt 0 ]; do
  case "$1" in
    check|kill)   MODE=$1; shift ;;
    --threshold)  THRESHOLD=${2:?needs a value}; shift 2 ;;
    --sample)     SAMPLE=${2:?needs a value}; shift 2 ;;
    --min-age)    MIN_AGE=${2:?needs a value}; shift 2 ;;
    --all)        INCLUDE_PARENTED=1; shift ;;
    --full)       FULL=1; shift ;;
    -y|--yes)     ASSUME_YES=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    [0-9]*)       NAMED_PIDS="$NAMED_PIDS $1"; shift ;;
    *)            die "unknown argument '$1'. Try --help." ;;
  esac
done

# Killing an ancestor kills the shell running this script, and on the way out
# the terminal too. Collect the whole chain up to init and never touch it.
own_ancestry() {
  local pid=$$ chain=""
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
    chain="$chain,$pid"
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  echo "${chain#,}"
}

humanize_age() {
  local secs=$1
  if   [ "$secs" -ge 86400 ]; then printf '%dd%dh' $(( secs / 86400 )) $(( secs % 86400 / 3600 ))
  elif [ "$secs" -ge 3600 ];  then printf '%dh%dm' $(( secs / 3600 ))  $(( secs % 3600 / 60 ))
  elif [ "$secs" -ge 60 ];    then printf '%dm'    $(( secs / 60 ))
  else                             printf '%ds'    "$secs"
  fi
}

SNAPSHOT_BEFORE=$(mktemp -t cpu-hogs) || die "cannot create temp file"
SNAPSHOT_AFTER=$(mktemp -t cpu-hogs)  || die "cannot create temp file"
trap 'rm -f "$SNAPSHOT_BEFORE" "$SNAPSHOT_AFTER"' EXIT

# Two snapshots of accumulated CPU time. The difference over a known wall-clock
# window is the process's real current CPU draw; `ps %cpu` is a decaying
# average that stays high for minutes after a process goes quiet.
ps -axo pid=,cputime= > "$SNAPSHOT_BEFORE"
sleep "$SAMPLE"
ps -axo pid=,ppid=,uid=,cputime=,etime=,tty=,command= > "$SNAPSHOT_AFTER"

CANDIDATES=$(awk \
  -v sample="$SAMPLE" \
  -v threshold="$THRESHOLD" \
  -v min_age_minutes="$MIN_AGE" \
  -v my_uid="$(id -u)" \
  -v ancestry="$(own_ancestry)" \
  -v sep="$FIELD_SEP" '
  # Handles every ps duration shape: DD-HH:MM:SS, HH:MM:SS, MM:SS.ss. The
  # minutes field legitimately exceeds 60 in cputime (259:32.31), which the
  # arithmetic below already treats as plain minutes.
  function to_secs(t,   parts, chunk, count, days) {
    days = 0
    if (t ~ /-/) { split(t, parts, "-"); days = parts[1]; t = parts[2] }
    count = split(t, chunk, ":")
    if (count == 3) return days * 86400 + chunk[1] * 3600 + chunk[2] * 60 + chunk[3]
    if (count == 2) return days * 86400 + chunk[1] * 60 + chunk[2]
    return days * 86400 + t
  }

  BEGIN {
    split(ancestry, own, ",")
    for (i in own) protected[own[i]] = 1
  }

  NR == FNR { cpu_before[$1] = to_secs($2); next }

  {
    pid = $1; ppid = $2; uid = $3
    cpu_after = to_secs($4); age_seconds = to_secs($5); tty = $6
    command = $0
    sub(/^ *([^ ]+ +){6}/, "", command)

    if (pid in protected) next
    if (!(pid in cpu_before)) next

    cpu_percent = (cpu_after - cpu_before[pid]) / sample * 100
    if (cpu_percent < threshold) next

    orphaned = (ppid == 1)
    detached = (tty ~ /^\?+$/ || tty == "-")

    executable = command
    sub(/ .*$/, "", executable)
    sub(/^.*\//, "", executable)

    # launchd starts every GUI app, so a browser always looks orphaned and
    # always lacks a tty. Those two signals alone would mark Chrome a runaway
    # the moment it got busy. What a dead tool session actually strands is a
    # shell or an interpreter, so auto-kill is limited to those; anything else
    # is reported and needs an explicit pid or --all.
    app_bundle = (command ~ /\.app\/Contents\//)
    interpreter = (executable ~ /^(zsh|bash|sh|dash|fish|ksh|tcsh|csh|node|deno|bun|python[0-9.]*|ruby|perl|php|java|make|cargo|tsc|esbuild|vitest|jest|find|rg|grep)$/)

    if (uid != my_uid) {
      verdict = "SYSTEM"; reason = "another user owns it"
    } else if (!orphaned) {
      verdict = "BUSY"; reason = "live parent (pid " ppid ")"
    } else if (!detached) {
      verdict = "BUSY"; reason = "orphaned but still holds tty " tty
    } else if (app_bundle) {
      verdict = "BUSY"; reason = "GUI app — launchd is its parent by design"
    } else if (!interpreter) {
      verdict = "BUSY"; reason = "orphaned, but not a shell or interpreter"
    } else if (age_seconds < min_age_minutes * 60) {
      verdict = "BUSY"; reason = "orphaned but younger than --min-age"
    } else {
      verdict = "RUNAWAY"; reason = "orphaned " executable ", no terminal"
    }

    printf "%d%s%.0f%s%d%s%s%s%s%s%s\n", \
      pid, sep, cpu_percent, sep, age_seconds, sep, verdict, sep, reason, sep, command
  }
' "$SNAPSHOT_BEFORE" "$SNAPSHOT_AFTER" | sort -t"$FIELD_SEP" -k2 -rn)

if [ -z "$CANDIDATES" ]; then
  echo "No process is burning >=${THRESHOLD}% of a core. Nothing to do."
  exit 0
fi

width=$(tput cols 2>/dev/null || echo 100)
command_width=$(( width - 42 ))
[ "$command_width" -lt 20 ] && command_width=20

printf '%-7s %6s %7s %-8s %s\n' PID CPU AGE VERDICT COMMAND
KILL_LIST=""
while IFS="$FIELD_SEP" read -r pid cpu age verdict reason command; do
  [ -z "$pid" ] && continue

  if [ -n "$NAMED_PIDS" ]; then
    case " $NAMED_PIDS " in *" $pid "*) selected=1 ;; *) selected=0 ;; esac
  elif [ "$verdict" = RUNAWAY ]; then
    selected=1
  elif [ "$verdict" = BUSY ] && [ "$INCLUDE_PARENTED" -eq 1 ]; then
    selected=1
  else
    selected=0
  fi
  [ "$selected" -eq 1 ] && KILL_LIST="$KILL_LIST $pid"

  shown=$command
  [ "$FULL" -eq 0 ] && [ ${#shown} -gt "$command_width" ] \
    && shown="${shown:0:$command_width}…"

  printf '%-7s %5s%% %7s %-8s %s\n' \
    "$pid" "$cpu" "$(humanize_age "$age")" "$verdict" "$shown"
  printf '%-7s %6s %7s %-8s └─ %s\n' '' '' '' '' "$reason"
done <<< "$CANDIDATES"

KILL_LIST=$(echo "$KILL_LIST" | xargs 2>/dev/null)

if [ "$MODE" = check ]; then
  if [ -n "$KILL_LIST" ]; then
    echo
    echo "Runaways: $KILL_LIST"
    echo "Kill them with: cpu-hogs kill"
    exit 1
  fi
  exit 0
fi

if [ -z "$KILL_LIST" ]; then
  echo
  echo "Nothing selected to kill. Name pids explicitly, or use --all."
  exit 0
fi

echo
if [ "$ASSUME_YES" -eq 0 ]; then
  printf 'Kill %s? [y/N] ' "$KILL_LIST"
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Left alone."; exit 0 ;;
  esac
fi

# TERM lets a process run its own cleanup; a spin loop that ignores it gets
# KILL on the second pass.
kill -TERM $KILL_LIST 2>/dev/null
sleep 2

survivors=""
for pid in $KILL_LIST; do
  kill -0 "$pid" 2>/dev/null && survivors="$survivors $pid"
done

if [ -n "$survivors" ]; then
  echo "Ignored TERM, sending KILL:$survivors"
  kill -KILL $survivors 2>/dev/null
  sleep 1
fi

still_alive=""
for pid in $KILL_LIST; do
  kill -0 "$pid" 2>/dev/null && still_alive="$still_alive $pid"
done

if [ -n "$still_alive" ]; then
  echo "Survived:$still_alive"
  exit 1
fi

echo "Killed: $KILL_LIST"
echo "Load average decays over minutes — check with 'uptime', not instantly."
