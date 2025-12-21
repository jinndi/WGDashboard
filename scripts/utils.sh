#!/usr/bin/env bash

log() {
  echo -e "$(date "+%Y-%m-%d %H:%M:%S") $1" >&2
}

warn(){
  log "⚠️ WARN: $1" >&2
}

exiterr() {
  log "❌ ERROR: $1"; exit 1 >&2
}

get_public_ipv4(){
  local public_ip
  public_ip="$(curl -4 -s ip.sb)"
  [ -z "$public_ip" ] && public_ip="$(curl -4 -s ifconfig.me)"
  [ -z "$public_ip" ] && public_ip="$(curl -4 -s https://api.ipify.org)"
  is_ipv4 "$public_ip" || public_ip=""
  echo "$public_ip"
}

is_port(){
  local port="$1"
  if [[ ! "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
    return 1
  else
    return 0
  fi
}

is_ipv4(){
  local ip="$1"
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    [[ "$octet" != "0" && "$octet" =~ ^0 ]] && return 1
    dec_octet=$((10#$octet))
    (( dec_octet >= 0 && dec_octet <= 255 )) || return 1
  done
  return 0
}

is_ipv6(){
  local ip="$1"
  [[ $ip =~ ^[0-9A-Fa-f:.]+$ ]] || return 1
  [[ $ip == *:* ]] || return 1
  [[ $ip != *:::* ]] || return 1
  [[ $ip != ::.* ]] || return 1
  if [[ $(grep -o "::" <<< "$ip" | wc -l) -gt 1 ]]; then
    return 1
  fi
  local expanded="$ip"
  if [[ $expanded == *::* ]]; then
    local head="${expanded%%::*}"
    local tail="${expanded##*::}"
    local head_groups tail_groups
    head_groups=$(grep -o ":" <<< "$head" | wc -l)
    tail_groups=$(grep -o ":" <<< "$tail" | wc -l)
    local total_groups=$((head_groups + tail_groups + 1))
    (( total_groups <= 8 )) || return 1
  else
    local group_count
    group_count=$(grep -o ":" <<< "$expanded" | wc -l)
    (( group_count == 7 )) || return 1
  fi
  IFS=':' read -r -a blocks <<< "$ip"
  for block in "${blocks[@]}"; do
    [[ -z "$block" ]] && continue
    [[ "$block" =~ ^[0-9A-Fa-f]{0,4}$ ]] || return 1
  done
  return 0
}

is_ip(){
  local value="$1"
  if is_ipv4 "$value" || is_ipv6 "$value"; then
    return 0
  fi
  return 1
}

is_domain(){
  local d="$1"
  local ascii
  ascii=$(idn2 "$d" 2>/dev/null) || return 1
  (( ${#ascii} <= 253 )) || return 1
  IFS='.' read -ra labels <<< "$ascii"
  for label in "${labels[@]}"; do
    (( ${#label} >= 1 && ${#label} <= 63 )) || return 1
    [[ $label =~ ^[a-z0-9-]+$ ]] || return 1
    [[ $label =~ ^-|-$ ]] && return 1
  done
  return 0
}

is_valid_tun_name(){
  local name="$1"
  [[ $name =~ ^[a-zA-Z0-9_=+.-]{1,15}$ ]]
}

validate_tun_list(){
  local list="$1"
  IFS=',' read -ra arr <<< "$list"
  for name in "${arr[@]}"; do
    if ! is_valid_tun_name "$name"; then
      warn "Invalid interface name: $name"
      return 1
    fi
  done
  return 0
}

