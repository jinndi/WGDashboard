#!/usr/bin/env bash

WATCH_DIRS=("/etc/wireguard" "/etc/amnezia/amneziawg")

# WG interface(s) with allowed traffic
ALLOW_FORWARD=${ALLOW_FORWARD:-}

# NET interface with allowed traffic
NET_IFACE=${NET_IFACE:-}
if [ -z "$NET_IFACE" ]; then
  NET_IFACE=$(route 2>/dev/null | grep -m 1 '^default' | grep -o '[^ ]*$')
  [ -z "$NET_IFACE" ] && NET_IFACE=$(ip -4 route list 0/0 2>/dev/null | grep -m 1 -Po '(?<=dev )(\S+)')
  [ -z "$NET_IFACE" ] && NET_IFACE=eth0
fi

# Function to add/delete iptables a rules
apply_forward_rules() {
  local WG_IFACE="$1"
  local action="$2" # -A or -D

  [[ -z "$WG_IFACE" ]] || [[ -z "$action" ]] && \
    exiterr "[auto-iptables-forward.sh] Usage: apply_forward_rules <WG_IFACE> <-A|-D>"

  # --- 1. Allow traffic to/from the exempt interface (singbox) ---
  iptables "$action" FORWARD -i "$WG_IFACE" -o "$NET_IFACE" -j ACCEPT || true
  iptables "$action" FORWARD -i "$NET_IFACE" -o "$WG_IFACE" -j ACCEPT || true

  ip6tables "$action" FORWARD -i "$WG_IFACE" -o "$NET_IFACE" -j ACCEPT || true
  ip6tables "$action" FORWARD -i "$NET_IFACE" -o "$WG_IFACE" -j ACCEPT || true

  if [[ -n "$ALLOW_FORWARD" ]] && [[ ",${ALLOW_FORWARD// /}," =~ ,$WG_IFACE, ]]; then
    # --- 2. Allow all traffic if WG_IFACE is in ALLOW_FORWARD ---
    iptables "$action" FORWARD -i "$WG_IFACE" -j ACCEPT || true
    iptables "$action" FORWARD -o "$WG_IFACE" -j ACCEPT || true

    ip6tables "$action" FORWARD -i "$WG_IFACE" -j ACCEPT || true
    ip6tables "$action" FORWARD -o "$WG_IFACE" -j ACCEPT || true
  else
    # --- 3. Block peer-to-peer traffic inside the WireGuard interface ---
    iptables "$action" FORWARD -i "$WG_IFACE" -o "$WG_IFACE" -j DROP || true

    ip6tables "$action" FORWARD -i "$WG_IFACE" -o "$WG_IFACE" -j DROP || true

    # --- 4. Block all traffic from WG_IFACE to all other interfaces except NET_IFACE ---
    iptables "$action" FORWARD -i "$WG_IFACE" ! -o "$NET_IFACE" -j DROP || true
    iptables "$action" FORWARD ! -i "$NET_IFACE" -o "$WG_IFACE" -j DROP || true

    ip6tables "$action" FORWARD -i "$WG_IFACE" ! -o "$NET_IFACE" -j DROP || true
    ip6tables "$action" FORWARD ! -i "$NET_IFACE" -o "$WG_IFACE" -j DROP || true
  fi

  # --- 5. Logging ---
  if [[ "$action" == "-A" ]]; then
    log "[+] iptables FORWARD rules added for interface: $WG_IFACE"
  else
    log "[-] iptables FORWARD rules removed for interface: $WG_IFACE"
  fi
}

# Initial pass through files
for dir in "${WATCH_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*.conf; do
    [ -f "$f" ] || continue
    iface=$(basename "$f" .conf)
    apply_forward_rules "$iface" "-A"
  done
done

# Start monitoring
inotifywait -m -e create -e delete "${WATCH_DIRS[@]}" --format '%e %w%f' |
while read -r event file; do
  case "$event" in
    CREATE|MOVED_TO)
      iface=$(basename "$file" .conf)
      [[ "$file" == *.conf ]] && apply_forward_rules "$iface" "-A"
    ;;
    DELETE|MOVED_FROM)
      iface=$(basename "$file" .conf)
      [[ "$file" == *.conf ]] && apply_forward_rules "$iface" "-D"
    ;;
  esac
done &
# shellcheck disable=SC2034
PID_INOTIFY=$!
