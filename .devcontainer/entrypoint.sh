#!/bin/sh
# .devcontainer/entrypoint.sh
set -eu

CONFIG_TEMPLATE="/etc/config.template.json"
CONFIG="/etc/config.json"
USERS_FILE="/etc/users.json"
LINKS_FILE="/tmp/vless-links.txt"
RELOAD_FLAG="/tmp/reload.flag"
PANEL_PORT=8080

ADMIN_UUID="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"   # @Enity

# ---------- first-run: create users.json ----------
if [ ! -f "$USERS_FILE" ]; then
    cat > "$USERS_FILE" <<EOF
{
  "users": [
    {
      "uuid": "$ADMIN_UUID",
      "limit_gb": -1,
      "comment": "Admin (@Enity)"
    }
  ]
}
EOF
fi

# ---------- helper: regenerate xray config from users.json ----------
generate_config() {
    jq -c '.users' "$USERS_FILE" | jq '[.[] | {id: .uuid}]' > /tmp/clients.json
    jq --slurpfile clients /tmp/clients.json \
       '.inbounds[0].settings.clients = $clients[0]' \
       "$CONFIG_TEMPLATE" > "$CONFIG"
}

# ---------- start xray ----------
start_xray() {
    generate_config
    /usr/local/bin/xray -c "$CONFIG" &
    XRAY_PID=$!
}

# ---------- print links ----------
print_links() {
    UUID_LIST=$(jq -r '.users[].uuid' "$USERS_FILE")
    SNI="${CODESPACE_NAME:-localhost}-443.app.github.dev"
    > "$LINKS_FILE"
    for uuid in $UUID_LIST; do
        for ip in 94.130.50.12 63.141.252.203 50.7.5.83; do
            LINK="vless://${uuid}@${ip}:443?encryption=none&security=tls&type=ws&sni=${SNI}&path=%2F#@Kakoolnews-${uuid:0:8}"
            echo "$LINK" | tee -a "$LINKS_FILE"
        done
    done
}

# ---------- monitor & reload logic ----------
auto_reload() {
    while true; do
        if [ -f "$RELOAD_FLAG" ]; then
            rm -f "$RELOAD_FLAG"
            echo "[entrypoint] Reload triggered"
            if kill -0 "$XRAY_PID" 2>/dev/null; then
                kill "$XRAY_PID"
                wait "$XRAY_PID" 2>/dev/null || true
            fi
            start_xray
            print_links
        fi
        sleep 5
    done
}

# ---------- main ----------
start_xray
print_links

# start monitor daemon
/usr/local/bin/monitor.sh "$USERS_FILE" "$RELOAD_FLAG" &
# start web panel
python3 /usr/local/bin/panel.py "$USERS_FILE" "$RELOAD_FLAG" "$PANEL_PORT" &

# start auto-reloader
auto_reload &

# keep-alive
while kill -0 "$XRAY_PID" 2>/dev/null; do
    echo "[@Kakoolnews] alive - $(date '+%H:%M:%S')"
    sleep 300
done
