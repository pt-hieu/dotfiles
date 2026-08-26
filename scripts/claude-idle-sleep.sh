#!/usr/bin/env bash
#
# Sleep the Mac once every Claude Code session has finished working.
#
# Modes:
#   check            Print the report and exit. No side effect. (default)
#   sleep            Check once, then sleep the machine if it is idle.
#   watch [minutes]  Check every N minutes (default 15) and sleep when idle.
#
# Exit codes for `check` and `sleep`:
#   0  IDLE    every session is at its prompt and the guards pass
#   1  BUSY    at least one guard says no
#   2  ASLEEP  the machine is already asleep or in a scheduled dark wake
#
# Thresholds (flag or environment variable):
#   --quiet-minutes N   TRANSCRIPT_QUIET_MINUTES   default 10
#   --user-idle N       USER_IDLE_SECONDS          default 300
#   --delay N           SLEEP_DELAY_SECONDS        default 5

set -uo pipefail

TRANSCRIPT_QUIET_MINUTES=${TRANSCRIPT_QUIET_MINUTES:-10}
USER_IDLE_SECONDS=${USER_IDLE_SECONDS:-300}
SLEEP_DELAY_SECONDS=${SLEEP_DELAY_SECONDS:-5}
WATCH_MINUTES=15
MODE=check
VERBOSE=1

# Print the header comment block, stopping at the first line of real code.
usage() {
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
}

die() {
  echo "claude-idle-sleep: $*" >&2
  exit 64
}

if [ "$(uname -s)" != "Darwin" ]; then
  die "macOS only. It relies on pmset, ioreg and BSD stat."
fi

while [ $# -gt 0 ]; do
  case "$1" in
    check|sleep|watch)
      MODE=$1
      shift
      # `watch` takes an optional bare number as its interval.
      if [ "$MODE" = watch ] && [ $# -gt 0 ] && [[ $1 =~ ^[0-9]+$ ]]; then
        WATCH_MINUTES=$1
        shift
      fi
      ;;
    --quiet-minutes) TRANSCRIPT_QUIET_MINUTES=${2:?needs a value}; shift 2 ;;
    --user-idle)     USER_IDLE_SECONDS=${2:?needs a value}; shift 2 ;;
    --delay)         SLEEP_DELAY_SECONDS=${2:?needs a value}; shift 2 ;;
    -q|--quiet)      VERBOSE=0; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               die "unknown argument '$1'. Try --help." ;;
  esac
done

# The session running this check is busy by definition, so it must not veto its
# own sleep. Claude Code exports CLAUDE_PID; fall back to walking the process
# tree when the script is launched some other way.
find_own_claude_pid() {
  local pid=$$
  while [ "$pid" -gt 1 ]; do
    if [ "$(ps -o comm= -p "$pid" 2>/dev/null | xargs)" = "claude" ]; then
      echo "$pid"
      return
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$pid" ] && break
  done
}

# A scheduled DarkWake (maintenance, RTC, push notification) runs with the
# display off and returns to sleep on its own. Sleeping again there only cuts
# the maintenance window short. Only a plain "Wake" means genuinely awake.
last_power_event() {
  pmset -g log 2>/dev/null \
    | grep -E '^[0-9-]+ [0-9:]+ \+[0-9]+[[:space:]]+(Sleep|Wake|DarkWake)[[:space:]]' \
    | tail -1 | awk '{print $4}'
}

REPORT=""
VERDICT=""
REASON=""

# Sets REPORT, VERDICT and REASON. Returns 0 idle, 1 busy, 2 already asleep.
run_check() {
  local own_claude_pid own_session_id claude_pid
  local -a busy_sessions=() idle_sessions=() blockers=()

  own_claude_pid=${CLAUDE_PID:-$(find_own_claude_pid)}
  own_claude_pid=${own_claude_pid:-__no_own_pid__}

  # Claude Code holds a `caffeinate` child for the whole time it is working and
  # kills it on return to the prompt. No caffeinate child means idle.
  for claude_pid in $(pgrep -x claude); do
    [ "$claude_pid" = "$own_claude_pid" ] && continue
    if pgrep -P "$claude_pid" -x caffeinate >/dev/null 2>&1; then
      busy_sessions+=("$claude_pid")
    else
      idle_sessions+=("$claude_pid")
    fi
  done

  # A running session appends to its transcript constantly, so its own file
  # would always look fresh. lsof cannot find it -- Claude Code closes the file
  # between appends -- but the session id appears in the path of both the
  # session transcript and its subagent transcripts.
  own_session_id=${CLAUDE_CODE_SESSION_ID:-__no_own_session__}

  local newest_epoch now_epoch transcript_quiet_seconds
  newest_epoch=$(find "$HOME/.claude/projects" -name '*.jsonl' -print0 2>/dev/null \
    | xargs -0 stat -f '%m %N' 2>/dev/null \
    | grep -v -F "$own_session_id" \
    | sort -rn | head -1 | cut -d' ' -f1)
  now_epoch=$(date +%s)
  transcript_quiet_seconds=$(( now_epoch - ${newest_epoch:-0} ))

  local user_idle
  user_idle=$(ioreg -c IOHIDSystem 2>/dev/null \
    | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
  user_idle=${user_idle:-0}

  [ ${#busy_sessions[@]} -gt 0 ] \
    && blockers+=("${#busy_sessions[@]} session(s) working")
  [ "$transcript_quiet_seconds" -lt $(( TRANSCRIPT_QUIET_MINUTES * 60 )) ] \
    && blockers+=("transcript written ${transcript_quiet_seconds}s ago")
  [ "$user_idle" -lt "$USER_IDLE_SECONDS" ] \
    && blockers+=("user active ${user_idle}s ago")

  # `pmset -g log` parses the whole power history and takes about 7 seconds, so
  # only consult it when every cheap guard has already passed and we are about
  # to sleep. A busy machine never pays that cost.
  local power_event=skipped
  if [ ${#blockers[@]} -eq 0 ]; then
    power_event=$(last_power_event)
    power_event=${power_event:-unknown}
  fi

  REPORT=$(cat <<EOF
own_session_pid=$own_claude_pid own_session_id=$own_session_id
busy_sessions=${busy_sessions[*]:-none} (${#busy_sessions[@]})
idle_sessions=${idle_sessions[*]:-none} (${#idle_sessions[@]})
transcript_quiet_seconds=$transcript_quiet_seconds (threshold $(( TRANSCRIPT_QUIET_MINUTES * 60 )))
user_idle_seconds=$user_idle (threshold $USER_IDLE_SECONDS)
last_power_event=$power_event
EOF
)

  if [ ${#blockers[@]} -gt 0 ]; then
    VERDICT=BUSY
    REASON=$(IFS='; '; echo "${blockers[*]}")
    return 1
  fi

  # A scheduled dark wake returns to sleep on its own; sleeping again there
  # only cuts the maintenance window short.
  if [ "$power_event" != Wake ] && [ "$power_event" != unknown ]; then
    VERDICT=ASLEEP
    REASON="already asleep ($power_event)"
    return 2
  fi

  VERDICT=IDLE
  REASON="${#idle_sessions[@]} session(s) idle"
  return 0
}

sleep_now() {
  if [ "$SLEEP_DELAY_SECONDS" -gt 0 ]; then
    echo "Sleeping in ${SLEEP_DELAY_SECONDS}s. Ctrl-C to cancel."
    command sleep "$SLEEP_DELAY_SECONDS"
  fi
  pmset sleepnow
}

case "$MODE" in
  check)
    run_check
    status=$?
    [ "$VERBOSE" -eq 1 ] && echo "$REPORT"
    echo "VERDICT=$VERDICT reason=$REASON"
    exit $status
    ;;

  sleep)
    run_check
    status=$?
    [ "$VERBOSE" -eq 1 ] && echo "$REPORT"
    echo "VERDICT=$VERDICT reason=$REASON"
    [ $status -eq 0 ] && sleep_now
    exit $status
    ;;

  watch)
    echo "Watching every ${WATCH_MINUTES}m. Sleeps once every Claude session is idle. Ctrl-C to stop."
    while true; do
      run_check
      printf '[%s] %s — %s\n' "$(date '+%H:%M:%S')" "$VERDICT" "$REASON"
      if [ "$VERDICT" = IDLE ]; then
        sleep_now
      fi
      command sleep $(( WATCH_MINUTES * 60 ))
    done
    ;;
esac
