#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LANGUAGE="zh-CN"
TIMEOUT_SEC=10
SKIP_NETWORK=0
JSON_OUTPUT=0
CHECK_ONLY=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1 ;;
    --language) LANGUAGE="${2:-zh-CN}"; shift ;;
    --timeout) TIMEOUT_SEC="${2:-10}"; shift ;;
    --skip-network) SKIP_NETWORK=1 ;;
    --json) JSON_OUTPUT=1 ;;
  esac
  shift
done

case "$LANGUAGE" in
  zh-CN|en-US) ;;
  *) LANGUAGE="zh-CN" ;;
esac

TS="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$ROOT_DIR/logs"
REPORT_DIR="$ROOT_DIR/reports"
mkdir -p "$LOG_DIR" "$REPORT_DIR"
LOG_FILE="$LOG_DIR/run-$TS-wsl.log"
JSON_REPORT="$REPORT_DIR/report-$TS-wsl.json"
MD_REPORT="$REPORT_DIR/report-$TS-wsl.md"

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

append_json_item() {
  local item="$1"
  if [ -n "$CHECKS_JSON" ]; then
    CHECKS_JSON="$CHECKS_JSON,"
  fi
  CHECKS_JSON="$CHECKS_JSON$item"
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

check_tool() {
  local name="$1" cmd="$2" arg="${3:---version}" out rc status value
  if command -v "$cmd" >/dev/null 2>&1; then
    out="$(run_capture "$cmd" "$arg")"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      status="OK"
      value="$(mask_proxy "$out" | head -n 1)"
    elif [ "$rc" -eq 124 ]; then
      status="TIMEOUT"
      value="timeout"
    else
      status="ERROR"
      value="$(mask_proxy "$out" | head -n 1)"
    fi
  else
    status="MISSING"
    value="command not found"
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
      if [ -n "$PROXY_ENV_JSON" ]; then PROXY_ENV_JSON="$PROXY_ENV_JSON,"; fi
      PROXY_ENV_JSON="$PROXY_ENV_JSON{\"name\":\"$name\",\"value\":\"$(json_escape "$masked")\"}"
      case "$name" in
        HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy)
          if [ -z "$RECOMMENDED_URL" ]; then
            RECOMMENDED_URL="$masked"
            RECOMMENDED_SOURCE="Environment:$name"
            RECOMMENDED_PROTOCOL="$(printf '%s' "$masked" | sed -E 's#^([A-Za-z0-9+.-]+)://.*#\1#')"
            RECOMMENDED_CONFIDENCE="medium"
            RECOMMENDED_USABLE="true"
          fi
          ;;
      esac
    fi
  done
}

detect_proxy_command() {
  local label="$1" cmd="$2" key="$3" out rc masked
  if command -v "$cmd" >/dev/null 2>&1; then
    out="$(run_capture "$cmd" config --global --get "$key")"
    rc=$?
    if [ "$label" = "npm" ]; then
      out="$(run_capture "$cmd" config get "$key")"
      rc=$?
    fi
    if [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$out" != "null" ] && [ "$out" != "undefined" ]; then
      masked="$(mask_proxy "$out")"
      log "proxy $label $key=$masked"
      printf '| %s:%s | %s |\n' "$label" "$key" "$masked" >> "$MD_REPORT"
      if [ -z "$RECOMMENDED_URL" ]; then
        RECOMMENDED_URL="$masked"
        RECOMMENDED_SOURCE="$label:$key"
        RECOMMENDED_PROTOCOL="$(printf '%s' "$masked" | sed -E 's#^([A-Za-z0-9+.-]+)://.*#\1#')"
        RECOMMENDED_CONFIDENCE="medium"
        RECOMMENDED_USABLE="true"
      fi
    fi
  fi
}

detect_local_ports() {
  local ports port reachable protocol url http_rc socks_rc item
  ports="7890 7891 7897 1080 10808 10809 10870 10871 20170 20171 2080 3128 8000 8080 8888 9090"
  for port in $ports; do
    reachable=0
    if tcp_check 127.0.0.1 "$port" || tcp_check localhost "$port"; then
      reachable=1
    fi
    protocol="unknown"
    url=""
    if [ "$reachable" -eq 1 ]; then
      if [ "$SKIP_NETWORK" -eq 0 ] && command -v curl >/dev/null 2>&1; then
        run_capture curl -x "http://127.0.0.1:$port" -I https://github.com --max-time 8 >/dev/null
        http_rc=$?
        if [ "$http_rc" -eq 0 ]; then
          protocol="http"
          url="http://127.0.0.1:$port"
        else
          run_capture curl -x "socks5h://127.0.0.1:$port" -I https://github.com --max-time 8 >/dev/null
          socks_rc=$?
          if [ "$socks_rc" -eq 0 ]; then
            protocol="socks5h"
            url="socks5h://127.0.0.1:$port"
          fi
        fi
      fi
      if [ -z "$url" ]; then
        url="tcp://127.0.0.1:$port"
      fi
      log "local proxy port=$port protocol=$protocol url=$url"
      printf '| local:%s | %s |\n' "$port" "$protocol" >> "$MD_REPORT"
      if [ -z "$RECOMMENDED_URL" ]; then
        RECOMMENDED_URL="$url"
        RECOMMENDED_SOURCE="LocalPortScan"
        RECOMMENDED_PROTOCOL="$protocol"
        RECOMMENDED_PORT="$port"
        RECOMMENDED_CONFIDENCE="low"
        RECOMMENDED_USABLE="true"
      fi
    fi
    item="{\"port\":$port,\"tcpReachable\":$([ "$reachable" -eq 1 ] && echo true || echo false),\"protocol\":\"$protocol\",\"url\":\"$(json_escape "$url")\"}"
    if [ -n "$LOCAL_SCAN_JSON" ]; then LOCAL_SCAN_JSON="$LOCAL_SCAN_JSON,"; fi
    LOCAL_SCAN_JSON="$LOCAL_SCAN_JSON$item"
  done
}

log "WSL check started language=$LANGUAGE timeout=$TIMEOUT_SEC skip_network=$SKIP_NETWORK"

cat > "$MD_REPORT" <<MD
# WSL Environment Check Report

| Field | Value |
|-------|-------|
| Language | $LANGUAGE |
| CheckOnly | $CHECK_ONLY |
| Timestamp | $TS |
| Log | \`$LOG_FILE\` |

## System

| Check | Status | Value |
|-------|--------|-------|
MD

if grep -qi microsoft /proc/version 2>/dev/null; then
  append_json_item "{\"name\":\"wsl\",\"status\":\"OK\",\"value\":\"true\"}"
  printf '| WSL | OK | true |\n' >> "$MD_REPORT"
else
  append_json_item "{\"name\":\"wsl\",\"status\":\"WARNING\",\"value\":\"not detected\"}"
  printf '| WSL | WARNING | not detected |\n' >> "$MD_REPORT"
fi

[ -n "${WSL_DISTRO_NAME-}" ] && distro="$WSL_DISTRO_NAME" || distro="unknown"
append_json_item "{\"name\":\"distro\",\"status\":\"OK\",\"value\":\"$(json_escape "$distro")\"}"
printf '| Distro | OK | %s |\n' "$distro" >> "$MD_REPORT"

kernel="$(uname -r 2>/dev/null || true)"
append_json_item "{\"name\":\"kernel\",\"status\":\"OK\",\"value\":\"$(json_escape "$kernel")\"}"
printf '| Kernel | OK | %s |\n' "$kernel" >> "$MD_REPORT"

printf '\n## Tools\n\n| Tool | Status | Value |\n|------|--------|-------|\n' >> "$MD_REPORT"
check_tool "bash" "bash" "--version"
check_tool "zsh" "zsh" "--version"
check_tool "node" "node" "--version"
check_tool "npm" "npm" "--version"
check_tool "git" "git" "--version"
check_tool "curl" "curl" "--version"
check_tool "code" "code" "--version"
check_tool "claude" "claude" "--version"
check_tool "codex" "codex" "--version"
check_tool "docker" "docker" "--version"

printf '\n## WSL Interop\n\n| Check | Status | Value |\n|-------|--------|-------|\n' >> "$MD_REPORT"
if [ -d /mnt/c ]; then
  printf '| /mnt/c | OK | accessible |\n' >> "$MD_REPORT"
  append_json_item "{\"name\":\"mnt_c\",\"status\":\"OK\",\"value\":\"accessible\"}"
else
  printf '| /mnt/c | WARNING | not accessible |\n' >> "$MD_REPORT"
  append_json_item "{\"name\":\"mnt_c\",\"status\":\"WARNING\",\"value\":\"not accessible\"}"
fi

case "$PWD" in
  /mnt/*) mixed_note="project is on Windows-mounted filesystem" ;;
  *) mixed_note="project is on Linux filesystem" ;;
esac
printf '| Project path | OK | %s |\n' "$mixed_note" >> "$MD_REPORT"
append_json_item "{\"name\":\"project_path\",\"status\":\"OK\",\"value\":\"$(json_escape "$mixed_note")\"}"

printf '\n## Proxy\n\n| Source | Value |\n|--------|-------|\n' >> "$MD_REPORT"
detect_proxy_env
detect_proxy_command "npm" "npm" "proxy"
detect_proxy_command "npm" "npm" "https-proxy"
detect_proxy_command "git" "git" "http.proxy"
detect_proxy_command "git" "git" "https.proxy"
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
    "Platform": "wsl",
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
