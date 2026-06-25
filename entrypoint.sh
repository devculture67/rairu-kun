#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"
START_TIME=$(date '+%Y-%m-%d %H:%M:%S WIB')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# =============================================
# NTFY notification function
# =============================================
notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 --retry 3 --retry-delay 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Content-Type: text/plain" \
    -d "$body" > /dev/null 2>&1 || true
}

# =============================================
# Bore tunnel per port
# =============================================
bore_tunnel() {
  local lport="$1" label="$2"
  local log_file="/tmp/bore_${lport}.log"
  while true; do
    > "$log_file"
    bore local "$lport" --to "$BORE_SERVER" > "$log_file" 2>&1 &
    local PID=$!
    local PORT=""
    for i in $(seq 1 40); do
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
      notify "⚠️ Tunnel Gagal [$label]" \
        "Port $lport gagal connect ke bore.pub\nError: $(head -1 $log_file 2>/dev/null)\nRetry dalam 5 detik..." \
        "high" "warning,x"
    fi
    wait $PID 2>/dev/null || true
    log "[$label] Disconnect → Reconnect 5s..."
    rm -f "/tmp/port_${lport}.txt"
    notify "🔄 Tunnel Terputus [$label]" \
      "Koneksi port $lport ke bore.pub terputus.\nMenghubungkan ulang dalam 5 detik...\n📡 ntfy.sh/$NTFY_TOPIC" \
      "default" "arrows_counterclockwise"
    sleep 5
  done
}

# =============================================
# Update summary notif setelah port siap
# =============================================
update_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  local P80=$(cat /tmp/port_80.txt 2>/dev/null)
  local P443=$(cat /tmp/port_443.txt 2>/dev/null)
  local P3000=$(cat /tmp/port_3000.txt 2>/dev/null)
  local P8080=$(cat /tmp/port_8080.txt 2>/dev/null)
  local P8888=$(cat /tmp/port_8888.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local UPTIME=$(uptime -p 2>/dev/null || echo 'baru start')
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB / %dMB", $3, $2}' || echo 'n/a')
  local DISK=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)", $3,$2,$5}' || echo 'n/a')
  local IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'n/a')

  local BODY="✅ Ubuntu 20.04 VPS AKTIF

🔑 SSH    : ssh root@bore.pub -p ${P22}
🔒 Pass   : ${ROOT_PASS}
🌐 HTTP   : http://bore.pub:${P80:-pending}
🔐 HTTPS  : https://bore.pub:${P443:-pending}
🚀 Port 3000  : bore.pub:${P3000:-pending}
🔧 Port 8080  : bore.pub:${P8080:-pending}
📡 Port 8888  : bore.pub:${P8888:-pending}

🌍 IP Publik : $IP
⏰ Uptime    : $UPTIME
💾 RAM       : $MEM
💽 Disk      : $DISK
🕐 Start     : $START_TIME
📲 ntfy      : ntfy.sh/$NTFY_TOPIC"

  notify "🖥️ VPS ONLINE — Semua Port Ready!" "$BODY" "high" "computer,key,white_check_mark,tada"
}

# =============================================
# Monitor setiap 5 menit
# =============================================
monitor_loop() {
  local check=0
  while true; do
    sleep 300
    check=$((check + 1))
    local P22=$(cat /tmp/port_22.txt 2>/dev/null)
    [ -z "$P22" ] && continue
    local UPTIME=$(uptime -p 2>/dev/null || echo 'running')
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB (%.0f%%)", $3,$2,$3/$2*100}' || echo 'n/a')
    local LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo 'n/a')
    local DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $5}' || echo 'n/a')
    local PROC=$(ps aux 2>/dev/null | wc -l || echo 'n/a')
    notify "📊 Status VPS #${check} (5-menit)" \
      "⏰ Uptime : $UPTIME\n💾 RAM    : $MEM\n⚡ Load   : $LOAD\n💽 Disk   : $DISK dipakai\n🔢 Proses : $PROC\n🔑 SSH    : bore.pub:$P22" \
      "min" "bar_chart,clock4"
  done
}

# =============================================
# SSH watchdog — notif jika sshd mati
# =============================================
ssh_watchdog() {
  while true; do
    sleep 60
    if ! pgrep sshd > /dev/null; then
      notify "🚨 SSH MATI!" \
        "SSH daemon tidak berjalan!\nMencoba restart...\nVPS: devculture67/rairu-kun" \
        "urgent" "rotating_light,sos"
      /usr/sbin/sshd && log "✅ SSH restarted by watchdog"
      notify "🔄 SSH Direstart" \
        "SSH daemon berhasil direstart oleh watchdog.\nCoba hubungkan kembali ke bore.pub" \
        "high" "white_check_mark"
    fi
  done
}

# =============================================
# MAIN
# =============================================
log "============================================="
log "  Ubuntu 20.04 VPS — devculture67/rairu-kun"
log "  Ports : 22 80 443 3000 8080 8888"
log "  ntfy  : $NTFY_TOPIC"
log "  Start : $START_TIME"
log "============================================="

# Set password dari env
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Notifikasi startup
notify "🚀 VPS Booting..." \
  "Ubuntu 20.04 sedang startup...\n\nPorts: SSH(22) HTTP(80) HTTPS(443) 3000 8080 8888\nTunnel via bore.pub akan aktif sebentar.\n\n📲 ntfy.sh/$NTFY_TOPIC\n🕐 $START_TIME" \
  "default" "rocket,hourglass"

# Start SSH daemon
/usr/sbin/sshd && log "✅ SSH daemon started"
notify "🔑 SSH Daemon Aktif" \
  "SSH daemon berhasil start.\nMenunggu tunnel bore.pub aktif...\n\nVPS: devculture67/rairu-kun" \
  "low" "key"

# HTTP placeholder servers (80, 443, 3000, 8888)
python3 - << 'PY' &
import http.server, socketserver, threading, time, os

class VPSHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(b'''<!DOCTYPE html><html><head><title>VPS devculture67</title>
<style>body{font-family:monospace;background:#0d1117;color:#58a6ff;padding:40px}
h1{color:#f0f6fc}pre{background:#161b22;padding:20px;border-radius:8px;color:#7ee787}</style>
</head><body>
<h1>Ubuntu 20.04 VPS — devculture67/rairu-kun</h1>
<pre>Status  : ONLINE
SSH     : ssh root@bore.pub -p &lt;cek ntfy&gt;
ntfy    : ntfy.sh/rairu-devculture67
Ports   : 22 80 443 3000 8080 8888</pre>
<p>Pantau notifikasi di <a href="https://ntfy.sh/rairu-devculture67" style="color:#79c0ff">ntfy.sh/rairu-devculture67</a></p>
</body></html>''')

for p in [80, 443, 3000, 8888]:
    threading.Thread(
        target=lambda p=p: socketserver.TCPServer(('', p), VPSHandler).serve_forever(),
        daemon=True
    ).start()
time.sleep(86400 * 365)
PY

sleep 2

# Start bore tunnels (semua port paralel)
bore_tunnel 22   "SSH-22"    &
bore_tunnel 80   "HTTP-80"   &
bore_tunnel 443  "HTTPS-443" &
bore_tunnel 3000 "APP-3000"  &
bore_tunnel 8080 "APP-8080"  &
bore_tunnel 8888 "APP-8888"  &

# Start watchdog & monitor
ssh_watchdog &
monitor_loop &

# Health check server (port 8080 — Railway needs this)
log "✅ Health check server on :8080"
exec python3 -c "
import http.server, socketserver
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'OK')
socketserver.TCPServer(('', 8080), H).serve_forever()
"
