#!/bin/bash
set -euo pipefail

case "${NAME:-}" in
  aero.front_app)
    if [[ "${SENDER:-}" == front_app_switched && -n "${INFO:-}" ]]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
    ;;
  aero.clock)
    sketchybar --set "$NAME" label="$(/bin/date '+%a %H:%M')"
    ;;
  aero.battery)
    battery_text="$(/usr/bin/pmset -g batt | /usr/bin/awk -F ';' '/[0-9]+%/ {sub(/^.*\t/,"",$1); print $1; exit}')"
    if [[ -n "$battery_text" ]]; then
      sketchybar --set "$NAME" label="$battery_text" drawing=on
    else
      sketchybar --set "$NAME" drawing=off
    fi
    ;;
  aero.wifi)
    wifi_device="$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '/Hardware Port: (Wi-Fi|AirPort)/ {getline; print $2; exit}')"
    wifi_label='Wi-Fi unavailable'
    if [[ -n "$wifi_device" ]]; then
      wifi_power="$(/usr/sbin/networksetup -getairportpower "$wifi_device" 2>/dev/null || true)"
      case "$wifi_power" in
        *': On') wifi_label='Wi-Fi on' ;;
        *': Off') wifi_label='Wi-Fi off' ;;
      esac
    fi
    sketchybar --set "$NAME" label="$wifi_label"
    ;;
  aero.space.*)
    if [[ "${SELECTED:-false}" == true ]]; then
      sketchybar --set "$NAME" background.drawing=on
    else
      sketchybar --set "$NAME" background.drawing=off
    fi
    ;;
esac
