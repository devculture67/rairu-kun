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

🔑 SSH      : ssh root@bore.pub -p ${P22}
🔒 Password : ${ROOT_PASS}
🌐 Nginx/UI : http://bore.pub:${P80:-pending}
🤖 Ollama   : http://bore.pub:${P80:-pending}/api/
🔐 HTTPS    : bore.pub:${P443:-pending}
🚀 Port 3000: bore.pub:${P3000:-pending}
🔧 Port 8080: bore.pub:${P8080:-pending}
📡 Port 8888: bore.pub:${P8888:-pending}

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
    local OLLAMA_STATUS="❌ Mati"
    pgrep ollama > /dev/null && OLLAMA_STATUS="✅ Aktif"
    notify "📊 Status VPS #${check} (5-menit)" \
      "⏰ Uptime  : $UPTIME\n💾 RAM     : $MEM\n⚡ Load    : $LOAD\n💽 Disk    : $DISK dipakai\n🔢 Proses  : $PROC\n🤖 Ollama  : $OLLAMA_STATUS\n🔑 SSH     : bore.pub:$P22" \
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
        "SSH daemon tidak berjalan!\nMencoba restart...\nVPS: Devculture" \
        "urgent" "rotating_light,sos"
      /usr/sbin/sshd && log "✅ SSH restarted by watchdog"
      notify "🔄 SSH Direstart" "SSH daemon berhasil direstart." "high" "white_check_mark"
    fi
  done
}

# =============================================
# Nginx watchdog
# =============================================
nginx_watchdog() {
  while true; do
    sleep 60
    if ! pgrep nginx > /dev/null; then
      notify "🚨 Nginx MATI!" \
        "Nginx tidak berjalan! Mencoba restart...\nVPS: Devculture" \
        "urgent" "rotating_light"
      nginx && log "✅ Nginx restarted by watchdog"
      notify "🔄 Nginx Direstart" "Nginx berhasil direstart." "high" "white_check_mark"
    fi
  done
}

# =============================================
# Ollama watchdog + model info
# =============================================
ollama_watchdog() {
  local first_run=true
  while true; do
    sleep 30
    if ! pgrep ollama > /dev/null; then
      notify "🚨 Ollama MATI!" \
        "Ollama service tidak berjalan!\nMencoba restart...\nVPS: Devculture" \
        "urgent" "robot_face,rotating_light"
      ollama serve > /tmp/ollama.log 2>&1 &
      sleep 10
      if pgrep ollama > /dev/null; then
        notify "🔄 Ollama Direstart" "Ollama service berhasil direstart." "high" "robot_face,white_check_mark"
        $first_run = false
      fi
    elif [ "$first_run" = true ]; then
      # Kirim info model yang tersedia saat Ollama pertama kali aktif
      local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -10 || echo 'none')
      notify "🤖 Ollama Siap!" \
        "Ollama service aktif!\n\nModel tersedia:\n${MODELS:-'(belum ada — pull model dulu)'}\n\nAPI: /api/ via bore.pub:80\nUI  : / via bore.pub:80" \
        "default" "robot_face,white_check_mark"
      first_run=false
    fi
  done
}

# =============================================
# MAIN
# =============================================
log "============================================="
log "  Ubuntu 20.04 VPS — Devculture"
log "  Ports : 22 80 443 3000 8080 8888 11434"
log "  ntfy  : $NTFY_TOPIC"
log "  Start : $START_TIME"
log "============================================="

# Set password dari env
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Notifikasi startup
notify "🚀 VPS Booting..." \
  "Ubuntu 20.04 sedang startup...\n\nPorts: SSH(22) Nginx/Ollama(80) HTTPS(443) 3000 8080 8888\nTunnel via bore.pub akan aktif sebentar.\n\n📲 ntfy.sh/$NTFY_TOPIC\n🕐 $START_TIME" \
  "default" "rocket,hourglass"

# 1. Start SSH
/usr/sbin/sshd && log "✅ SSH daemon started"
notify "🔑 SSH Aktif" "SSH daemon berhasil start." "low" "key"

# 2. Start Ollama service
log "🤖 Starting Ollama..."
ollama serve > /tmp/ollama.log 2>&1 &
sleep 5
if pgrep ollama > /dev/null; then
  log "✅ Ollama started"
  notify "🤖 Ollama Starting..." \
    "Ollama service sedang startup.\nAPI akan tersedia di: /api/\nUI di: /\n\nUntuk pull model:\n  ollama pull llama3.2\n  ollama pull mistral" \
    "low" "robot_face"
else
  log "⚠️ Ollama gagal start, cek /tmp/ollama.log"
  notify "⚠️ Ollama Gagal Start" \
    "Ollama tidak bisa start.\nCek log: /tmp/ollama.log\n$(head -5 /tmp/ollama.log 2>/dev/null)" \
    "high" "warning,robot_face"
fi

# 3. Configure & start nginx
nginx -t 2>&1 && log "✅ Nginx config valid"
nginx && log "✅ Nginx started"
notify "🌐 Nginx Aktif" "Nginx berhasil start.\nProxy Ollama API aktif di /api/\nOllama UI aktif di /" "low" "globe_with_meridians"

# 4. HTTPS/443 placeholder (nginx handles 80)
python3 - << 'PY' &
import http.server, socketserver, threading, time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(301)
        self.send_header('Location', 'http://bore.pub/')
        self.end_headers()
for p in [443, 3000, 8888]:
    threading.Thread(target=lambda p=p: socketserver.TCPServer(('',p),H).serve_forever(), daemon=True).start()
time.sleep(86400 * 365)
PY

sleep 2

# 5. Bore tunnels (semua port paralel)
bore_tunnel 22   "SSH-22"      &
bore_tunnel 80   "HTTP-80"     &
bore_tunnel 443  "HTTPS-443"   &
bore_tunnel 3000 "APP-3000"    &
bore_tunnel 8080 "APP-8080"    &
bore_tunnel 8888 "APP-8888"    &

# 6. Watchdogs & monitor
ssh_watchdog    &
nginx_watchdog  &
ollama_watchdog &
monitor_loop    &

# 7. Health check (port 8080 untuk Railway)
log "✅ Health check server on :8080"
exec python3 -c "
import http.server, socketserver, subprocess
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'OK')
socketserver.TCPServer(('', 8080), H).serve_forever()
"
