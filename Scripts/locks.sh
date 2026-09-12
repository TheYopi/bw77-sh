#!/usr/bin/env bash
# Watches the keyboard lock LEDs and prints a line only when something changes.
#
#   usage: locks.sh [interval_seconds]      # fractional, e.g. 0.05
#
# Output is three characters - caps, num, scroll, each 0 or 1 - or the word
# "none" when the machine exposes no lock LEDs at all.
#
# Why a long-running watcher rather than a poll from QML:
#
# There is no change notification on sysfs LED nodes (inotify does not fire on
# them), so something has to look repeatedly. Doing that from QML meant forking
# a shell - plus a `cat` per LED per keyboard - on every tick, which is why the
# old sampler could only afford to run three times a second when idle. At that
# rate the first press of Caps Lock took up to a third of a second to show, and
# a quick double-tap landed inside one interval and was never seen at all.
#
# Here the process is started once and the hot loop does no forking whatsoever:
# the node paths are resolved up front, the values are read with the `read`
# builtin and its redirect, and the wait between ticks is a timed read on a
# pipe nobody writes to rather than a call to `sleep`. That makes a 50ms tick
# cost less than the old 300ms one, so lock keys land as promptly as volume.
#
# Only changes are printed, so a quiet keyboard produces no output and no work
# on the QML side.

interval="${1:-0.05}"

# How often to look for keyboards that were not there at startup, in ticks.
# The LED node is named after the input device and the number is assigned at
# plug time, so an external keyboard connected later has paths that did not
# exist when this started.
rescan_every=40

# --- fork-free wait
#
# `read -t` needs a descriptor that stays open and never delivers anything.
# A fifo held open for both reading and writing is exactly that: no writer ever
# sends a byte, and because this process also holds the write end there is no
# EOF to return early on. Falls back to `sleep` if a fifo cannot be made, which
# still works, just with one fork per tick.
nap_fd_ready=0
fifo="$(mktemp -u 2>/dev/null)" || fifo=""
if [ -n "$fifo" ] && mkfifo "$fifo" 2>/dev/null; then
  exec 9<>"$fifo"
  rm -f "$fifo"
  nap_fd_ready=1
fi

nap() {
  if [ "$nap_fd_ready" = 1 ]; then
    # Returns non-zero on timeout, which is the expected path.
    read -r -t "$interval" -u 9 _ 2>/dev/null
    return 0
  fi
  sleep "$interval"
}

# --- node discovery
caps_files=()
num_files=()
scroll_files=()

rescan() {
  caps_files=()
  num_files=()
  scroll_files=()

  # A laptop typically has several keyboards and only one carries the LEDs, so
  # every match is collected and the results OR-ed. An unmatched glob comes
  # back as the literal pattern, which the -r test rejects.
  for f in /sys/class/leds/*::capslock/brightness; do
    [ -r "$f" ] && caps_files+=("$f")
  done
  for f in /sys/class/leds/*::numlock/brightness; do
    [ -r "$f" ] && num_files+=("$f")
  done
  for f in /sys/class/leds/*::scrolllock/brightness; do
    [ -r "$f" ] && scroll_files+=("$f")
  done
}

# Sets CUR. Deliberately not a command substitution: `$(...)` forks a subshell,
# which is the cost this whole file exists to avoid.
CUR=""

read_locks() {
  local f r v
  CUR=""

  v=0
  for f in "${caps_files[@]}"; do
    read -r r < "$f" 2>/dev/null || continue
    [ "$r" != "0" ] && { v=1; break; }
  done
  CUR="$CUR$v"

  v=0
  for f in "${num_files[@]}"; do
    read -r r < "$f" 2>/dev/null || continue
    [ "$r" != "0" ] && { v=1; break; }
  done
  CUR="$CUR$v"

  v=0
  for f in "${scroll_files[@]}"; do
    read -r r < "$f" 2>/dev/null || continue
    [ "$r" != "0" ] && { v=1; break; }
  done
  CUR="$CUR$v"
}

rescan

last=""
ticks=0

# Quickshell ignores SIGPIPE and children inherit that, so a write to a shell
# that has gone fails instead of killing this - and this writes only when a
# LED changes, so an orphaned copy may never write at all. It has to notice
# its parent is gone by asking. `kill -0` is a builtin: a syscall, no fork.
while :; do
  kill -0 "$PPID" 2>/dev/null || exit 0

  if [ ${#caps_files[@]} -eq 0 ] \
     && [ ${#num_files[@]} -eq 0 ] \
     && [ ${#scroll_files[@]} -eq 0 ]; then
    if [ "$last" != "none" ]; then
      printf 'none\n' || exit 0
      last="none"
    fi
  else
    read_locks
    if [ "$CUR" != "$last" ]; then
      printf '%s\n' "$CUR" || exit 0
      last="$CUR"
    fi
  fi

  ticks=$(( ticks + 1 ))
  if [ $(( ticks % rescan_every )) -eq 0 ]; then
    rescan
  fi

  nap
done
