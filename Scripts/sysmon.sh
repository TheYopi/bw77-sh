#!/usr/bin/env bash
# Emits one JSON object per interval on stdout. Kept in shell so the shell
# process itself never blocks on /proc reads.
#
# usage: sysmon.sh [interval_seconds]     # fractional is fine, e.g. 0.1
#
# At sub-second intervals the per-tick cost matters, so the two readings that
# are expensive and slow-moving are not taken every time. /proc/cpuinfo is a
# few hundred lines to average one number out of, and `df` forks; neither
# changes meaningfully ten times a second. They refresh roughly once a second
# and hold their previous value in between.

interval="${1:-2}"

# Pick a temperature source once, preferring CPU package sensors.
temp_file=""
for c in /sys/class/hwmon/hwmon*; do
  [ -r "$c/name" ] || continue
  name="$(cat "$c/name" 2>/dev/null)"
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

  # ---- CPU clock (average across cores, MHz), on the slow cycle
  if [ "$slow" -le 0 ]; then
    clock=$(awk '/^cpu MHz/ {sum+=$4; n++} END {if(n) printf "%d", sum/n; else print 0}' /proc/cpuinfo)
  fi

  # ---- Memory
  mem=$(awk '
    /^MemTotal:/     {t=$2}
    /^MemAvailable:/ {a=$2}
    /^SwapTotal:/    {st=$2}
    /^SwapFree:/     {sf=$2}
    END {
      used=t-a
      pct=(t>0)? int(used*100/t) : 0
      spct=(st>0)? int((st-sf)*100/st) : 0
      printf "%d %d %d %d", pct, used, t, spct
    }' /proc/meminfo)
  set -- $mem
  mem_pct=$1; mem_used_kb=$2; mem_total_kb=$3; swap_pct=$4

  # ---- Temperature
  temp=0
  if [ -n "$temp_file" ] && [ -r "$temp_file" ]; then
    raw=$(cat "$temp_file" 2>/dev/null || echo 0)
    temp=$((raw/1000))
  fi

  # ---- Network throughput (all interfaces except loopback)
  netline=$(awk -F'[: ]+' '
    NR>2 && $2 != "lo" {rx+=$3; tx+=$11}
    END {printf "%d %d", rx, tx}' /proc/net/dev)
  set -- $netline
  rx=$1; tx=$2
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
  if [ "$slow" -le 0 ]; then
    disk=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
  fi

  # ---- Load average
  load=$(awk '{print $1}' /proc/loadavg)

  if [ "$first" -eq 0 ]; then
    printf '{"cpu":%d,"clock":%d,"temp":%d,"mem":%d,"memUsedKb":%d,"memTotalKb":%d,"swap":%d,"down":%d,"up":%d,"disk":%s,"load":%s}\n' \
      "$cpu" "$clock" "$temp" "$mem_pct" "$mem_used_kb" "$mem_total_kb" "$swap_pct" "$dl" "$ul" "${disk:-0}" "${load:-0}" \
      || exit 0
  fi
  first=0

  slow=$((slow - 1))
  [ "$slow" -le 0 ] && slow=$slow_every

  # Gone with the shell. Quickshell ignores SIGPIPE and its children inherit
  # that, so a failed write alone does not end an orphaned copy - see netbt.sh.
  kill -0 "$PPID" 2>/dev/null || exit 0
  sleep "$interval"
done
