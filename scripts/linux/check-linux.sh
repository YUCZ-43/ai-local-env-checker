#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LANGUAGE="zh-CN"
TIMEOUT_SEC=10
SKIP_NETWORK=0
JSON_OUTPUT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only) ;;
    --language) LANGUAGE="${2:-zh-CN}"; shift ;;
    --timeout) TIMEOUT_SEC="${2:-10}"; shift ;;
    --skip-network) SKIP_NETWORK=1 ;;
    --json) JSON_OUTPUT=1 ;;
  esac
  shift
done

case "$LANGUAGE" in zh-CN|en-US) ;; *) LANGUAGE="zh-CN" ;; esac

TS="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$ROOT_DIR/logs"
REPORT_DIR="$ROOT_DIR/reports"
mkdir -p "$LOG_DIR" "$REPORT_DIR"
LOG_FILE="$LOG_DIR/run-$TS-linux.log"
JSON_REPORT="$REPORT_DIR/report-$TS-linux.json"
MD_REPORT="$REPORT_DIR/report-$TS-linux.md"

mask_proxy() {
  printf '%s' "${1:-}" | sed -E 's#([A-Za-z][A-Za-z0-9+.-]*://)[^/@:[:space:]]+:[^/@[:space:]]+@#\1***:***@#g'
}

json_escape() {
  local s
  s="$(mask_proxy "${1:-}")"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$(mask_proxy "$*")" >> "$LOG_FILE"
}

run_capture() {
  local tmp pid elapsed rc
  tmp="$LOG_DIR/.cmd-$TS-$RANDOM.tmp"
  "$@" > "$tmp" 2>&1 &
  pid=$!
  elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$elapsed" -ge "$TIMEOUT_SEC" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      cat "$tmp"
      rm -f "$tmp"
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid"
  rc=$?
  cat "$tmp"
  rm -f "$tmp"
  return "$rc"
}

tcp_check() {
  local host="$1" port="$2" tmp pid elapsed rc
  tmp="$LOG_DIR/.tcp-$TS-$RANDOM.tmp"
  ( : > "/dev/tcp/$host/$port" ) > "$tmp" 2>&1 &
  pid=$!
  elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$elapsed" -ge 2 ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      rm -f "$tmp"
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid"
  rc=$?
  rm -f "$tmp"
  return "$rc"
}

CHECKS_JSON=""
PROXY_ENV_JSON=""
LOCAL_SCAN_JSON=""
RECOMMENDED_URL=""
RECOMMENDED_PROTOCOL=""
RECOMMENDED_SOURCE=""
RECOMMENDED_PORT=""
RECOMMENDED_CONFIDENCE="none"
RECOMMENDED_USABLE="false"

append_json_item() {
  local item="$1"
  [ -n "$CHECKS_JSON" ] && CHECKS_JSON="$CHECKS_JSON,"
  CHECKS_JSON="$CHECKS_JSON$item"
}

check_tool() {
  local name="$1" cmd="$2" arg="${3:---version}" out rc status value
  if command -v "$cmd" >/dev/null 2>&1; then
    out="$(run_capture "$cmd" "$arg")"
    rc=$?
    if [ "$rc" -eq 0 ]; then status="OK"; value="$(mask_proxy "$out" | head -n 1)"
    elif [ "$rc" -eq 124 ]; then status="TIMEOUT"; value="timeout"
    else status="ERROR"; value="$(mask_proxy "$out" | head -n 1)"; fi
  else
    status="MISSING"; value="command not found"
  fi
  log "$name status=$status value=$value"
  printf '| %s | %s | %s |\n' "$name" "$status" "$value" >> "$MD_REPORT"
  append_json_item "{\"name\":\"$(json_escape "$name")\",\"status\":\"$status\",\"value\":\"$(json_escape "$value")\"}"
}

detect_proxy_env() {
  local vars name value masked
  vars="HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy"
  for name in $vars; do
    value="${!name-}"
    if [ -n "$value" ]; then
      masked="$(mask_proxy "$value")"
      log "proxy env $name=$masked"
      printf '| env:%s | %s |\n' "$name" "$masked" >> "$MD_REPORT"
      [ -n "$PROXY_ENV_JSON" ] && PROXY_ENV_JSON="$PROXY_ENV_JSON,"
      PROXY_ENV_JSON="$PROXY_ENV_JSON{\"name\":\"$name\",\"value\":\"$(json_escape "$masked")\"}"
      case "$name" in
        HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy)
          if [ -z "$RECOMMENDED_URL" ]; then
            RECOMMENDED_URL="$masked"; RECOMMENDED_SOURCE="Environment:$name"
            RECOMMENDED_PROTOCOL="$(printf '%s' "$masked" | sed -E 's#^([A-Za-z0-9+.-]+)://.*#\1#')"
            RECOMMENDED_CONFIDENCE="medium"; RECOMMENDED_USABLE="true"
          fi
          ;;
      esac
    fi
  done
}

detect_proxy_command() {
  local label="$1" cmd="$2" key="$3" out rc masked
  if command -v "$cmd" >/dev/null 2>&1; then
    if [ "$label" = "npm" ]; then out="$(run_capture "$cmd" config get "$key")"; rc=$?
    else out="$(run_capture "$cmd" config --global --get "$key")"; rc=$?; fi
    if [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$out" != "null" ] && [ "$out" != "undefined" ]; then
      masked="$(mask_proxy "$out")"
      log "proxy $label $key=$masked"
      printf '| %s:%s | %s |\n' "$label" "$key" "$masked" >> "$MD_REPORT"
      if [ -z "$RECOMMENDED_URL" ]; then
        RECOMMENDED_URL="$masked"; RECOMMENDED_SOURCE="$label:$key"
        RECOMMENDED_PROTOCOL="$(printf '%s' "$masked" | sed -E 's#^([A-Za-z0-9+.-]+)://.*#\1#')"
        RECOMMENDED_CONFIDENCE="medium"; RECOMMENDED_USABLE="true"
      fi
    fi
  fi
}

detect_gsettings_proxy() {
  local mode host port value
  if command -v gsettings >/dev/null 2>&1; then
    mode="$(run_capture gsettings get org.gnome.system.proxy mode || true)"
    log "gsettings proxy mode=$mode"
    printf '| gsettings:mode | %s |\n' "$(mask_proxy "$mode")" >> "$MD_REPORT"
    for schema in http https socks; do
      host="$(run_capture gsettings get "org.gnome.system.proxy.$schema" host || true)"
      port="$(run_capture gsettings get "org.gnome.system.proxy.$schema" port || true)"
      host="$(printf '%s' "$host" | tr -d "'")"
      port="$(printf '%s' "$port" | tr -dc '0-9')"
      if [ -n "$host" ] && [ -n "$port" ]; then
        value="$schema://$host:$port"
        printf '| gsettings:%s | %s |\n' "$schema" "$(mask_proxy "$value")" >> "$MD_REPORT"
      fi
    done
  fi
}

detect_local_ports() {
  local ports port reachable protocol url http_rc socks_rc
  ports="7890 7891 7897 1080 10808 10809 10870 10871 20170 20171 2080 3128 8000 8080 8888 9090"
  for port in $ports; do
    reachable=0
    if tcp_check 127.0.0.1 "$port" || tcp_check localhost "$port"; then reachable=1; fi
    protocol="unknown"; url=""
    if [ "$reachable" -eq 1 ]; then
      if [ "$SKIP_NETWORK" -eq 0 ] && command -v curl >/dev/null 2>&1; then
        run_capture curl -x "http://127.0.0.1:$port" -I https://github.com --max-time 8 >/dev/null; http_rc=$?
        if [ "$http_rc" -eq 0 ]; then protocol="http"; url="http://127.0.0.1:$port"
        else run_capture curl -x "socks5h://127.0.0.1:$port" -I https://github.com --max-time 8 >/dev/null; socks_rc=$?
          [ "$socks_rc" -eq 0 ] && protocol="socks5h" && url="socks5h://127.0.0.1:$port"; fi
      fi
      [ -z "$url" ] && url="tcp://127.0.0.1:$port"
      printf '| local:%s | %s |\n' "$port" "$protocol" >> "$MD_REPORT"
      if [ -z "$RECOMMENDED_URL" ]; then
        RECOMMENDED_URL="$url"; RECOMMENDED_SOURCE="LocalPortScan"; RECOMMENDED_PROTOCOL="$protocol"
        RECOMMENDED_PORT="$port"; RECOMMENDED_CONFIDENCE="low"; RECOMMENDED_USABLE="true"
      fi
    fi
    [ -n "$LOCAL_SCAN_JSON" ] && LOCAL_SCAN_JSON="$LOCAL_SCAN_JSON,"
    LOCAL_SCAN_JSON="$LOCAL_SCAN_JSON{\"port\":$port,\"tcpReachable\":$([ "$reachable" -eq 1 ] && echo true || echo false),\"protocol\":\"$protocol\",\"url\":\"$(json_escape "$url")\"}"
  done
}

log "Linux check started language=$LANGUAGE timeout=$TIMEOUT_SEC skip_network=$SKIP_NETWORK"

cat > "$MD_REPORT" <<MD
# Linux Environment Check Report

| Field | Value |
|-------|-------|
| Language | $LANGUAGE |
| Timestamp | $TS |
| Log | \`$LOG_FILE\` |

## System

| Check | Status | Value |
|-------|--------|-------|
MD

if [ -f /etc/os-release ]; then
  distro="$(. /etc/os-release; printf '%s %s' "${NAME:-unknown}" "${VERSION_ID:-}")"
else
  distro="unknown"
fi
printf '| Distribution | OK | %s |\n' "$distro" >> "$MD_REPORT"
append_json_item "{\"name\":\"distribution\",\"status\":\"OK\",\"value\":\"$(json_escape "$distro")\"}"
printf '| Kernel | OK | %s |\n' "$(uname -r)" >> "$MD_REPORT"
append_json_item "{\"name\":\"kernel\",\"status\":\"OK\",\"value\":\"$(json_escape "$(uname -r)")\"}"
printf '| User | OK | %s |\n' "$(id -un)" >> "$MD_REPORT"
append_json_item "{\"name\":\"user\",\"status\":\"OK\",\"value\":\"$(json_escape "$(id -un)")\"}"
if [ "$(id -u)" -eq 0 ]; then root_status="root"; else root_status="non-root"; fi
printf '| Privilege | OK | %s |\n' "$root_status" >> "$MD_REPORT"
command -v sudo >/dev/null 2>&1 && sudo_status="available" || sudo_status="missing"
printf '| sudo | OK | %s |\n' "$sudo_status" >> "$MD_REPORT"

printf '\n## Package Managers\n\n| Tool | Status | Value |\n|------|--------|-------|\n' >> "$MD_REPORT"
for pm in apt dnf yum pacman zypper snap flatpak; do check_tool "$pm" "$pm" "--version"; done

printf '\n## Shells and Tools\n\n| Tool | Status | Value |\n|------|--------|-------|\n' >> "$MD_REPORT"
for tool in bash zsh fish curl wget git unzip tar node npm npx code claude codex docker; do check_tool "$tool" "$tool" "--version"; done
if command -v docker >/dev/null 2>&1; then check_tool "docker compose" "docker" "compose"; fi

printf '\n## PATH\n\n\`\`\`\n%s\n\`\`\`\n' "$PATH" >> "$MD_REPORT"

printf '\n## Proxy\n\n| Source | Value |\n|--------|-------|\n' >> "$MD_REPORT"
detect_proxy_env
detect_proxy_command "npm" "npm" "proxy"
detect_proxy_command "npm" "npm" "https-proxy"
detect_proxy_command "git" "git" "http.proxy"
detect_proxy_command "git" "git" "https.proxy"
detect_gsettings_proxy
detect_local_ports

if [ "$SKIP_NETWORK" -eq 0 ]; then
  printf '\n## Network\n\n| Target | Status |\n|--------|--------|\n' >> "$MD_REPORT"
  if tcp_check github.com 443; then
    printf '| github.com:443 | OK |\n' >> "$MD_REPORT"
    append_json_item "{\"name\":\"github_443\",\"status\":\"OK\",\"value\":\"reachable\"}"
  else
    printf '| github.com:443 | WARNING |\n' >> "$MD_REPORT"
    append_json_item "{\"name\":\"github_443\",\"status\":\"WARNING\",\"value\":\"unreachable\"}"
  fi
fi

cat > "$JSON_REPORT" <<JSON
{
  "Meta": {
    "Platform": "linux",
    "Timestamp": "$TS",
    "Language": "$LANGUAGE",
    "CheckOnly": true,
    "TimeoutSec": $TIMEOUT_SEC,
    "LogFile": "$(json_escape "$LOG_FILE")"
  },
  "Checks": [$CHECKS_JSON],
  "Proxy": {
    "Environment": [$PROXY_ENV_JSON],
    "Npm": {},
    "Git": {},
    "WinHTTP": {},
    "WindowsInternetSettings": {},
    "LocalPortScan": [$LOCAL_SCAN_JSON],
    "RecommendedProxy": {
      "Url": "$(json_escape "$RECOMMENDED_URL")",
      "Protocol": "$(json_escape "$RECOMMENDED_PROTOCOL")",
      "Host": "127.0.0.1",
      "Port": "$(json_escape "$RECOMMENDED_PORT")",
      "Source": "$(json_escape "$RECOMMENDED_SOURCE")",
      "Confidence": "$RECOMMENDED_CONFIDENCE",
      "IsUsable": $RECOMMENDED_USABLE,
      "Notes": ["detection only; no proxy settings were modified"]
    }
  }
}
JSON

log "reports saved json=$JSON_REPORT md=$MD_REPORT"

if [ "$JSON_OUTPUT" -eq 1 ]; then
  cat "$JSON_REPORT"
else
  printf 'Log: %s\nJSON: %s\nMarkdown: %s\n' "$LOG_FILE" "$JSON_REPORT" "$MD_REPORT"
fi

exit 0
