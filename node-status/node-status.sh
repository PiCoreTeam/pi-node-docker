#!/bin/bash
set -euo pipefail

# ── Constants ──

readonly CORE_URL="http://localhost:11626"
readonly HORIZON_URL="http://localhost:8000"
readonly CURL_TIMEOUT=5
readonly HORIZON_LOG_DIR="/var/log/supervisor"

# ── Helpers ──

header() {
  echo ""
  echo "=== $1 ==="
}

# Print a labeled field with consistent alignment.
# Usage: field <width> <label> <value>
field() {
  local width="$1" label="$2" value="$3"
  printf "  %-${width}s  %s\n" "${label}:" "$value"
}

# Fetch JSON from a URL. Returns empty string on failure.
fetch_json() {
  curl -sf --max-time "$CURL_TIMEOUT" "$1" 2>/dev/null || echo ""
}

# Extract a value from JSON via jq. Returns "N/A" on failure.
# Usage: jq_val <json> <jq_filter>
jq_val() {
  local json="$1" filter="$2"
  if [ -z "$json" ]; then
    echo "N/A"
    return
  fi
  echo "$json" | jq -r "$filter // empty" 2>/dev/null || echo "N/A"
}

# Compute sync state: Catching Up / Not Running / Syncing / Synced.
# Usage: sync_state <core_latest> <ingest_latest>
sync_state() {
  local core="$1" ingest="$2"

  if [ "$ingest" = "N/A" ] || [ "$core" = "N/A" ]; then
    echo "Not Running"
    return
  fi

  if [ "$ingest" -le 0 ] 2>/dev/null; then
    if [ "$core" -le 0 ] 2>/dev/null; then
      echo "Catching Up"
    else
      echo "Not Running"
    fi
    return
  fi

  local gap=$(( core - ingest ))
  if [ "$gap" -lt 0 ]; then
    gap=$(( -gap ))
  fi

  if [ "$gap" -le 5 ]; then
    echo "Synced"
  else
    echo "Syncing"
  fi
}

# ── Sections ──

show_services() {
  header "Services"

  local raw
  raw=$(supervisorctl status 2>/dev/null) || true

  if [ -z "$raw" ]; then
    echo "  Status: supervisord not responding"
    return
  fi

  # supervisorctl output format: "name STATE info..."
  # Reformat each line for consistent alignment.
  local max_name=0 name
  while IFS= read -r line; do
    name="${line%% *}"
    (( ${#name} > max_name )) && max_name=${#name}
  done <<< "$raw"

  local state info
  while IFS= read -r line; do
    name="${line%% *}"
    line="${line#"$name"}"
    # Trim leading spaces to get STATE
    line="${line#"${line%%[![:space:]]*}"}"
    state="${line%% *}"
    info="${line#"$state"}"
    info="${info#"${info%%[![:space:]]*}"}"
    printf "  %-$(( max_name + 1 ))s  %-10s %s\n" "${name}:" "$state" "$info"
  done <<< "$raw"
}

show_protocol() {
  header "Protocol"

  local json
  json=$(fetch_json "${CORE_URL}/info")

  if [ -z "$json" ]; then
    echo "  Status: Not responding"
    return
  fi

  local w=14
  local ledger_version ledger_num
  ledger_version=$(jq_val "$json" '.info.ledger.version')
  ledger_num=$(jq_val "$json" '.info.ledger.num')

  local protocol_display="$ledger_version"
  if [ "$ledger_version" = "0" ] && { [ "$ledger_num" = "0" ] || [ "$ledger_num" = "1" ]; }; then
    protocol_display="$ledger_version  (ledger not established — catching up)"
  fi

  field "$w" "State"        "$(jq_val "$json" '.info.state')"
  field "$w" "Block"        "$ledger_num"
  field "$w" "Quorum Block" "$(jq_val "$json" '.info.quorum.qset.ledger // .info.ledger.num')"
  field "$w" "Protocol"     "$protocol_display"
  field "$w" "Network"      "$(jq_val "$json" '.info.network')"
  field "$w" "Version"      "$(jq_val "$json" '.info.build')"
}

show_horizon() {
  header "Horizon"

  local json
  json=$(fetch_json "${HORIZON_URL}/")

  if [ -z "$json" ]; then
    echo "  Status: Not Running"
    return
  fi

  local core_block ingest_block
  core_block=$(jq_val "$json" '.core_latest_ledger')
  ingest_block=$(jq_val "$json" '.ingest_latest_ledger')

  local state
  state=$(sync_state "$core_block" "$ingest_block")

  local w=18
  field "$w" "State"             "$state"
  field "$w" "Core Latest Block" "$core_block"
  field "$w" "History Block"     "$(jq_val "$json" '.history_latest_ledger')"
  field "$w" "Ingest Block"      "$ingest_block"
  field "$w" "Protocol Version"  "$(jq_val "$json" '.current_protocol_version')"
  field "$w" "Horizon Version"   "$(jq_val "$json" '.horizon_version')"

  # Show ingest progress when syncing
  if [ "$state" = "Syncing" ]; then
    local log_pattern="${HORIZON_LOG_DIR}/horizon-stdout---supervisor-*.log"
    local log_file
    log_file=$(ls -t $log_pattern 2>/dev/null | head -n 1 || true)

    if [ -n "$log_file" ]; then
      local last_line
      last_line=$(grep 'service=ingest' "$log_file" 2>/dev/null | tail -n 1 || true)

      if [ -n "$last_line" ]; then
        local progress="" processed=""
        if [[ "$last_line" =~ progress=\"([0-9.]+%)\" ]]; then
          progress="${BASH_REMATCH[1]}"
        fi
        if [[ "$last_line" =~ processed_entries=([0-9]+) ]]; then
          processed="${BASH_REMATCH[1]}"
        fi
        if [ -n "$progress" ]; then
          field "$w" "Ingest Progress" "$progress"
          if [ -n "$processed" ]; then
            local formatted
            formatted=$(printf "%'d" "$processed" 2>/dev/null || echo "$processed")
            field "$w" "Ingest Processed" "${formatted} entries"
          fi
        fi
      fi
    fi
  fi
}

show_peers() {
  header "Peers"

  local json
  json=$(fetch_json "${CORE_URL}/peers")

  if [ -z "$json" ]; then
    echo "  Status: Not responding"
    return
  fi

  local w=20
  field "$w" "Authenticated In"  "$(jq_val "$json" '.authenticated_peers.inbound  | length')"
  field "$w" "Authenticated Out" "$(jq_val "$json" '.authenticated_peers.outbound | length')"
  field "$w" "Pending In"        "$(jq_val "$json" '.pending_peers.inbound  | length')"
  field "$w" "Pending Out"       "$(jq_val "$json" '.pending_peers.outbound | length')"
}

show_system() {
  header "System"

  local w=12

  # Disk: use df on root filesystem
  local disk_line
  disk_line=$(df -h / 2>/dev/null | tail -n 1)
  if [ -n "$disk_line" ]; then
    local disk_used disk_total disk_pct
    disk_used=$(echo "$disk_line" | awk '{print $3}')
    disk_total=$(echo "$disk_line" | awk '{print $2}')
    disk_pct=$(echo "$disk_line" | awk '{print $5}')
    field "$w" "Disk Used" "${disk_used} / ${disk_total} (${disk_pct})"
  fi

  # RAM: parse /proc/meminfo
  if [ -r /proc/meminfo ]; then
    local mem_total_kb mem_avail_kb mem_used_kb
    mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

    if [ -n "$mem_total_kb" ] && [ -n "$mem_avail_kb" ]; then
      mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
      local mem_used_h mem_total_h mem_pct

      # Format KB to human-readable (G or M)
      if [ "$mem_total_kb" -ge 1048576 ]; then
        mem_used_h=$(awk "BEGIN {printf \"%.1fG\", $mem_used_kb / 1048576}")
        mem_total_h=$(awk "BEGIN {printf \"%.1fG\", $mem_total_kb / 1048576}")
      else
        mem_used_h=$(awk "BEGIN {printf \"%.0fM\", $mem_used_kb / 1024}")
        mem_total_h=$(awk "BEGIN {printf \"%.0fM\", $mem_total_kb / 1024}")
      fi

      mem_pct=$(awk "BEGIN {printf \"%.0f%%\", ($mem_used_kb / $mem_total_kb) * 100}")
      field "$w" "RAM Used" "${mem_used_h} / ${mem_total_h} (${mem_pct})"
    fi
  fi

  # CPU usage (sample /proc/stat over 0.2s)
  if [ -r /proc/stat ]; then
    local s1 s2 cpu_pct
    s1=$(awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8}' /proc/stat)
    sleep 0.2
    s2=$(awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8}' /proc/stat)
    local ncores
    ncores=$(nproc 2>/dev/null || echo 1)
    cpu_pct=$(awk -v a="$s1" -v b="$s2" -v nc="$ncores" 'BEGIN {
      split(a,x); split(b,y);
      total=0; for(i=1;i<=7;i++) { d[i]=y[i]-x[i]; total+=d[i] }
      if (total == 0) { printf "0.0%%"; exit }
      printf "%.1f%%", ((total-d[4])/total)*100*nc
    }')
    field "$w" "CPU" "${cpu_pct} / ${ncores} cores"
  fi
}

# ── Usage ──

usage() {
  cat <<'EOF'
Usage: node-status [OPTIONS]

Show Pi Network node status from inside the container.

Options:
  --services    Show supervisord service states
  --protocol    Show protocol state, block, network
  --horizon     Show Horizon sync state, blocks, ingest progress
  --peers       Show peer connections
  --system      Show disk, RAM, CPU
  -h, --help    Show this help message

No flags = show all sections.
EOF
}

# ── Flag Parsing ──

SHOW_SERVICES=false
SHOW_PROTOCOL=false
SHOW_HORIZON=false
SHOW_PEERS=false
SHOW_SYSTEM=false
ANY_FLAG=false

while [ $# -gt 0 ]; do
  case "$1" in
    --services) SHOW_SERVICES=true; ANY_FLAG=true ;;
    --protocol) SHOW_PROTOCOL=true; ANY_FLAG=true ;;
    --horizon)  SHOW_HORIZON=true;  ANY_FLAG=true ;;
    --peers)    SHOW_PEERS=true;    ANY_FLAG=true ;;
    --system)   SHOW_SYSTEM=true;   ANY_FLAG=true ;;
    -h|--help)  usage; exit 0 ;;
    *)
      echo "Error: unknown option '$1'" >&2
      echo "" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

# No flags = show all
if [ "$ANY_FLAG" = false ]; then
  SHOW_SERVICES=true
  SHOW_PROTOCOL=true
  SHOW_HORIZON=true
  SHOW_PEERS=true
  SHOW_SYSTEM=true
fi

# ── Preflight ──

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found" >&2
  exit 1
fi

# ── Main ──

[ "$SHOW_SERVICES" = true ] && show_services || true
[ "$SHOW_PROTOCOL" = true ] && show_protocol || true
[ "$SHOW_HORIZON"  = true ] && show_horizon  || true
[ "$SHOW_PEERS"    = true ] && show_peers    || true
[ "$SHOW_SYSTEM"   = true ] && show_system   || true

echo ""
