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

# ---- network
net_state() {
  local type="none" name="" strength=0 connected="false" wifi_enabled="false"

  if command -v nmcli >/dev/null 2>&1; then
    [ "$(nmcli radio wifi 2>/dev/null)" = "enabled" ] && wifi_enabled="true"
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

  printf '"net":{"type":"%s","name":"%s","strength":%s,"connected":%s,"wifiEnabled":%s,"aps":[%s]}' \
    "$(json_escape "$type")" "$(json_escape "$name")" "${strength:-0}" "$connected" \
    "$wifi_enabled" "$aps"
}

# ---- bluetooth
bt_state() {
  local available="false" powered="false" count=0 name=""

  if command -v bluetoothctl >/dev/null 2>&1; then
    available="true"
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
      powered="true"

      # bluetoothctl gained "devices Connected" fairly recently; fall back to
      # inspecting each known device when it is not supported.
      local devs
      devs=$(bluetoothctl devices Connected 2>/dev/null | grep -c '^Device ')
      if [ "${devs:-0}" -gt 0 ]; then
        count="$devs"
        name=$(bluetoothctl devices Connected 2>/dev/null \
               | head -1 | cut -d' ' -f3-)
      else
        local mac
        for mac in $(bluetoothctl devices 2>/dev/null | awk '{print $2}'); do
          if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            count=$((count+1))
            [ -z "$name" ] && name=$(bluetoothctl info "$mac" 2>/dev/null \
                              | awk -F': ' '/Name:/{print $2; exit}')
          fi
        done
      fi
    fi
  elif [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
    available="true"
  fi

  # Known devices, connected first. Paired but disconnected devices are
  # included so they can be reconnected from the panel.
  local devs="" first=1
  if [ "$available" = "true" ] && command -v bluetoothctl >/dev/null 2>&1; then
    local mac dname dconn
    for mac in $(bluetoothctl devices 2>/dev/null | awk '{print $2}' | head -12); do
      dname=$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/[ \t]Name:/{print $2; exit}')
      [ -z "$dname" ] && dname="$mac"
      local info
      info=$(bluetoothctl info "$mac" 2>/dev/null)
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

while :; do
  printf '{%s,%s}\n' "$(net_state)" "$(bt_state)"
  sleep "$interval"
done
