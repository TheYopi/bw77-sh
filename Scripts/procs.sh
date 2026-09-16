#!/usr/bin/env bash
# Emits one JSON object per interval naming the processes using the most of
# each resource.
#
#   usage: procs.sh [interval_seconds] [sections]
#
# `sections` is a comma-separated list of "cpu" and "gpu". The CPU section
# covers both processor and memory, which come out of one sweep of /proc; the
# GPU section covers graphics engine time and VRAM, which come out of the
# kernel's DRM fdinfo files. The GPU half is asked for separately because it is
# only wanted when a GPU widget is on the desktop, and there is no point walking
# every open file descriptor on the machine for a widget that is not there.
#
# Output, with every list already cut to the top five:
#
#   {"cpu":[{"n":"firefox","v":12.50}],"mem":[{"n":"firefox","v":1258291}],
#    "gpu":[...],"vram":[...]}
#
# Values are percent for cpu and gpu, kibibytes for mem and vram. The shell
# formats them; this only measures.
#
# --- why processes are grouped by name
#
# A browser is thirty processes and every one of them is called "firefox". A
# list of the five heaviest PIDs on a desktop machine is therefore five browser
# tabs, over and over, which says nothing a person can act on. Grouping by the
# command name gives "firefox 4.2 G", which is the sentence the widget is
# actually trying to say.
#
# --- everything here is a rate, measured between two samples
#
# Both percentages are deltas of counters taken a tick apart. That is the whole
# reason this keeps state between ticks rather than just asking a tool for a
# number, and it is worth spelling out because the obvious shortcuts are both
# wrong:
#
#   `ps -o pcpu` is NOT current CPU load. It is the process's total CPU time
#   divided by how long the process has been alive - a lifetime average. A
#   browser that was busy ten minutes ago still reports that ten minutes later,
#   and a process that just started spinning reports almost nothing, because
#   the spike is averaged over its whole life. On a machine that has been up a
#   while the list barely moves at all, which is what it looked like: a top
#   five that was not updating.
#
#   drm-engine-gfx is a running total of nanoseconds on the graphics engine, so
#   reading it once says how much a client has EVER drawn, not what it is doing
#   now.
#
# So both are differentiated here against the wall clock between samples.

interval="${1:-2}"
sections="${2:-cpu}"

want_cpu=0
want_gpu=0
case ",$sections," in *,cpu,*) want_cpu=1 ;; esac
case ",$sections," in *,gpu,*) want_gpu=1 ;; esac

# --- fork-free wait, as in sysmon.sh, gpu.sh and locks.sh
nap_fd_ready=0
fifo="$(mktemp -u 2>/dev/null)" || fifo=""
if [ -n "$fifo" ] && mkfifo "$fifo" 2>/dev/null; then
  exec 9<>"$fifo"
  rm -f "$fifo"
  nap_fd_ready=1
fi

nap() {
  if [ "$nap_fd_ready" = 1 ]; then
    read -r -t "$interval" -u 9 _ 2>/dev/null
    return 0
  fi
  sleep "$interval"
}

# Clock ticks per second, and how many cores there are to spread load over.
# Both are constants for the life of the machine, so they are asked for once.
clk=$(getconf CLK_TCK 2>/dev/null) || clk=100
[ -n "$clk" ] && [ "$clk" -gt 0 ] 2>/dev/null || clk=100
ncpu=$(getconf _NPROCESSORS_ONLN 2>/dev/null) || ncpu=1
[ -n "$ncpu" ] && [ "$ncpu" -gt 0 ] 2>/dev/null || ncpu=1

# Below this the counters have not moved far enough to divide by without the
# answer being mostly quantisation noise - and a span of a millisecond would
# turn a rounding error into a process apparently using 4000% of the machine.
min_span_ms=200

cpu_json='[]'
mem_json='[]'
gpu_json='[]'
vram_json='[]'

# ---- processor and memory
#
# Straight out of /proc rather than through `ps`, for the reason in the header:
# this needs the CPU time each process has used SINCE THE LAST TICK, and no
# invocation of ps can answer that. One awk reads every process's stat file in
# a single pass and prints the two counters; the differencing happens here,
# where the previous tick's numbers are.
#
# The command name is printed last because it is the one field that can contain
# spaces - and parentheses, which is why it is cut out by finding the LAST
# closing bracket rather than by splitting on whitespace. A process called
# "Web Content" or ")" is unusual but entirely legal, and getting it wrong
# shifts every field after it.
declare -A cpu_prev
cpu_prev_ns=0

sample_proc() {
  local -A jiff_now cpu_by mem_by
  local now_ns span_ms pid jiff rsskb name prev delta hundredths

  now_ns=$(( ${EPOCHREALTIME/./} * 1000 ))
  span_ms=$(( (now_ns - cpu_prev_ns) / 1000000 ))

  while read -r pid jiff rsskb name; do
    [ -n "$name" ] || continue
    jiff_now[$pid]=$jiff
    mem_by[$name]=$(( ${mem_by[$name]:-0} + rsskb ))

    prev=${cpu_prev[$pid]:-}
    [ -n "$prev" ] || continue
    [ "$cpu_prev_ns" -gt 0 ] && [ "$span_ms" -ge "$min_span_ms" ] || continue

    delta=$(( jiff - prev ))
    [ "$delta" -gt 0 ] || continue

    # Hundredths of a percent of the WHOLE machine, so the rows under a dial
    # reading 40% add up to roughly 40 rather than to 320 on an eight-core
    # box. Hundredths because a process using a third of one percent is still
    # worth ranking, and at whole-number resolution every light user collapses
    # to zero and drops out of the list entirely.
    hundredths=$(( delta * 10000000 / (clk * span_ms * ncpu) ))
    [ "$hundredths" -gt 0 ] || hundredths=1
    cpu_by[$name]=$(( ${cpu_by[$name]:-0} + hundredths ))
  done < <(awk '
    # "lo" and "hi" rather than the obvious "open" and "close": close() is an
    # awk built-in and assigning to it is a syntax error, which takes the whole
    # program with it - and a program that does not run prints nothing, which
    # looks exactly like a machine where no process is using any CPU.
    FNR == 1 {
      line = $0
      lo = index(line, "(")
      hi = 0
      for (k = length(line); k > 0; k--)
        if (substr(line, k, 1) == ")") { hi = k; break }
      if (lo == 0 || hi <= lo) next

      name = substr(line, lo + 1, hi - lo - 1)
      split(substr(line, hi + 2), f, " ")

      # f[1] is field 3 of the original line, so utime (14) is f[12],
      # stime (15) is f[13] and rss in pages (24) is f[22].
      printf "%d %d %d %s\n", substr(line, 1, lo - 2), f[12] + f[13], f[22] * 4, name
    }' /proc/[0-9]*/stat 2>/dev/null)

  # Carried forward wholesale, so a PID that has exited leaves nothing behind
  # for a recycled PID to be differenced against.
  cpu_prev=()
  for pid in "${!jiff_now[@]}"; do cpu_prev[$pid]=${jiff_now[$pid]}; done
  cpu_prev_ns=$now_ns

  cpu_json=$(top5_json cpu_by 2)
  mem_json=$(top5_json mem_by 0)
}

# ---- graphics engine and VRAM
#
# The kernel publishes per-client GPU accounting in the fdinfo of whichever
# file descriptor has the DRM device open - drm-engine-gfx as a running total
# of nanoseconds on the graphics engine, and drm-resident-vram as what that
# client currently has in video memory. This is the same place nvtop reads
# from, and it is the only per-process GPU accounting the kernel offers.
#
# grep does the walking, in batches. Expanding /proc/*/fdinfo/* is thousands of
# paths on a busy machine and reading them one at a time from bash would be far
# too slow at this cadence, but handing all of them to one grep risks the
# argument list overflowing - which fails the whole sweep and takes the GPU
# lists with it, on exactly the busy machine where they are most wanted.
# Batching keeps each call well inside the limit; it is normally one call, and
# a few on a machine with tens of thousands of descriptors open.
#
# Unreadable files - other users' processes - are skipped with -s rather than
# being an error.
declare -A gfx_prev
gpu_prev_ns=0

fdinfo_lines() {
  local -a files=(/proc/[0-9]*/fdinfo/*)
  local n=${#files[@]} i
  [ "$n" -gt 0 ] || return 0
  [ -e "${files[0]}" ] || return 0

  for (( i = 0; i < n; i += 4000 )); do
    grep -s -H -E \
      '^(drm-client-id|drm-engine-gfx|drm-resident-vram|drm-memory-vram):' \
      "${files[@]:i:4000}" 2>/dev/null
  done
  return 0
}

sample_gpu() {
  local -A gfx_now vram_now pid_of seen gpu_by vram_by
  local line path rest key val pid cur_path="" cur_pid=""
  local cur_cid="" cur_gfx=0 cur_vram=0
  local now_ns span_ns k nm prev delta hundredths

  now_ns=$(( ${EPOCHREALTIME/./} * 1000 ))

  # Commits the record built up for one fdinfo file. Several descriptors can
  # point at the same DRM client - a dup, or the same device opened twice - and
  # they all report identical numbers, so the client id is what de-duplicates
  # them rather than the descriptor.
  commit() {
    [ -n "$cur_cid" ] || return 0
    local k="$cur_pid:$cur_cid"
    [ -n "${seen[$k]+x}" ] && return 0
    seen[$k]=1
    gfx_now[$k]=$cur_gfx
    vram_now[$k]=$cur_vram
    pid_of[$k]=$cur_pid
  }

  while IFS= read -r line; do
    path=${line%%:*}
    rest=${line#*:}
    key=${rest%%:*}
    val=${rest#*:}

    if [ "$path" != "$cur_path" ]; then
      commit
      cur_path=$path
      pid=${path#/proc/}
      cur_pid=${pid%%/*}
      cur_cid=""; cur_gfx=0; cur_vram=0
    fi

    # Strip the leading whitespace and any unit suffix; what is left is an
    # integer in the unit the field name already tells us.
    val=${val//[[:space:]]/}
    val=${val%ns}
    val=${val%KiB}
    val=${val%kB}

    case "$key" in
      drm-client-id)     cur_cid=$val ;;
      drm-engine-gfx)    cur_gfx=$val ;;
      # Newer kernels publish drm-resident-vram; older amdgpu only has
      # drm-memory-vram. Both mean the same thing here, and taking whichever
      # arrives keeps this working across kernel versions.
      drm-resident-vram) cur_vram=$val ;;
      drm-memory-vram)   [ "$cur_vram" = 0 ] && cur_vram=$val ;;
    esac
  done < <(fdinfo_lines)

  commit

  span_ns=$(( now_ns - gpu_prev_ns ))

  for k in "${!seen[@]}"; do
    nm=""
    read -r nm < "/proc/${pid_of[$k]}/comm" 2>/dev/null || continue
    [ -n "$nm" ] || continue

    vram_by[$nm]=$(( ${vram_by[$nm]:-0} + ${vram_now[$k]:-0} ))

    prev=${gfx_prev[$k]:-}
    [ -n "$prev" ] || continue
    [ "$gpu_prev_ns" -gt 0 ] || continue
    [ "$span_ns" -ge $(( min_span_ms * 1000000 )) ] || continue

    delta=$(( ${gfx_now[$k]:-0} - prev ))
    [ "$delta" -gt 0 ] || continue

    # --- hundredths, and never rounded away to nothing
    #
    # At whole-tenths resolution a client drawing a compositor's worth of work
    # - a few tenths of a percent - landed on either side of the rounding
    # boundary from one tick to the next, so it appeared in the list, vanished,
    # and appeared again. The list looked like it had stopped updating when
    # what it was actually doing was flickering between a row and nothing.
    #
    # A client that drew ANYTHING at all in the last tick is a client that is
    # using the GPU, so it is floored at one hundredth rather than dropped.
    # The widget prints anything under one percent as "<1%".
    hundredths=$(( delta * 10000 / span_ns ))
    [ "$hundredths" -gt 0 ] || hundredths=1
    gpu_by[$nm]=$(( ${gpu_by[$nm]:-0} + hundredths ))
  done

  # Carry the counters forward. Reassigned wholesale rather than updated in
  # place, so a client that has gone away does not leave its last reading
  # behind to be subtracted from a reused id later.
  gfx_prev=()
  for k in "${!gfx_now[@]}"; do gfx_prev[$k]=${gfx_now[$k]}; done
  gpu_prev_ns=$now_ns

  gpu_json=$(top5_json gpu_by 2)
  vram_json=$(top5_json vram_by 0)
}

# Top five of an associative array as JSON. `decimals` says how many digits of
# the stored integer are fractional - the counters above are kept in hundredths
# so that small users can be ranked against each other rather than all
# collapsing to zero.
#
# Selection rather than a sort: five passes over a few hundred names is less
# work than ordering all of them to throw all but five away, and it starts no
# processes to do it.
top5_json() {
  local -n src=$1
  local decimals="${2:-0}"
  local -A used
  local i k best bestv out="[" first=1 esc value

  for (( i = 0; i < 5; i++ )); do
    best=""; bestv=0
    for k in "${!src[@]}"; do
      [ -n "${used[$k]+x}" ] && continue
      if [ -z "$best" ] || [ "${src[$k]}" -gt "$bestv" ]; then
        best=$k; bestv=${src[$k]}
      fi
    done
    [ -n "$best" ] || break
    [ "$bestv" -gt 0 ] || break
    used[$best]=1

    esc=${best//\\/\\\\}
    esc=${esc//\"/\\\"}

    case "$decimals" in
      # Zero-padded, or 5 hundredths would be written as "0.5".
      2) printf -v value '%d.%02d' $(( bestv / 100 )) $(( bestv % 100 )) ;;
      1) printf -v value '%d.%d'   $(( bestv / 10 ))  $(( bestv % 10 )) ;;
      *) value=$bestv ;;
    esac

    [ "$first" = 1 ] || out="$out,"
    first=0
    out="$out{\"n\":\"$esc\",\"v\":$value}"
  done

  printf '%s]' "$out"
}

# --- a baseline before the first reading
#
# Every percentage here is a difference between two samples, so the first
# sample of a run can only ever report nothing. That is one empty list at
# startup - except that a desktop widget is destroyed and rebuilt whenever the
# widget list is touched, which restarts this, which means "at startup" can
# happen often enough that the GPU column looks permanently empty.
#
# So the counters are primed before the loop begins and the first line that
# reaches the shell already carries real rates. The nap in between is what
# gives the first difference a full interval to span - priming and then
# sampling immediately would divide by a span of nearly zero.
if [ "$want_cpu" = 1 ] || [ "$want_gpu" = 1 ]; then
  [ "$want_cpu" = 1 ] && sample_proc
  [ "$want_gpu" = 1 ] && sample_gpu
  kill -0 "$PPID" 2>/dev/null || exit 0
  nap
fi

while :; do
  [ "$want_cpu" = 1 ] && sample_proc
  [ "$want_gpu" = 1 ] && sample_gpu

  printf '{"cpu":%s,"mem":%s,"gpu":%s,"vram":%s}\n' \
    "$cpu_json" "$mem_json" "$gpu_json" "$vram_json" || exit 0

  # Gone with the shell. Quickshell ignores SIGPIPE and its children inherit
  # that, so a failed write alone does not end an orphaned copy - see netbt.sh.
  kill -0 "$PPID" 2>/dev/null || exit 0
  nap
done
