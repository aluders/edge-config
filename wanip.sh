#!/usr/bin/env bash

# Colors
BOLD="\033[1m"
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

# Detect jq for pretty JSON
if command -v jq >/dev/null 2>&1; then
  JQ=1
else
  JQ=0
fi

print_json() {
  if [[ $JQ -eq 1 ]]; then
    echo "$1" | jq .
  else
    echo "$1"
  fi
}

usage() {
  echo "Usage: wanip [options]"
  echo ""
  echo "Options:"
  echo "  -4        Only show IPv4"
  echo "  -6        Only show IPv6"
  echo "  -info     Show IP info only (requires -4 or -6)"
  echo "  -h        Show help"
  exit 0
}

# Parse flags
ONLY4=0
ONLY6=0
INFOONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -4) ONLY4=1 ;;
    -6) ONLY6=1 ;;
    -info) INFOONLY=1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option $1"; usage ;;
  esac
  shift
done

echo -e "${BOLD}${CYAN}==============================="
echo "        WAN IP LOOKUP"
echo "===============================${RESET}"

# ------------------------
# Get IPv4
# ------------------------
if [[ $ONLY6 -eq 0 ]]; then
  ipv4=$(curl -4 -s https://ipinfo.io/ip)

  echo -e "${BOLD}${GREEN}IPv4 Address:${RESET}"
  if [[ -n "$ipv4" ]]; then
    echo "  $ipv4"
    if [[ $INFOONLY -eq 0 ]]; then
      echo -e "${YELLOW}IPv4 Details:${RESET}"
      json=$(curl -s "https://ipinfo.io/$ipv4")
      print_json "$json"
    fi
  else
    echo -e "  ${RED}Not available${RESET}"
  fi

  echo
fi

# ------------------------
# Get IPv6
# ------------------------
if [[ $ONLY4 -eq 0 ]]; then
  ipv6=$(curl -6 -s https://v6.ipinfo.io/ip)

  echo -e "${BOLD}${GREEN}IPv6 Address:${RESET}"
  if [[ -n "$ipv6" ]]; then
    echo "  $ipv6"
    if [[ $INFOONLY -eq 0 ]]; then
      echo -e "${YELLOW}IPv6 Details:${RESET}"
      json=$(curl -s "https://ipinfo.io/$ipv6")
      print_json "$json"
    fi
  else
    echo -e "  ${RED}Not available${RESET}"
  fi

  echo
fi

echo -e "${CYAN}===============================${RESET}"
