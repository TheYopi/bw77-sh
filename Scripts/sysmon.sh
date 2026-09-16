#!/usr/bin/env bash
# Emits one JSON object per interval on stdout. Kept in shell so the shell
# process itself never blocks on /proc reads.
#
# usage: sysmon.sh [interval_seconds]     # fractional is fine, e.g. 0.1
#
# --- the hot loop does not fork
#
# This is the one backend process that runs for the whole session: the bar's
# system widget holds it open from login to logout, and the gauges push it to
# ten ticks a second whenever a popup is on screen. So the cost of a single
# tick is multiplied by roughly a million a day, and anything forked inside the
# loop is paid for at that rate.
#
# It used to fork five times per tick - an awk for /proc/meminfo, an awk for
# /proc/net/dev, an awk for /proc/loadavg, a cat for the temperature, and a
# sleep - which at the idle rate alone is ten processes a second spawned to
# read four files that bash can read by itself. All five are gone: the readings
# are parsed with the `read` builtin and its redirect, and the wait between
# ticks is a timed read on a pipe nobody writes to, the same trick locks.sh
# uses. A tick now costs no processes at all.
#
# Two readings are still forked, and still only on the slow cycle: /proc/cpuinfo
# is a few hundred lines to average one number out of - more work for bash than
# for awk - and `df` is a program, not a file. Neither changes meaningfully ten
# times a second, so they refresh roughly once a second and hold their previous
# value in between.

interval="${1:-2}"

# --- fork-free wait
#
# `read -t` needs a descriptor that stays open and never delivers anything. A
# fifo held open for both reading and writing is exactly that: no writer ever
# sends a byte, and because this process also holds the write end there is no
# EOF to return early on. Falls back to `sleep` if a fifo cannot be made, which
# still works, just with the fork back.
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

# Pick a temperature source once, preferring CPU package sensors.
temp_file=""
for c in /sys/class/hwmon/hwmon*; do
  [ -r "$c/name" ] || continue
  read -r name < "$c/name" 2>/dev/null || continue
  case "$name" in
    k10temp|coretemp|zenpower|cpu_thermal|acpitz)
      for t in "$c"/temp1_input "$c"/temp2_input; do
        [ -r "$t" ] && { temp_file="$t"; break; }
      done
      ;;
  esac
  [ -n "$temp_file" ] && break
done
[ -z "$temp_file" ] && [ -r /sys/class/thermal/thermal_zone0/temp ] \
  && temp_file=/sys/class/thermal/thermal_zone0/temp

prev_total=0; prev_idle=0
prev_rx=0; prev_tx=0; prev_ms=0

# Last computed throughput, held between ticks. See the note where these are
# recalculated: at sub-second intervals most ticks are too close together to
# measure across, and the answer then is to repeat the last real figure rather
# than to report zero.
dl=0; ul=0
first=1
clock=0
disk=0

# ---- Memory, without awk
#
# Four numbers out of a file whose first fifteen lines carry all of them, so
# the loop stops at SwapFree rather than reading the remaining forty. Sets the
# four globals directly: a command substitution to return them would be a
# subshell, which is the fork this exists to avoid.
mem_total_kb=0; mem_used_kb=0; mem_pct=0; swap_pct=0

read_meminfo() {
  local key value avail=0 swap_total=0 swap_free=0
  mem_total_kb=0

  while read -r key value _; do
    case "$key" in
      MemTotal:)     mem_total_kb=$value ;;
      MemAvailable:) avail=$value ;;
      SwapTotal:)    swap_total=$value ;;
      SwapFree:)     swap_free=$value; break ;;
    esac
  done < /proc/meminfo

  mem_used_kb=$(( mem_total_kb - avail ))
  [ "$mem_used_kb" -lt 0 ] && mem_used_kb=0
  mem_pct=0
  [ "$mem_total_kb" -gt 0 ] && mem_pct=$(( mem_used_kb * 100 / mem_total_kb ))
  swap_pct=0
  [ "$swap_total" -gt 0 ] \
    && swap_pct=$(( (swap_total - swap_free) * 100 / swap_total ))
}

# ---- Network counters, without awk
#
# The two header lines carry a "|" and no ":", which is what filters them. The
# colon is turned into a space before splitting rather than trimmed off the
# name: the kernel prints this with "%6s:%8llu", so an interface whose name is
# longer than six characters and whose byte count needs more than eight digits
# has nothing between the two - "enp34s0:12345678901" - and splitting on
# whitespace alone would read the whole thing as the name and find no counters.
rx_total=0; tx_total=0

read_netdev() {
  local line
  rx_total=0; tx_total=0

  while read -r line; do
    case "$line" in *:*) ;; *) continue ;; esac
    # Unquoted, because splitting the line into fields is the point - with
    # globbing off for the duration so an interface name could never be
    # expanded against the filesystem on its way through.
    set -f
    set -- ${line/:/ }
    set +f
    [ "$#" -ge 10 ] || continue
    [ "$1" = "lo" ] && continue
    rx_total=$(( rx_total + $2 ))
    tx_total=$(( tx_total + ${10} ))
  done < /proc/net/dev
}

# Ticks between refreshes of the expensive readings. At 0.1s that is once a
# second; at 2s it is every tick, which is what it always used to be.
slow_every=$(awk -v i="$interval" 'BEGIN { n = int(1 / i); if (n < 1) n = 1; print n }')
slow=0

while :; do
  # ---- CPU load
  read -r _ u n s i io irq sirq st _ < /proc/stat
  total=$((u+n+s+i+io+irq+sirq+st))
  idle=$((i+io))
  d_total=$((total-prev_total))
  d_idle=$((idle-prev_idle))
  cpu=0
  [ "$d_total" -gt 0 ] && cpu=$(( (100*(d_total-d_idle))/d_total ))
  prev_total=$total; prev_idle=$idle

  # ---- the slow cycle
  #
  # Whether this tick takes the expensive readings. Decided once at the top so
  # the two of them stay on the same cycle, and - the part that was wrong - the
  # counter is reloaded here, where the work is actually done.
  #
  # It used to be reloaded at the bottom of the loop, unconditionally, which
  # meant it was topped back up on the tick before it would have reached zero
  # and so never reached zero at all. The clock and the disk figure were read
  # on the very first tick and then held for the life of the process: a bar
  # that had been up for an hour was still reporting the CPU frequency from the
  # moment it started, and a disk that had filled up since login never said so.
  slow_tick=0
  if [ "$slow" -le 0 ]; then
    slow_tick=1
    slow=$slow_every
  fi
  slow=$((slow - 1))

  # ---- CPU clock (average across cores, MHz), on the slow cycle
  if [ "$slow_tick" = 1 ]; then
    clock=$(awk '/^cpu MHz/ {sum+=$4; n++} END {if(n) printf "%d", sum/n; else print 0}' /proc/cpuinfo)
  fi

  # ---- Memory
  read_meminfo

  # ---- Temperature
  temp=0
  if [ -n "$temp_file" ]; then
    read -r raw < "$temp_file" 2>/dev/null && temp=$((raw/1000))
  fi

  # ---- Network throughput (all interfaces except loopback)
  read_netdev
  rx=$rx_total; tx=$tx_total
  #
  # Throughput is a rate, so it needs a real elapsed time - and the clock this
  # used was whole seconds from `date +%s` while the loop runs ten times a
  # second. Two things went wrong with that. The guard `now > prev_time` was
  # false on nine ticks out of ten, so both rates reported a flat 0 for 90% of
  # samples; and prev_rx/prev_time were reassigned on every tick regardless, so
  # on the tenth - the one that did report - the byte delta covered only the
  # last 100ms while the divisor was a whole second. The figure that got
  # through was therefore about a tenth of the truth, arriving in a stream of
  # zeroes. On a download that is mostly idle-looking with occasional spikes;
  # on a steady upload of small packets it rounds to nothing at all.
  #
  # EPOCHREALTIME is bash's own microsecond clock and costs no fork. The
  # baseline only moves when a rate is actually computed, so the delta and the
  # divisor always describe the same interval.
  #
  now_ms=$(( ${EPOCHREALTIME/./} / 1000 ))

  if [ "$prev_ms" -gt 0 ]; then
    span=$(( now_ms - prev_ms ))
    # Below this the byte counters have not moved enough to divide by without
    # the result being mostly quantisation noise. Under it, the previous
    # figures stand.
    if [ "$span" -ge 500 ]; then
      dl=$(( (rx - prev_rx) * 1000 / span ))
      ul=$(( (tx - prev_tx) * 1000 / span ))
      [ "$dl" -lt 0 ] && dl=0
      [ "$ul" -lt 0 ] && ul=0
      prev_rx=$rx; prev_tx=$tx; prev_ms=$now_ms
    fi
  else
    prev_rx=$rx; prev_tx=$tx; prev_ms=$now_ms
  fi

  # ---- Disk (root filesystem)
  # Also on the slow cycle: df forks and a root filesystem does not fill up
  # ten times a second.
  if [ "$slow_tick" = 1 ]; then
    disk=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
  fi

  # ---- Load average
  read -r load _ < /proc/loadavg

  if [ "$first" -eq 0 ]; then
    printf '{"cpu":%d,"clock":%d,"temp":%d,"mem":%d,"memUsedKb":%d,"memTotalKb":%d,"swap":%d,"down":%d,"up":%d,"disk":%s,"load":%s}\n' \
      "$cpu" "$clock" "$temp" "$mem_pct" "$mem_used_kb" "$mem_total_kb" "$swap_pct" "$dl" "$ul" "${disk:-0}" "${load:-0}" \
      || exit 0
  fi
  first=0

  # Gone with the shell. Quickshell ignores SIGPIPE and its children inherit
  # that, so a failed write alone does not end an orphaned copy - see netbt.sh.
  kill -0 "$PPID" 2>/dev/null || exit 0
  nap
done
