#!/usr/bin/env bash

# ---------------------------------------------------
# Colors
# ---------------------------------------------------
C_RESET="\033[0m"
C_HEADER="\033[34m"     # blue
C_KEY="\033[32m"        # green
C_DETECTED="\033[35m"   # purple/magenta

# ---------------------------------------------------
# Flags
# ---------------------------------------------------
ONLY4=0
ONLY6=0
RAW=0

usage() {
  echo "Usage: wanip [-4] [-6] [--raw]"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -4) ONLY4=1 ;;
    -6) ONLY6=1 ;;
    --raw) RAW=1 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
  shift
done

# ---------------------------------------------------
# Connection Type Detection
# ---------------------------------------------------
detect_type() {
  local org_lc=$(echo "$1" | tr '[:upper:]' '[:lower:]')

  if echo "$org_lc" | grep -q "starlink"; then
    if echo "$org_lc" | grep -Eq "residential"; then echo "Starlink Residential"; return; fi
    if echo "$org_lc" | grep -Eq "business|premium"; then echo "Starlink Business"; return; fi
    if echo "$org_lc" | grep -Eq "mobility|mobile|rv"; then echo "Starlink Mobility"; return; fi
    if echo "$org_lc" | grep -q "maritime"; then echo "Starlink Maritime"; return; fi
    if echo "$org_lc" | grep -q "aviation"; then echo "Starlink Aviation"; return; fi
    echo "Starlink"; return
  fi

  if echo "$org_lc" | grep -q "cloudflare"; then echo "Cloudflare / WARP"; return; fi
  if echo "$org_lc" | grep -Eq "vpn|nord|proton|mullvad|private internet|pia|express|surfshark|cyberghost"; then echo "VPN"; return; fi
  if echo "$org_lc" | grep -Eq "amazon|aws|google|digitalocean|linode|microsoft|ovh|contabo|hetzner"; then echo "Hosting Provider"; return; fi

  echo ""
}

# ---------------------------------------------------
# Raw JSON Mode
# ---------------------------------------------------
raw_output() {
  raw=$(curl -s "https://ipinfo.io/$1/json" | sed '/"readme"/d')

  org=$(echo "$raw" | grep -o '"org": *"[^"]*"' | sed 's/"org": "//; s/"$//')
  detected=$(detect_type "$org")

  if [[ -n "$detected" ]]; then
    echo "$raw" | jq --arg dt "$detected" '. + { detected_type: $dt }'
  else
    echo "$raw"
  fi
}

# ---------------------------------------------------
# Pretty Human Output
# ---------------------------------------------------
pretty_output() {
  local section="$1"
  local ip="$2"

  raw=$(curl -s "https://ipinfo.io/$ip/json" | sed '/"readme"/d')

  echo -e "${C_HEADER}==============================="
  echo "          $section"
  echo -e "===============================${C_RESET}"

  # JSON → readable text
  cleaned=$(echo "$raw" \
    | sed 's/[{}"]//g' \
    | sed 's/^ *//g' \
    | sed '/^$/d'
  )

  # Remove *JSON commas only* — keep commas inside values intact
  cleaned=$(echo "$cleaned" \
    | sed 's/,$//g' \
    | sed 's/: /:/g'
  )

  # Print with color
  while IFS= read -r line; do
    key="${line%%:*}"
    val="${line#*:}"
    echo -e "${C_KEY}${key}${C_RESET}: ${val}"
  done <<< "$cleaned"

  # Detection type
  org=$(echo "$raw" | grep -o '"org": *"[^"]*"' | sed 's/"org": "//; s/"$//')
  detected=$(detect_type "$org")

  if [[ -n "$detected" ]]; then
    echo -e "${C_DETECTED}detected type:${C_RESET} ${detected}"
  fi

  echo
}

# ---------------------------------------------------
# Lookup Helper
# ---------------------------------------------------
lookup() {
  local curlflag="$1"
  local url="$2"
  local label="$3"

  ip=$(curl $curlflag -s "$url")
  [[ -z "$ip" ]] && return

  if [[ $RAW -eq 1 ]]; then
    raw_output "$ip"
  else
    pretty_output "$label" "$ip"
  fi
}

# ---------------------------------------------------
# Execute Lookups
# ---------------------------------------------------
[[ $ONLY6 -eq 0 ]] && lookup "-4" "https://ipinfo.io/ip" "IPv4"
[[ $ONLY4 -eq 0 ]] && lookup "-6" "https://v6.ipinfo.io/ip" "IPv6"
