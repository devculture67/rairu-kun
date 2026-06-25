#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
START_TIME=$(date '+%Y-%m-%d %H:%M:%S WIB')

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# =============================================
# NTFY notification
# =============================================
notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 --retry 3 --retry-delay 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" -H "Priority: $priority" \
    -H "Tags: $tags" -H "Content-Type: text/plain" \
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
    local PID=$! PORT=""
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
      notify "⚠️ Tunnel Gagal [$label]" \
        "Port $lport gagal ke bore.pub\nError: $(head -1 $log_file 2>/dev/null)\nRetry 5s..." \
        "high" "warning,x"
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    notify "🔄 Tunnel Terputus [$label]" \
      "Koneksi port $lport terputus.\nReconnecting 5 detik..." "default" "arrows_counterclockwise"
    sleep 5
  done
}

# =============================================
# Update summary notifikasi
# =============================================
update_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local P80=$(cat /tmp/port_80.txt 2>/dev/null)
  local P443=$(cat /tmp/port_443.txt 2>/dev/null)
  local P3000=$(cat /tmp/port_3000.txt 2>/dev/null)
  local UPTIME=$(uptime -p 2>/dev/null || echo 'baru start')
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3, $2}' || echo 'n/a')
  local DISK=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s/%s(%s)", $3,$2,$5}' || echo 'n/a')
  local IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'n/a')
  local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print "  • "$1}' | head -5 || echo '  (belum ada)')

  notify "🖥️ Devculture VPS ONLINE!" \
"✅ Ubuntu 20.04 VPS AKTIF

🔑 SSH      : ssh root@bore.pub -p ${P22}
🔒 Password : ${ROOT_PASS}
🌐 Ollama UI: http://bore.pub:${P80:-pending}
🤖 API      : http://bore.pub:${P80:-pending}/api/
🔐 HTTPS    : bore.pub:${P443:-pending}
🚀 Port 3000: bore.pub:${P3000:-pending}

🤖 Model Ollama:
${MODELS}

🌍 IP Publik : $IP
⏰ Uptime    : $UPTIME
💾 RAM       : $MEM
💽 Disk      : $DISK
🕐 Start     : $START_TIME
📲 ntfy      : ntfy.sh/$NTFY_TOPIC" \
    "high" "computer,key,white_check_mark,tada"
}

# =============================================
# Auto-pull + auto-update model Ollama
# =============================================
ollama_auto_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "⏳ Menunggu Ollama siap sebelum pull/update model..."

  local ready=false
  for i in $(seq 1 30); do
    sleep 2
    if curl -s --max-time 3 http://localhost:11434/api/tags > /dev/null 2>&1; then
      ready=true; break
    fi
  done

  if [ "$ready" = false ]; then
    notify "⚠️ Auto-Pull Ditunda" \
      "Ollama belum ready setelah 60s.\nPull manual:\n  ollama pull $model" "low" "warning,robot_face"
    return
  fi

  # Cek apakah ini update (model sudah ada) atau pull baru
  if ollama list 2>/dev/null | grep -q "^$model"; then
    log "🔄 Model $model sudah ada, update ke versi terbaru..."
    notify "🔄 Update Model..." \
      "Memperbarui '$model' ke versi terbaru...\nIni mungkin butuh beberapa menit." \
      "low" "arrows_counterclockwise,robot_face"
    IS_UPDATE=true
  else
    log "⬇️ Pull model baru: $model"
    notify "⬇️ Mengunduh Model AI..." \
      "Auto-pull: $model

Model gratis tersedia:
• smollm2   = 270 MB (default)
• tinyllama = 637 MB
• gemma:2b  = 1.4 GB
• phi3      = 2.3 GB (recommended)

Proses berjalan di background.
Notif akan masuk saat selesai 🎉" \
      "default" "robot_face,hourglass"
    IS_UPDATE=false
  fi

  if ollama pull "$model" >> /tmp/ollama-pull.log 2>&1; then
    local SIZE=$(ollama list 2>/dev/null | grep "^$model" | awk '{print $3, $4}')
    if [ "$IS_UPDATE" = true ]; then
      notify "✅ Model Berhasil Di-Update!" \
        "Model '$model' sudah versi terbaru! 🎉

📦 Ukuran : ${SIZE:-'lihat ollama list'}
🌐 Chat   : buka bore.pub di browser
💬 SSH    : ollama run $model

Update berikutnya: Senin depan (otomatis)" \
        "default" "robot_face,white_check_mark,arrows_counterclockwise"
    else
      notify "✅ Model AI Siap Dipakai!" \
        "Model '$model' berhasil diunduh! 🎉

📦 Ukuran : ${SIZE:-'lihat ollama list'}
🌐 Chat   : buka bore.pub di browser
💬 SSH    : ollama run $model

Pull model lain (SSH):
  ollama pull tinyllama  (637MB)
  ollama pull phi3       (2.3GB)
  ollama pull mistral    (4.1GB)" \
        "high" "robot_face,white_check_mark,tada"
    fi
    update_summary
  else
    notify "❌ Pull/Update Model Gagal" \
      "Gagal download '$model'\nLog: $(tail -3 /tmp/ollama-pull.log 2>/dev/null)\n\nCoba manual:\n  ollama pull $model" \
      "high" "warning,robot_face"
  fi
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
    local OLLAMA_STATUS="❌ Mati"
    pgrep ollama > /dev/null && OLLAMA_STATUS="✅ Aktif"
    local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
    notify "📊 Status Devculture VPS #${check}" \
      "⏰ Uptime  : $UPTIME\n💾 RAM     : $MEM\n⚡ Load    : $LOAD\n💽 Disk    : $DISK\n🤖 Ollama  : $OLLAMA_STATUS\n📦 Model   : ${MODELS:-(none)}\n🔑 SSH     : bore.pub:$P22" \
      "min" "bar_chart,clock4"
  done
}

# =============================================
# Watchdogs
# =============================================
ssh_watchdog() {
  while true; do
    sleep 60
    if ! pgrep sshd > /dev/null; then
      notify "🚨 SSH MATI!" "SSH crash! Restart..." "urgent" "rotating_light,sos"
      /usr/sbin/sshd && notify "🔄 SSH Direstart" "SSH OK." "high" "white_check_mark"
    fi
  done
}

nginx_watchdog() {
  while true; do
    sleep 60
    if ! pgrep nginx > /dev/null; then
      notify "🚨 Nginx MATI!" "Nginx crash! Restart..." "urgent" "rotating_light"
      nginx && notify "🔄 Nginx Direstart" "Nginx OK." "high" "white_check_mark"
    fi
  done
}

ollama_watchdog() {
  while true; do
    sleep 60
    if ! pgrep ollama > /dev/null; then
      notify "🚨 Ollama MATI!" "Ollama crash! Restart..." "urgent" "robot_face,rotating_light"
      ollama serve > /tmp/ollama.log 2>&1 &
      sleep 10
      pgrep ollama > /dev/null && notify "🔄 Ollama Direstart" "Ollama OK." "high" "robot_face,white_check_mark"
    fi
  done
}

# =============================================
# MAIN
# =============================================
log "============================================="
log "  Devculture VPS — Ubuntu 20.04"
log "  Branch : Devculture"
log "  Ports  : 22 80 443 3000 8080 8888 11434"
log "  ntfy   : $NTFY_TOPIC"
log "  Model  : $AUTO_PULL_MODEL (auto-pull/update)"
log "  Start  : $START_TIME"
log "============================================="

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

notify "🚀 Devculture VPS Booting..." \
  "Ubuntu 20.04 sedang startup...

Ports: SSH(22) Nginx/Ollama(80) 443 3000 8080 8888
Model '$AUTO_PULL_MODEL' akan diunduh/update otomatis.

📲 ntfy.sh/$NTFY_TOPIC
🕐 $START_TIME" "default" "rocket,hourglass"

# 1. SSH
/usr/sbin/sshd && log "✅ SSH started"
notify "🔑 SSH Aktif" "SSH daemon start OK." "low" "key"

# 2. Ollama
log "🤖 Starting Ollama..."
ollama serve > /tmp/ollama.log 2>&1 &
sleep 3
pgrep ollama > /dev/null && log "✅ Ollama started"

# 3. Nginx
nginx -t 2>&1 | tail -1 && nginx && log "✅ Nginx started"
notify "🌐 Nginx Aktif" "Nginx proxy Ollama OK.\nAPI: /api/ | UI: /" "low" "globe_with_meridians"

# 4. Placeholder ports
python3 - << 'PY' &
import http.server, socketserver, threading, time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'Devculture VPS - OK')
for p in [443, 3000, 8888]:
    threading.Thread(target=lambda p=p: socketserver.TCPServer(('',p),H).serve_forever(), daemon=True).start()
time.sleep(86400 * 365)
PY
sleep 2

# 5. Auto-pull/update model (background)
ollama_auto_pull &

# 6. Bore tunnels
bore_tunnel 22   "SSH-22"    &
bore_tunnel 80   "HTTP-80"   &
bore_tunnel 443  "HTTPS-443" &
bore_tunnel 3000 "APP-3000"  &
bore_tunnel 8080 "APP-8080"  &
bore_tunnel 8888 "APP-8888"  &

# 7. Watchdogs & monitor
ssh_watchdog    &
nginx_watchdog  &
ollama_watchdog &
monitor_loop    &

# 8. Health check Railway (port 8080)
log "✅ Health check :8080"
exec python3 -c "
import http.server, socketserver
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'OK')
socketserver.TCPServer(('', 8080), H).serve_forever()
"
