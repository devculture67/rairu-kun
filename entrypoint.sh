#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"
# Default model: smollm2 (270MB) — paling ringan, gratis
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
  local P8080=$(cat /tmp/port_8080.txt 2>/dev/null)
  local P8888=$(cat /tmp/port_8888.txt 2>/dev/null)
  local UPTIME=$(uptime -p 2>/dev/null || echo 'baru start')
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB / %dMB", $3, $2}' || echo 'n/a')
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
🔧 Port 8080: bore.pub:${P8080:-pending}
📡 Port 8888: bore.pub:${P8888:-pending}

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
# Auto-pull model Ollama (gratis, ringan)
# =============================================
ollama_auto_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "⏳ Menunggu Ollama siap sebelum pull model..."

  # Tunggu Ollama benar-benar ready (max 60 detik)
  local ready=false
  for i in $(seq 1 30); do
    sleep 2
    if curl -s --max-time 3 http://localhost:11434/api/tags > /dev/null 2>&1; then
      ready=true
      break
    fi
  done

  if [ "$ready" = false ]; then
    log "⚠️ Ollama belum ready setelah 60s, skip auto-pull"
    notify "⚠️ Auto-Pull Ditunda" \
      "Ollama belum ready.\nPull manual via SSH:\n  ollama pull $model" \
      "low" "warning,robot_face"
    return
  fi

  # Cek apakah model sudah ada
  if ollama list 2>/dev/null | grep -q "^$model"; then
    log "✅ Model $model sudah ada, skip pull"
    notify "🤖 Model Sudah Ada" \
      "Model '$model' sudah tersedia!\nLangsung bisa chat di Web UI." \
      "low" "robot_face,white_check_mark"
    return
  fi

  # Mulai pull
  log "⬇️ Pulling model: $model"
  notify "⬇️ Mengunduh Model AI..." \
    "Auto-pull: $model\n\nModel ini gratis & ringan:\n• smollm2 = 270MB\n• tinyllama = 637MB\n• phi3 = 2.3GB\n\nProses berjalan di background.\nAkan ada notif saat selesai 🎉" \
    "default" "robot_face,hourglass"

  if ollama pull "$model" >> /tmp/ollama-pull.log 2>&1; then
    log "✅ Model $model berhasil di-pull"
    local SIZE=$(ollama list 2>/dev/null | grep "^$model" | awk '{print $3, $4}')
    notify "✅ Model AI Siap Dipakai!" \
      "Model '$model' berhasil diunduh! 🎉

📦 Ukuran : ${SIZE:-'lihat di ollama list'}
🌐 Chat   : buka bore.pub:80 di browser
💬 SSH    : ollama run $model

Model lain bisa di-pull via SSH:
  ollama pull tinyllama  (637MB)
  ollama pull phi3       (2.3GB)
  ollama pull mistral    (4.1GB)" \
      "high" "robot_face,white_check_mark,tada"
    # Kirim ulang summary dengan model terbaru
    update_summary
  else
    log "❌ Gagal pull model $model"
    notify "❌ Pull Model Gagal" \
      "Gagal download '$model'.\nLog: /tmp/ollama-pull.log\n$(tail -3 /tmp/ollama-pull.log 2>/dev/null)\n\nCoba manual via SSH:\n  ollama pull tinyllama" \
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
    local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
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
      notify "🚨 SSH MATI!" "SSH crash! Mencoba restart..." "urgent" "rotating_light,sos"
      /usr/sbin/sshd && notify "🔄 SSH Direstart" "SSH berhasil direstart." "high" "white_check_mark"
    fi
  done
}

nginx_watchdog() {
  while true; do
    sleep 60
    if ! pgrep nginx > /dev/null; then
      notify "🚨 Nginx MATI!" "Nginx crash! Mencoba restart..." "urgent" "rotating_light"
      nginx && notify "🔄 Nginx Direstart" "Nginx berhasil direstart." "high" "white_check_mark"
    fi
  done
}

ollama_watchdog() {
  while true; do
    sleep 60
    if ! pgrep ollama > /dev/null; then
      notify "🚨 Ollama MATI!" "Ollama crash! Mencoba restart..." "urgent" "robot_face,rotating_light"
      ollama serve > /tmp/ollama.log 2>&1 &
      sleep 10
      pgrep ollama > /dev/null && notify "🔄 Ollama Direstart" "Ollama berhasil direstart." "high" "robot_face,white_check_mark"
    fi
  done
}

# =============================================
# MAIN
# =============================================
log "============================================="
log "  Devculture VPS — Ubuntu 20.04"
log "  Ports : 22 80 443 3000 8080 8888 11434"
log "  ntfy  : $NTFY_TOPIC"
log "  Model : $AUTO_PULL_MODEL (auto-pull)"
log "  Start : $START_TIME"
log "============================================="

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

notify "🚀 Devculture VPS Booting..." \
  "Ubuntu 20.04 sedang startup...\n\nPorts: SSH(22) Nginx(80) HTTPS(443) 3000 8080 8888\nOllama model '$AUTO_PULL_MODEL' akan diunduh otomatis.\n\n📲 ntfy.sh/$NTFY_TOPIC\n🕐 $START_TIME" \
  "default" "rocket,hourglass"

# 1. SSH
/usr/sbin/sshd && log "✅ SSH started"
notify "🔑 SSH Aktif" "SSH daemon berhasil start." "low" "key"

# 2. Ollama
log "🤖 Starting Ollama..."
ollama serve > /tmp/ollama.log 2>&1 &
sleep 3
pgrep ollama > /dev/null && log "✅ Ollama started" || log "⚠️ Ollama belum ready"

# 3. Nginx
nginx -t 2>&1 | tail -2 && nginx && log "✅ Nginx started"
notify "🌐 Nginx Aktif" "Nginx proxy Ollama API & UI aktif di port 80." "low" "globe_with_meridians"

# 4. Placeholder ports 443, 3000, 8888
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

# 5. Auto-pull model (background, tidak blokir startup)
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
log "✅ Health check server :8080"
exec python3 -c "
import http.server, socketserver
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'OK')
socketserver.TCPServer(('', 8080), H).serve_forever()
"
