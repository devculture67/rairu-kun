#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$body" > /dev/null 2>&1 || true
}

bore_tunnel() {
  local lport="$1" label="$2" log_file="/tmp/bore_${lport}.log"
  while true; do
    > "$log_file"
    bore local "$lport" --to "$BORE_SERVER" > "$log_file" 2>&1 &
    local PID=$!
    local PORT=""
    for i in $(seq 1 30); do
      sleep 1
      PORT=$(grep -oE "${BORE_SERVER}:[0-9]+" "$log_file" 2>/dev/null | head -1 | cut -d: -f2)
      [ -n "$PORT" ] && break
      PORT=$(grep -iE "remote_port=[0-9]+" "$log_file" 2>/dev/null | grep -oE "[0-9]+" | tail -1)
      [ -n "$PORT" ] && break
    done
    if [ -n "$PORT" ]; then
      log "[$label] READY → bore.pub:$PORT"
      echo "$PORT" > "/tmp/port_${lport}.txt"
      update_summary
    else
      log "[$label] GAGAL: $(head -3 $log_file 2>/dev/null)"
      notify "⚠️ Tunnel Gagal [$label]" "Port $lport gagal connect ke bore.pub\nRetry 5 detik..." "low" "warning"
    fi
    wait $PID 2>/dev/null || true
    log "[$label] Disconnect → Reconnect 5s..."
    rm -f "/tmp/port_${lport}.txt"
    notify "🔄 Reconnecting [$label]" "Tunnel port $lport terputus. Menghubungkan ulang ke bore.pub..." "low" "arrows_counterclockwise"
    sleep 5
  done
}

update_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  local P80=$(cat /tmp/port_80.txt 2>/dev/null)
  local P443=$(cat /tmp/port_443.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local UPTIME=$(uptime -p 2>/dev/null || echo 'running')
  local BODY="🖥️ Ubuntu 20.04 VPS AKTIF

🔑 SSH   : ssh root@bore.pub -p ${P22}
🔒 Pass  : ${ROOT_PASS}
🌐 HTTP  : bore.pub:${P80:-pending}
🔐 HTTPS : bore.pub:${P443:-pending}

⏰ Up: $UPTIME
📡 ntfy : ntfy.sh/${NTFY_TOPIC}"
  notify "✅ VPS ONLINE - Port Ready!" "$BODY" "high" "computer,key,white_check_mark"
}

monitor_loop() {
  while true; do
    sleep 300
    local P22=$(cat /tmp/port_22.txt 2>/dev/null)
    [ -z "$P22" ] && continue
    local UPTIME=$(uptime -p 2>/dev/null || echo 'running')
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3, $2}' || echo 'n/a')
    local LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo 'n/a')
    notify "📊 Status VPS (5min)" "⏰ Uptime: $UPTIME\n💾 RAM: $MEM\n⚡ Load: $LOAD\n🔑 SSH: bore.pub:$P22" "min" "bar_chart"
  done
}

log "============================================="
log "  Ubuntu 20.04 VPS — devculture67"
log "  bore tunnel: SSH + HTTP + HTTPS"
log "  ntfy topic : $NTFY_TOPIC"
log "============================================="

# Pastikan password root dari env
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Kirim notif startup
notify "🚀 VPS Booting..." "Ubuntu 20.04 sedang startup...\nTunnel SSH+HTTP+HTTPS akan aktif sebentar.\n📡 ntfy.sh/${NTFY_TOPIC}" "default" "rocket"

# Start SSH
/usr/sbin/sshd && log "✅ SSH daemon started"

# HTTP/HTTPS placeholder agar bore bisa forward
python3 - << 'PY' &
import http.server, socketserver, threading, time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'VPS devculture67 - Ready! Connect via SSH.')
for p in [80, 443]:
    threading.Thread(target=lambda p=p: socketserver.TCPServer(('',p),H).serve_forever(), daemon=True).start()
time.sleep(86400)
PY

sleep 2

# 3 bore tunnel paralel
bore_tunnel 22  "SSH-22"    &
bore_tunnel 80  "HTTP-80"   &
bore_tunnel 443 "HTTPS-443" &

# Monitor setiap 5 menit
monitor_loop &

log "Health check port 8080"
exec python3 -c "
import http.server, socketserver
h=http.server.SimpleHTTPRequestHandler
h.log_message=lambda *a:None
socketserver.TCPServer(('',8080),h).serve_forever()
"
