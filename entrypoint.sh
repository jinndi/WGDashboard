#!/usr/bin/env bash
# shellcheck disable=SC1091

# Load utils
. /scripts/utils.sh

# Paths
PID_FILE="${WGDASH}/gunicorn.pid"
DB_DIR="${WGDASH}/db"
CONFIG_FILE="${WGDASH}/wg-dashboard.ini"
LOG_DIR="${WGDASH}/log"

DATA_DIR="/data"
DATA_DB_DIR="$DATA_DIR/db"
DATA_CONFIG_FILE="${DATA_DIR}/wg-dashboard.ini"

PID_GUNICORN=""
PID_INOTIFY=""
PID_TAIL=""

validation_options(){
  echo -e "\n------------------------- START ----------------------------"
  log "Validating options..."

  if is_domain "${HOST:-}" || is_ip "${HOST:-}"; then
    log "HOST accept: ${HOST}"
  else
    local public_ip
    public_ip="$(get_public_ipv4)"
    [ -z "$public_ip" ] && exiterr "HOST not set"
    warn "HOST set by default on: ${public_ip}"
    HOST="${public_ip}"
  fi

  if is_port "${PORT:-}"; then
    log "PORT accept: ${PORT}"
  else
    warn "PORT set by default on: 10086"
    PORT="10086"
  fi

  if [[ -n "${ALLOW_FORWARD:-}" ]]; then
    if validate_tun_list "$ALLOW_FORWARD"; then
      log "ALLOW_FORWARD accept: ${ALLOW_FORWARD}"
    else
      exiterr "ALLOW_FORWARD must be a valid"
    fi
  fi

  echo "------------------------------------------------------------"
}

ensure_installation(){
  log "Quick-installing..."

  [ -f "$PID_FILE" ] && { log "Found stale pid, removing..."; rm "$PID_FILE"; }

  [ -d "$DATA_DB_DIR" ] || { log "Creating database dir"; mkdir -p "$DATA_DB_DIR"; }
  [ -d "$DB_DIR" ] || { log "Linking database dir"; ln -s "$DATA_DB_DIR" "$DB_DIR"; }

  [ -f "$DATA_CONFIG_FILE" ] || { log "Creating wg-dashboard.ini file"; touch "$DATA_CONFIG_FILE"; }
  [ -f "$CONFIG_FILE" ] || { log "Linking wg-dashboard.ini file"; ln -s "$DATA_CONFIG_FILE" "$CONFIG_FILE"; }
}

set_envvars(){
  echo -e "\n-------------- SETTING ENVIRONMENT VARIABLES ---------------"

  if [[ ! -s "${DATA_CONFIG_FILE}" ]]; then
    log "Config file is empty. Creating template."
    {
      echo "[Peers]"
      echo "peer_global_dns = 1.1.1.1"
      echo "remote_endpoint = ${HOST}"
      echo
      echo "[Server]"
      echo "app_port = ${PORT}"
      echo "app_prefix = /"
    } > "${DATA_CONFIG_FILE}"
    return 0
  else
    log "Config file is not empty, using pre-existing."
  fi

  set_envvar() {
    local var_name="$1"
    local var_value="$2"
    if grep -q "^${var_name} =" "$DATA_CONFIG_FILE"; then
      sed -i "s|^${var_name} = .*|${var_name} = ${var_value}|" "$DATA_CONFIG_FILE"
    fi
  }

  log "Verifying current variables..."

  check_and_update_var() {
    local var_name="$1"
    local var_value="$2"
    local current_value
    current_value=$(grep "^${var_name} = " "$DATA_CONFIG_FILE" | awk '{print $NF}')

    if [[ "$var_value" == "$current_value" ]]; then
      log "${var_name} is set correctly, moving on."
    else
      log "Changing default ${var_name}..."
      set_envvar "$var_name" "$var_value"
    fi
  }

  check_and_update_var "remote_endpoint" "${HOST}"
  check_and_update_var "app_port" "${PORT}"
}

start_core(){
  echo -e "\n---------------------- STARTING CORE -----------------------"
  log "Start WGDashboard"

  gunicorn --config ./gunicorn.conf.py &

  log "Waiting for Gunicorn PID file..."
  local checkPIDExist=0
  local timeout=40
  local waited=0

  while [ $checkPIDExist -eq 0 ]; do
    if [[ -f "$PID_FILE" ]]; then
      checkPIDExist=1
      PID_GUNICORN="$(cat "$PID_FILE")"
      log "Gunicorn PID file found, WGDashboard starting"
    else
      sleep 1
      waited=$((waited+1))
      if [ $waited -ge $timeout ]; then
        exiterr "Gunicorn PID file not found after $timeout seconds, exiting"
      fi
    fi
  done
  log "WGDashboard started successfully (PID: $PID_GUNICORN)"

  log "Apply iptables forwards"
  . /scripts/auto-iptables-forward.sh
}

ensure_blocking(){
  echo -e "\n------------------------ SHOW LOGS -------------------------"
  log "Ensuring container continuation."

  local latest_wgd_err_log
  latest_wgd_err_log=$(find "$LOG_DIR" -name "error_*.log" -type f -print | sort -r | head -n 1)

  if [[ -n "$latest_wgd_err_log" ]]; then
    tail -f "$latest_wgd_err_log" &
    PID_TAIL=$!
    log "Tailing logs (PID: $PID_TAIL)\n"
  else
    exiterr "No log files found to tail. Something went wrong, exiting..."
  fi

  while kill -0 "$PID_INOTIFY" 2>/dev/null || kill -0 "$PID_TAIL" 2>/dev/null; do
    sleep 1
  done
}

stop_all_proces() {
  log "Stopping services..."

  stop_process() {
    local name="$1"
    local pid="$2"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      log "Stopping $name (PID $pid)..."
      kill -TERM "$pid"
      local timeout=5
      while kill -0 "$pid" 2>/dev/null && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
      done
      if [[ "$name" != "gunicorn" ]] && kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null
      fi
    fi
  }

  stop_process "gunicorn" "$PID_GUNICORN"
  stop_process "inotify" "$PID_INOTIFY"
  stop_process "log tail" "$PID_TAIL"

  log "All services stopped"
  exit 1
}

trap 'stop_all_proces' SIGTERM SIGINT

validation_options
ensure_installation
set_envvars
start_core
ensure_blocking
