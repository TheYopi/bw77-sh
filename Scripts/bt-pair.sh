#!/usr/bin/env bash
# Pair, trust and connect a bluetooth device.
#
#   bt-pair.sh <MAC>
#
# Why this is a script and not three bluetoothctl calls:
#
#   1. bluez will not complete a pairing without a registered agent, and
#      Quickshell's bluetooth module does not provide one.
#   2. bluetoothctl may still PROMPT for confirmation ("Confirm passkey ...
#      (yes/no)"). Piping a fixed command list gives it nothing to read when the
#      prompt appears, so the pairing stalls and is aborted - the device pairs
#      for a moment, never connects, and is then discarded.
#   3. Each separate `bluetoothctl <cmd>` invocation is its own session, so an
#      agent registered in one is gone by the next.
#
# So: one session, an explicit NoInputNoOutput agent, paced input that keeps
# stdin open, and a "yes" ready for any confirmation prompt.

set -u

mac="${1:-}"
if [ -z "$mac" ]; then
  echo "bt-pair: no address given" >&2
  exit 2
fi

if ! command -v bluetoothctl >/dev/null 2>&1; then
  echo "bt-pair: bluetoothctl not found" >&2
  exit 3
fi

# Feed commands with pauses so prompts are answered as they appear rather than
# being consumed before bluez has asked anything.
feed() {
  # Drop any agent this shell previously registered; re-registering while one
  # is active fails and silently leaves the old capability in place.
  echo "agent off";            sleep 0.3
  echo "agent NoInputNoOutput"; sleep 0.3
  echo "default-agent";        sleep 0.3

  # Scanning competes with pairing for the radio.
  echo "scan off";             sleep 0.5

  echo "pair $mac";            sleep 6
  echo "yes";                  sleep 2      # answers a confirmation if asked
  echo "trust $mac";           sleep 1
  echo "connect $mac";         sleep 4
  echo "quit"
}

output=$(feed | bluetoothctl 2>&1)

# bluetoothctl exits 0 almost regardless, so the transcript decides.
if printf '%s' "$output" | grep -qiE "Pairing successful|already.*paired|Connection successful"; then
  echo "paired"
  exit 0
fi

if printf '%s' "$output" | grep -qiE "Failed to pair|AuthenticationFailed|AuthenticationCanceled"; then
  reason=$(printf '%s' "$output" | grep -iE "Failed to pair|Authentication" | head -1)
  echo "failed: ${reason:-unknown}" >&2
  exit 1
fi

echo "failed: no confirmation from bluetoothctl" >&2
printf '%s\n' "$output" | tail -5 >&2
exit 1
