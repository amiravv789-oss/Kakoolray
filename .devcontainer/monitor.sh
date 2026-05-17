#!/bin/sh
# .devcontainer/monitor.sh
set -eu

USERS_FILE="$1"
RELOAD_FLAG="$2"
XRAY_API="http://127.0.0.1:10085"

# return current downlink+uplink in bytes for a uuid
get_usage_bytes() {
    uuid="$1"
    down=$(curl -s "$XRAY_API/stats/get?name=user>>>${uuid}>>>traffic>>>downlink" | jq -r '.stat.value // 0')
    up=$(curl -s "$XRAY_API/stats/get?name=user>>>${uuid}>>>traffic>>>uplink" | jq -r '.stat.value // 0')
    echo $(( down + up ))
}

# convert GB to bytes (1 GB = 1073741824)
gb_to_bytes() {
    echo $(( $1 * 1073741824 ))
}

while true; do
    changed=0
    users_len=$(jq '.users | length' "$USERS_FILE")
    i=0
    while [ "$i" -lt "$users_len" ]; do
        uuid=$(jq -r ".users[$i].uuid" "$USERS_FILE")
        limit_gb=$(jq -r ".users[$i].limit_gb" "$USERS_FILE")
        if [ "$limit_gb" != "-1" ]; then
            usage=$(get_usage_bytes "$uuid")
            limit_bytes=$(gb_to_bytes "$limit_gb")
            if [ "$usage" -ge "$limit_bytes" ]; then
                echo "[monitor] Removing user $uuid (limit exceeded)"
                jq "del(.users[$i])" "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
                changed=1
                i=$(( i - 1 ))  # index shifted
            fi
        fi
        i=$(( i + 1 ))
    done
    if [ "$changed" -eq 1 ]; then
        touch "$RELOAD_FLAG"
    fi
    sleep 60
done
