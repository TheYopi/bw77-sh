#!/usr/bin/env bash
# Emits one JSON object per interval describing network and bluetooth state.
#
# Everything here degrades: a missing tool reports "unknown" rather than failing,
# because the panel showing a stale-but-plausible state is better than a widget
# that vanishes on machines without NetworkManager or bluez.
#
# usage: netbt.sh [interval_seconds]

interval="${1:-5}"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# --- bluetoothctl, with a deadline
#
# bluetoothctl does not fail when bluetoothd is not there to answer it - it
# prints "Waiting to connect to bluetoothd..." and waits, forever. With no
# controller plugged in that is exactly the path `list` took, inside two
# nested command substitutions, so the poller hung on its first tick.
#
# Worse than a hung poller: when the shell stopped it (every reload, and the
# refresh after every toggle) only this top-level bash was killed. The two
# subshells and the bluetoothctl under them were still waiting on a daemon
# that was never coming, so each stop left three processes behind for good.
# Two seconds is far longer than a working bluetoothctl ever takes.
btctl() { timeout 2 bluetoothctl "$@"; }

# ---- network
net_state() {
  local type="none" name="" strength=0 connected="false" wifi_enabled="false"
  local wifi_present="false" net_present="false"

  if command -v nmcli >/dev/null 2>&1; then
    [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ] && wifi_enabled="true"
  fi

  # --- what hardware is actually here
  #
  # "Offline" and "there is no adapter" are different sentences and the panel
  # was only able to say the first one, so a machine with no wireless card read
  # as a machine that had simply not connected yet - and the Wi-Fi toggle sat
  # there offering to turn on a radio that does not exist.
  if command -v nmcli >/dev/null 2>&1; then
    local types
    types=$(nmcli -t -f TYPE device 2>/dev/null)
    printf '%s\n' "$types" | grep -qx "wifi" && wifi_present="true"
    printf '%s\n' "$types" | grep -qxE "wifi|ethernet" && net_present="true"
  else
    local dev
    for dev in /sys/class/net/*; do
      [ -e "$dev" ] || continue
      [ "$(basename "$dev")" = "lo" ] && continue
      net_present="true"
      { [ -d "$dev/wireless" ] || [ -e "$dev/phy80211" ]; } && wifi_present="true"
    done
  fi

  if command -v nmcli >/dev/null 2>&1; then
    # TYPE:STATE:CONNECTION for the active device, wifi preferred over ethernet.
    local line
    line=$(nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null \
           | awk -F: '$2=="connected" && ($1=="wifi"||$1=="ethernet")' | head -1)

    if [ -n "$line" ]; then
      type=$(printf '%s' "$line" | cut -d: -f1)
      name=$(printf '%s' "$line" | cut -d: -f3-)
      connected="true"

      if [ "$type" = "wifi" ]; then
        strength=$(nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null \
                   | awk -F: '$1=="*"{print $2; exit}')
        [ -z "$strength" ] && strength=0
      fi
    fi
  else
    # No NetworkManager: fall back to reading the interfaces directly.
    local iface
    for iface in /sys/class/net/*; do
      local n
      n=$(basename "$iface")
      [ "$n" = "lo" ] && continue
      [ -r "$iface/operstate" ] || continue
      [ "$(cat "$iface/operstate")" = "up" ] || continue

      connected="true"
      name="$n"
      if [ -d "$iface/wireless" ] || [ -e "$iface/phy80211" ]; then
        type="wifi"
        # Column 3 of /proc/net/wireless is link quality, roughly 0-70.
        local q
        q=$(awk -v i="$n:" '$1==i {gsub(/\./,"",$3); print $3; exit}' /proc/net/wireless 2>/dev/null)
        [ -n "$q" ] && strength=$(( q * 100 / 70 ))
        [ "$strength" -gt 100 ] && strength=100
      else
        type="ethernet"
      fi
      break
    done
  fi

  # Access points, best signal first. Only meaningful with NetworkManager;
  # without it the list is simply empty and the panel shows the current
  # connection alone.
  local aps="" first=1
  if command -v nmcli >/dev/null 2>&1; then
    # Split with `read` rather than four `cut` calls and two subshells per
    # line. Twelve access points is twelve lines, and the old shape forked six
    # processes for each of them - seventy-odd processes to format a list that
    # is already in hand. IFS gives the same fields: the last variable keeps
    # the remainder of the line with its colons, which is what -f4- did.
    local ap_line
    while IFS= read -r ap_line; do
      [ -n "$ap_line" ] || continue
      local inuse ssid signal security active secure
      IFS=: read -r inuse ssid signal security <<< "$ap_line"
      [ -n "$ssid" ] || continue

      case "$inuse" in '*') active=true ;; *) active=false ;; esac
      case "$security" in '') secure=false ;; *) secure=true ;; esac

      [ "$first" -eq 0 ] && aps="$aps,"
      first=0
      aps="$aps{\"ssid\":\"$(json_escape "$ssid")\",\"signal\":${signal:-0}"
      aps="$aps,\"active\":$active,\"secure\":$secure}"
    done <<< "$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
                | sort -t: -k3 -rn | awk -F: '!seen[$2]++' | head -12)"
  fi

  printf '"net":{"type":"%s","name":"%s","strength":%s,"connected":%s,"wifiEnabled":%s,"wifiPresent":%s,"present":%s,"aps":[%s]}' \
    "$(json_escape "$type")" "$(json_escape "$name")" "${strength:-0}" "$connected" \
    "$wifi_enabled" "$wifi_present" "$net_present" "$aps"
}

# ---- bluetooth
#
# --- one question per device, asked once
#
# Every fact about a device comes out of `bluetoothctl info`, and this used to
# run it up to four times for each one: once to test whether it was connected,
# again for its name, again for the listing's name, and a fourth time for the
# listing's flags. With a dozen paired devices that is around fifty processes
# spawned every five seconds for as long as the panel is open, each of them
# waiting on bluetoothd for the same answer.
#
# It is now read once per device and everything is parsed out of that one copy,
# with bash pattern matching rather than a `grep` per field - a `case` costs
# nothing, a pipeline costs two processes. Connected count and the name shown
# on the tile fall out of the same pass, so `devices Connected` is not needed
# either.
bt_state() {
  local available="false" powered="false" count=0 name=""

  # --- is there a controller, not just a tool to talk to one with
  #
  # This used to report "available" for any machine with bluetoothctl
  # installed, which is most of them, so a desktop with no radio at all showed
  # a Bluetooth tile that could be switched on and would then report itself
  # off forever. The kernel exposes a controller under /sys/class/bluetooth the
  # moment one is plugged in, which is also how a dongle appearing later gets
  # noticed without restarting anything.
  #
  # A glob rather than `ls -A` in a substitution: the shell can see whether the
  # directory has anything in it without starting a program to look.
  local node
  for node in /sys/class/bluetooth/*; do
    [ -e "$node" ] && { available="true"; break; }
  done

  if [ "$available" = "false" ] && command -v bluetoothctl >/dev/null 2>&1 \
     && [ -n "$(btctl list 2>/dev/null)" ]; then
    available="true"
  fi

  # Known devices, connected first. Paired but disconnected devices are
  # included so they can be reconnected from the panel.
  local devs="" first=1

  if [ "$available" = "true" ] && command -v bluetoothctl >/dev/null 2>&1; then
    case "$(btctl show 2>/dev/null)" in
      *"Powered: yes"*) powered="true" ;;
    esac

    local mac info line dname dconn dpair
    for mac in $(btctl devices 2>/dev/null | awk '{print $2}' | head -12); do
      info=$(btctl info "$mac" 2>/dev/null)

      # The name line is indented under the device heading, which is what the
      # leading whitespace in the pattern is for - the heading itself carries
      # the name too, unindented, and matching that first would pick up an
      # alias the controller does not use.
      dname=""
      while IFS= read -r line; do
        case "$line" in
          *" Name: "*|*$'\t'"Name: "*) dname="${line#*Name: }"; break ;;
        esac
      done <<< "$info"
      [ -z "$dname" ] && dname="$mac"

      case "$info" in *"Connected: yes"*) dconn=true ;; *) dconn=false ;; esac
      case "$info" in *"Paired: yes"*) dpair=true ;; *) dpair=false ;; esac

      if [ "$dconn" = true ]; then
        count=$((count+1))
        [ -z "$name" ] && name="$dname"
      fi

      [ "$first" -eq 0 ] && devs="$devs,"
      first=0
      devs="$devs{\"mac\":\"$mac\",\"name\":\"$(json_escape "$dname")\""
      devs="$devs,\"connected\":$dconn,\"paired\":$dpair}"
    done
  fi

  # The count is over the devices actually listed above. Anything past the cap
  # is not shown in the panel either, so a badge counting it would be pointing
  # at a row that is not there.
  printf '"bt":{"available":%s,"powered":%s,"count":%s,"name":"%s","devices":[%s]}' \
    "$available" "$powered" "$count" "$(json_escape "$name")" "$devs"
}

# --- leaving when the shell does
#
# Quickshell ignores SIGPIPE, and an ignored signal is inherited across exec -
# so a write to a reader that has gone does not kill this script, it just
# fails. If the shell exits without stopping it (a crash, a pkill) the script
# is re-parented and loops forever writing to nobody. Both checks are
# builtins: the parent test costs one syscall, not a fork.
while :; do
  kill -0 "$PPID" 2>/dev/null || exit 0
  printf '{%s,%s}\n' "$(net_state)" "$(bt_state)" || exit 0
  sleep "$interval"
done
