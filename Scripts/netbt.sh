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
    local ap_line
    while IFS= read -r ap_line; do
      [ -n "$ap_line" ] || continue
      local inuse ssid signal security
      inuse=$(printf '%s' "$ap_line" | cut -d: -f1)
      ssid=$(printf '%s' "$ap_line" | cut -d: -f2)
      signal=$(printf '%s' "$ap_line" | cut -d: -f3)
      security=$(printf '%s' "$ap_line" | cut -d: -f4-)
      [ -n "$ssid" ] || continue

      [ "$first" -eq 0 ] && aps="$aps,"
      first=0
      aps="$aps{\"ssid\":\"$(json_escape "$ssid")\",\"signal\":${signal:-0}"
      aps="$aps,\"active\":$([ "$inuse" = "*" ] && echo true || echo false)"
      aps="$aps,\"secure\":$([ -n "$security" ] && echo true || echo false)}"
    done <<< "$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
                | sort -t: -k3 -rn | awk -F: '!seen[$2]++' | head -12)"
  fi

  printf '"net":{"type":"%s","name":"%s","strength":%s,"connected":%s,"wifiEnabled":%s,"wifiPresent":%s,"present":%s,"aps":[%s]}' \
    "$(json_escape "$type")" "$(json_escape "$name")" "${strength:-0}" "$connected" \
    "$wifi_enabled" "$wifi_present" "$net_present" "$aps"
}

# ---- bluetooth
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
  if [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
    available="true"
  elif command -v bluetoothctl >/dev/null 2>&1 \
       && [ -n "$(btctl list 2>/dev/null)" ]; then
    available="true"
  fi

  if [ "$available" = "true" ] && command -v bluetoothctl >/dev/null 2>&1; then
    if btctl show 2>/dev/null | grep -q "Powered: yes"; then
      powered="true"

      # bluetoothctl gained "devices Connected" fairly recently; fall back to
      # inspecting each known device when it is not supported.
      local devs
      devs=$(btctl devices Connected 2>/dev/null | grep -c '^Device ')
      if [ "${devs:-0}" -gt 0 ]; then
        count="$devs"
        name=$(btctl devices Connected 2>/dev/null \
               | head -1 | cut -d' ' -f3-)
      else
        local mac
        for mac in $(btctl devices 2>/dev/null | awk '{print $2}'); do
          if btctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            count=$((count+1))
            [ -z "$name" ] && name=$(btctl info "$mac" 2>/dev/null \
                              | awk -F': ' '/Name:/{print $2; exit}')
          fi
        done
      fi
    fi
  fi

  # Known devices, connected first. Paired but disconnected devices are
  # included so they can be reconnected from the panel.
  local devs="" first=1
  if [ "$available" = "true" ] && command -v bluetoothctl >/dev/null 2>&1; then
    local mac dname dconn
    for mac in $(btctl devices 2>/dev/null | awk '{print $2}' | head -12); do
      dname=$(btctl info "$mac" 2>/dev/null | awk -F': ' '/[ \t]Name:/{print $2; exit}')
      [ -z "$dname" ] && dname="$mac"
      local info
      info=$(btctl info "$mac" 2>/dev/null)
      dconn=$(printf '%s' "$info" | grep -q "Connected: yes" && echo true || echo false)
      local dpair
      dpair=$(printf '%s' "$info" | grep -q "Paired: yes" && echo true || echo false)

      [ "$first" -eq 0 ] && devs="$devs,"
      first=0
      devs="$devs{\"mac\":\"$mac\",\"name\":\"$(json_escape "$dname")\""
      devs="$devs,\"connected\":$dconn,\"paired\":$dpair}"
    done
  fi

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
