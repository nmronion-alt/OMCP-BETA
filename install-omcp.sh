#!/usr/bin/env bash
set -Eeuo pipefail
# OMCP installer for Ubuntu/Debian. Supports systemd VPS and no-systemd shells.
REPO="https://raw.githubusercontent.com/nmronion-alt/OMCP-BETA/main"
APP="/opt/omcp"
DATA="/var/lib/omcp"

# Railway and similar container hosts provide PORT and route HTTP traffic to it.
# In that mode, bind on all interfaces and do not depend on an outbound SSH tunnel.
PLATFORM_PORT="${PORT:-}"
if [[ -n "$PLATFORM_PORT" ]]; then
  if ! [[ "$PLATFORM_PORT" =~ ^[0-9]+$ ]] || (( PLATFORM_PORT < 1 || PLATFORM_PORT > 65535 )); then
    echo "Invalid platform PORT value: $PLATFORM_PORT"; exit 1
  fi
  PANEL_HOST="0.0.0.0"
  PANEL_PORT="$PLATFORM_PORT"
  PLATFORM_MODE=1
else
  PANEL_HOST="${OMCP_HOST:-127.0.0.1}"
  PANEL_PORT="${OMCP_PORT:-8765}"
  PLATFORM_MODE=0
fi
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo/root: sudo bash install-omcp.sh"; exit 1; fi
if ! command -v apt-get >/dev/null; then echo "Supported target: Ubuntu/Debian."; exit 1; fi
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-paramiko git curl ca-certificates openjdk-21-jre-headless openssh-client
DEBIAN_FRONTEND=noninteractive apt-get install -y cpulimit >/dev/null 2>&1 || true

# Create the application paths and service account before writing helper scripts.
id omcp >/dev/null 2>&1 || useradd --system --home-dir "$DATA" --create-home --shell /usr/sbin/nologin omcp
install -d -o root -g omcp -m 0750 "$APP"
install -d -o omcp -g omcp -m 0750 "$DATA" "$DATA/servers" "$DATA/backups"

# Cloudflare Quick Tunnel provides a browser-ready HTTPS URL without a token.
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) CF_ARCH="amd64" ;;
  arm64) CF_ARCH="arm64" ;;
  *) echo "Unsupported CPU architecture for cloudflared: $ARCH"; exit 1 ;;
esac
curl -fL --retry 3 --retry-all-errors "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH" -o /usr/local/bin/cloudflared.new
chmod 0755 /usr/local/bin/cloudflared.new
/usr/local/bin/cloudflared.new --version >/dev/null
mv /usr/local/bin/cloudflared.new /usr/local/bin/cloudflared
cat >"$APP/omcp-tunnel.sh" <<'TUNNEL'
#!/usr/bin/env bash
set -u
PORT="${1:-8765}"
LOG="${2:-/var/lib/omcp/tunnel.log}"
while true; do
  echo "[$(date -Is)] Trying Cloudflare Quick Tunnel" >>"$LOG"
  /usr/local/bin/cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" >>"$LOG" 2>&1 || true
  echo "[$(date -Is)] Trying localhost.run fallback" >>"$LOG"
  timeout 90 ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -R "80:127.0.0.1:$PORT" nokey@localhost.run >>"$LOG" 2>&1 || true
  echo "[$(date -Is)] Trying Pinggy fallback" >>"$LOG"
  timeout 90 ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -p 443 -R "0:127.0.0.1:$PORT" a.pinggy.io >>"$LOG" 2>&1 || true
  echo "[$(date -Is)] Tunnel providers cycled; retrying in 8 seconds" >>"$LOG"
  sleep 8
done
TUNNEL
chmod 0755 "$APP/omcp-tunnel.sh"
chown root:omcp "$APP/omcp-tunnel.sh"
# Keep Java 21 as the predictable baseline for current Minecraft server software.
# Open the dedicated SFTP listener in UFW when UFW is already active. Cloud firewalls need a separate rule.
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then ufw allow 2022/tcp || true; fi

# Service account and directories were created before tunnel helper installation.
cat >"$DATA/omcp.env" <<ENV
OMCP_HOST=$PANEL_HOST
OMCP_PORT=$PANEL_PORT
OMCP_DATA=/var/lib/omcp
OMCP_WEB=/opt/omcp/index.html
ENV
chown omcp:omcp "$DATA/omcp.env"
chmod 0640 "$DATA/omcp.env"
curl -fsSL "$REPO/agent/omcp_agent.py" -o "$APP/omcp_agent.py.new"
curl -fsSL "$REPO/index.html" -o "$APP/index.html.new"
# Publish only fully downloaded files.
mv "$APP/omcp_agent.py.new" "$APP/omcp_agent.py"
mv "$APP/index.html.new" "$APP/index.html"
# Validate the complete agent source before stopping/restarting the existing process.
python3 -m py_compile "$APP/omcp_agent.py"
chown root:omcp "$APP/omcp_agent.py" "$APP/index.html"
chmod 0640 "$APP/omcp_agent.py" "$APP/index.html"

SYSTEMD_STATE=""
SYSTEMD_OK=0
if command -v systemctl >/dev/null 2>&1; then
  SYSTEMD_STATE="$(systemctl is-system-running 2>/dev/null || true)"
  # Do not trust the mere presence of systemctl or /run/systemd files.
  # PID 1 must actually be systemd and the manager bus must answer.
  PID1_EXE="$(readlink -f /proc/1/exe 2>/dev/null || true)"
  if [[ "$PID1_EXE" == *systemd* ]] && systemctl is-active --quiet default.target 2>/dev/null; then
    SYSTEMD_OK=1
  fi
fi
if [[ "$SYSTEMD_OK" == "1" ]]; then
  cat >/etc/systemd/system/omcp.service <<'UNIT'
[Unit]
Description=OMCP Onion Minecraft Panel
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=omcp
Group=omcp
WorkingDirectory=/opt/omcp
EnvironmentFile=/var/lib/omcp/omcp.env
ExecStart=/usr/bin/python3 /opt/omcp/omcp_agent.py
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/omcp
UMask=0027
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable omcp
  if systemctl is-active --quiet omcp; then systemctl restart omcp; else systemctl start omcp; fi
  systemctl daemon-reload
  if [[ "$PLATFORM_MODE" == "1" ]]; then
    systemctl disable --now omcp-tunnel.service 2>/dev/null || true
    echo "Platform PORT detected; using the platform's HTTP ingress instead of tunnl.gg."
  else
    cat >/etc/systemd/system/omcp-tunnel.service <<UNIT
[Unit]
Description=OMCP HTTPS Quick Tunnel
After=network-online.target omcp.service
Wants=network-online.target
[Service]
Type=simple
User=omcp
Group=omcp
ExecStart=/opt/omcp/omcp-tunnel.sh $PANEL_PORT /var/lib/omcp/tunnel.log
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/omcp
UMask=0027
[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload
    systemctl enable --now omcp-tunnel.service
  fi
  sleep 2
  echo "OMCP service status:"
  systemctl --no-pager --full status omcp || true
  echo "First-run Admin setup: sudo journalctl -u omcp -n 80 --no-pager"
  if [[ "$PLATFORM_MODE" == "1" ]]; then
    echo "Platform ingress: open the service's assigned HTTPS domain (PORT=$PANEL_PORT)."
  else
    for _ in {1..45}; do
      PANEL_URL="$(grep -Eo 'https://[A-Za-z0-9.-]+' "$DATA/tunnel.log" 2>/dev/null | grep -E 'trycloudflare\.com|localhost\.run|lhr\.life|pinggy\.link' | tail -n 1 || true)"
      [[ -n "$PANEL_URL" ]] && break
      sleep 2
    done
    if [[ -n "$PANEL_URL" ]]; then echo "OMCP PANEL URL: $PANEL_URL"; else echo "Tunnel is still connecting. Check: sudo journalctl -u omcp-tunnel -n 80 --no-pager"; fi
  fi
else
  echo "systemd is not usable (state: ${SYSTEMD_STATE:-unavailable}); using background-process mode."
  if [[ -f "$DATA/agent.pid" ]] && kill -0 "$(cat "$DATA/agent.pid")" 2>/dev/null; then
    old_pid="$(cat "$DATA/agent.pid")"
    echo "Restarting existing OMCP process (PID $old_pid) to load updated files."
    kill "$old_pid" 2>/dev/null || true
    for _ in {1..20}; do kill -0 "$old_pid" 2>/dev/null || break; sleep 0.25; done
  fi
  rm -f "$DATA/agent.pid"
  runuser -u omcp -- sh -c 'nohup env OMCP_HOST="$1" OMCP_PORT="$2" OMCP_DATA=/var/lib/omcp OMCP_WEB=/opt/omcp/index.html /usr/bin/python3 /opt/omcp/omcp_agent.py </dev/null >>/var/lib/omcp/agent.log 2>&1 & echo $! >/var/lib/omcp/agent.pid' sh "$PANEL_HOST" "$PANEL_PORT"
  sleep 2
  if [[ -f "$DATA/agent.pid" ]] && kill -0 "$(cat "$DATA/agent.pid")" 2>/dev/null; then
    echo "OMCP background process started (PID $(cat "$DATA/agent.pid"))."
  else
    echo "OMCP did not start. Recent log:"
    tail -n 60 "$DATA/agent.log" 2>/dev/null || true
    exit 1
  fi
  echo "First-run Admin setup / startup log: sudo cat $DATA/agent.log"
  if [[ "$PLATFORM_MODE" == "1" ]]; then
    if [[ -f "$DATA/tunnel.pid" ]] && kill -0 "$(cat "$DATA/tunnel.pid")" 2>/dev/null; then kill "$(cat "$DATA/tunnel.pid")" 2>/dev/null || true; fi
    echo "Platform PORT detected; skipping Quick Tunnel. Use the platform-generated HTTPS domain."
  else
    if [[ -f "$DATA/tunnel.pid" ]] && kill -0 "$(cat "$DATA/tunnel.pid")" 2>/dev/null; then
      kill "$(cat "$DATA/tunnel.pid")" 2>/dev/null || true
    fi
    runuser -u omcp -- sh -c 'nohup /opt/omcp/omcp-tunnel.sh "$1" /var/lib/omcp/tunnel.log </dev/null >>/var/lib/omcp/tunnel.log 2>&1 & echo $! >/var/lib/omcp/tunnel.pid' sh "$PANEL_PORT"
    PANEL_URL=""
    for _ in {1..90}; do
      PANEL_URL="$(grep -Eo 'https://[A-Za-z0-9.-]+' "$DATA/tunnel.log" 2>/dev/null | grep -E 'trycloudflare\.com|localhost\.run|lhr\.life|pinggy\.link' | tail -n 1 || true)"
      [[ -n "$PANEL_URL" ]] && break
      sleep 2
    done
    if [[ -n "$PANEL_URL" ]]; then echo "OMCP PANEL URL: $PANEL_URL"; else echo "Tunnel is still connecting. Check: sudo tail -n 60 $DATA/tunnel.log"; fi
    echo "Stop this no-systemd tunnel: sudo kill \$(cat $DATA/tunnel.pid)"
  fi
  echo "Stop this no-systemd panel: sudo kill \$(cat $DATA/agent.pid)"
fi
echo
echo "OMCP panel listener: http://$PANEL_HOST:$PANEL_PORT"
if [[ "$PLATFORM_MODE" == "1" ]]; then
  echo "Platform mode is active: open the HTTPS domain assigned to this service on port $PANEL_PORT."
  echo "The host must keep this container/process running and preserve /var/lib/omcp for persistent server data."
else
  echo "Panel is bound to localhost. Tunnel runner tries Cloudflare, localhost.run, then Pinggy."
  echo "Tunnel URLs are temporary and may change after reconnecting."
fi
echo "OpenJDK 21 is installed. Verify with: java -version"
echo "Minecraft server traffic still needs a separate TCP route/relay; the panel's HTTPS domain does not carry Minecraft TCP."
