#!/usr/bin/env bash
# Emits one JSON object per interval on stdout, describing the first GPU found.
#
#   usage: gpu.sh [interval_seconds]
#
# Fields: vendor, name, usage (%), temp (C), vramUsedMb, vramTotalMb, power (W).
# Any metric this machine cannot report comes back as -1 rather than 0, so the
# widget can hide a reading instead of drawing a convincing zero.
#
# --- why not nvtop
#
# nvtop is the obvious candidate and it is the wrong shape for this. It is an
# ncurses application: it draws a full-screen interactive UI and has no
# machine-readable output mode at all - no JSON, no CSV, no one-shot dump. The
# request for one is still an open discussion upstream. Parsing its rendered
# frames would mean scraping box-drawing characters out of a pty, re-scraping
# them whenever its layout changed, and running a whole TUI per sample.
#
# What nvtop actually does is read the same interfaces this script reads: the
# amdgpu sysfs files for AMD and NVML for NVIDIA. Its value is the interface it
# draws, not access to data that is otherwise unavailable - so for a widget the
# sources go straight to the kernel and the driver.
#
#   AMD    - /sys/class/drm/card*/device, all four metrics, no extra package
#   NVIDIA - nvidia-smi --query-gpu, which ships with the driver itself
#   Intel  - partial; see the note in probe_intel

interval="${1:-2}"

vendor=""
name=""

# AMD
amd_base=""
amd_hwmon=""

read_first() {
  # Echoes the contents of the first readable, non-empty file given.
  local f
  for f in "$@"; do
    [ -r "$f" ] || continue
    local v
    read -r v < "$f" 2>/dev/null || continue
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  printf '%s' ""
}

probe_amd() {
  local dev
  for dev in /sys/class/drm/card[0-9]*/device; do
    # gpu_busy_percent is the marker: it exists only on amdgpu, and only on
    # cards whose firmware actually reports activity.
    [ -r "$dev/gpu_busy_percent" ] || continue
    amd_base="$dev"

    local h
    for h in "$dev"/hwmon/hwmon*; do
      [ -d "$h" ] && { amd_hwmon="$h"; break; }
    done

    name="$(read_first "$dev/product_name")"
    [ -z "$name" ] && name="AMD GPU"
    vendor="amd"
    return 0
  done
  return 1
}

probe_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 || return 1
  # A driver can be installed on a machine with no NVIDIA card in it, so the
  # probe has to be a real query rather than just the binary existing.
  local n
  n="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)"
  [ -z "$n" ] && return 1
  name="$n"
  vendor="nvidia"
  return 0
}

intel_base=""
intel_hwmon=""

probe_intel() {
  # Deliberately partial, and it says so in the output.
  #
  # i915 and xe expose frequency and, on newer parts, hwmon temperature and
  # power - but not a busy percentage. Utilisation on Intel comes from perf
  # counters, which is why intel_gpu_top needs CAP_PERFMON or root; a desktop
  # widget is not the place to ask for that. So Intel reports whatever the
  # driver hands over for free and returns -1 for the rest.
  local dev
  for dev in /sys/class/drm/card[0-9]*/device; do
    local drv=""
    [ -L "$dev/driver" ] && drv="$(basename "$(readlink -f "$dev/driver")")"
    case "$drv" in
      i915|xe) ;;
      *) continue ;;
    esac
    intel_base="$dev"
    local h
    for h in "$dev"/hwmon/hwmon*; do
      [ -d "$h" ] && { intel_hwmon="$h"; break; }
    done
    name="Intel GPU"
    vendor="intel"
    return 0
  done
  return 1
}

probe_amd || probe_nvidia || probe_intel || vendor="none"

# Nothing to watch. Say so once and exit rather than spinning: the service
# reads the vendor and stops asking.
if [ "$vendor" = "none" ]; then
  printf '{"vendor":"none","name":"","usage":-1,"temp":-1,"vramUsedMb":-1,"vramTotalMb":-1,"power":-1}\n'
  exit 0
fi

# JSON strings, so a card called `Radeon RX 7900 "XTX"` cannot break the parse.
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}
name_esc="$(json_escape "$name")"

emit() {
  printf '{"vendor":"%s","name":"%s","usage":%s,"temp":%s,"vramUsedMb":%s,"vramTotalMb":%s,"power":%s}\n' \
    "$vendor" "$name_esc" "${1:--1}" "${2:--1}" "${3:--1}" "${4:--1}" "${5:--1}"
}

sample_amd() {
  local usage temp vused vtotal power raw

  usage="$(read_first "$amd_base/gpu_busy_percent")"
  [ -z "$usage" ] && usage=-1

  # Bytes from the driver, mebibytes out - a widget showing 25199575040 is not
  # showing anything.
  vused="$(read_first "$amd_base/mem_info_vram_used")"
  vtotal="$(read_first "$amd_base/mem_info_vram_total")"
  [ -n "$vused" ]  && vused=$(( vused / 1048576 ))   || vused=-1
  [ -n "$vtotal" ] && vtotal=$(( vtotal / 1048576 )) || vtotal=-1

  temp=-1
  if [ -n "$amd_hwmon" ]; then
    raw="$(read_first "$amd_hwmon/temp1_input")"
    [ -n "$raw" ] && temp=$(( raw / 1000 ))
  fi

  # Millidegrees and microwatts are the hwmon convention. power1_average is
  # the smoothed figure and is what the card reports on most parts;
  # power1_input is the instantaneous one and is all some of them have.
  power=-1
  if [ -n "$amd_hwmon" ]; then
    raw="$(read_first "$amd_hwmon/power1_average" "$amd_hwmon/power1_input")"
    [ -n "$raw" ] && power=$(( raw / 1000000 ))
  fi

  emit "$usage" "$temp" "$vused" "$vtotal" "$power"
}

sample_nvidia() {
  # One query for all five, so this is one fork per tick rather than five.
  # nounits keeps the values bare; the fields come back comma separated.
  local line
  line="$(nvidia-smi \
    --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw \
    --format=csv,noheader,nounits 2>/dev/null | head -n1)"

  if [ -z "$line" ]; then
    emit -1 -1 -1 -1 -1
    return
  fi

  # "[N/A]" comes back for anything the card does not report - power draw on a
  # good number of laptop parts - and must not be printed into the JSON.
  local IFS=,
  set -- $line
  local u="${1// /}" t="${2// /}" mu="${3// /}" mt="${4// /}" p="${5// /}"
  local v
  for v in u t mu mt p; do
    case "${!v}" in
      ''|*[!0-9.]*) printf -v "$v" '%s' "-1" ;;
    esac
  done
  # Watts arrive with a decimal; the widget wants a whole number.
  p="${p%%.*}"

  emit "$u" "$t" "$mu" "$mt" "${p:--1}"
}

sample_intel() {
  local temp=-1 power=-1 raw
  if [ -n "$intel_hwmon" ]; then
    raw="$(read_first "$intel_hwmon/temp1_input")"
    [ -n "$raw" ] && temp=$(( raw / 1000 ))
    raw="$(read_first "$intel_hwmon/power1_average" "$intel_hwmon/power1_input")"
    [ -n "$raw" ] && power=$(( raw / 1000000 ))
  fi
  # Usage and VRAM stay -1: see probe_intel.
  emit -1 "$temp" -1 -1 "$power"
}

while :; do
  case "$vendor" in
    amd)    sample_amd ;;
    nvidia) sample_nvidia ;;
    intel)  sample_intel ;;
  esac
  # Gone with the shell. Quickshell ignores SIGPIPE and its children inherit
  # that, so a failed write alone does not end an orphaned copy - see netbt.sh.
  kill -0 "$PPID" 2>/dev/null || exit 0
  sleep "$interval"
done
