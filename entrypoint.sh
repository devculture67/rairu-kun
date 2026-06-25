#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
CF_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
CF_DOMAIN="methatech.eu.org"
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
# Cloudflare Tunnel (domain statis)
# =============================================
start_cloudflare_tunnel() {
  if [ -z "$CF_TUNNEL_TOKEN" ]; then
    log "⚠️  CLOUDFLARE_TUNNEL_TOKEN tidak diset — skip tunnel"
    log "   Tambahkan di Railway Variables untuk aktifkan $CF_DOMAIN"
    return
  fi

  log "☁️  Memulai Cloudflare Tunnel → $CF_DOMAIN..."
  cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" \
    > /tmp/cloudflared.log 2>&1 &
  CF_PID=$!

  # Tunggu tunnel terhubung (max 30 detik)
  local connected=false
  for i in $(seq 1 15); do
    sleep 2
    if grep -q "Connection registered" /tmp/cloudflared.log 2>/dev/null || \
       grep -q "Registered tunnel" /tmp/cloudflared.log 2>/dev/null || \
       grep -q "conid=" /tmp/cloudflared.log 2>/dev/null; then
      connected=true; break
    fi
  done

  if [ "$connected" = true ]; then
    log "✅ Cloudflare Tunnel AKTIF → $CF_DOMAIN"
    notify "☁️ Domain Aktif!" \
"Cloudflare Tunnel berhasil! 🎉

🌐 Web UI  : https://$CF_DOMAIN
🤖 API     : https://$CF_DOMAIN/api/
📡 Domain  : $CF_DOMAIN (HTTPS otomatis!)

✅ Domain STATIS — tidak berubah walau restart!
✅ HTTPS gratis via Cloudflare SSL
✅ Tidak perlu cek port lagi

Backup (bore):
🔑 SSH : cek notif port SSH" \
    "high" "white_check_mark,cloud,globe_with_meridians,tada"
  else
    log "⚠️  Cloudflare Tunnel belum terhubung — cek token"
    log "   Log: $(tail -3 /tmp/cloudflared.log 2>/dev/null)"
    notify "⚠️ Cloudflare Tunnel Gagal" \
"Tunnel ke $CF_DOMAIN gagal terhubung.

Kemungkinan penyebab:
• Token salah/expired di Railway Variables
• Tunnel belum dibuat di Cloudflare Zero Trust
• Domain belum diarahkan ke tunnel

Cek log: /tmp/cloudflared.log
Panduan setup: lihat README.md" \
    "high" "warning,cloud,x"
  fi

  # Watchdog Cloudflare tunnel
  cloudflare_watchdog $CF_PID &
}

cloudflare_watchdog() {
  local PID="$1"
  while true; do
    sleep 60
    if ! kill -0 $PID 2>/dev/null; then
      log "🔄 Cloudflare Tunnel terputus, reconnecting..."
      notify "🔄 CF Tunnel Reconnect" \
        "Cloudflare Tunnel terputus.\nMemulai ulang..." "default" "arrows_counterclockwise,cloud"
      cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" \
        >> /tmp/cloudflared.log 2>&1 &
      PID=$!
      sleep 15
      kill -0 $PID 2>/dev/null && \
        notify "✅ CF Tunnel Aktif Kembali" \
          "$CF_DOMAIN terhubung kembali!\nhttps://$CF_DOMAIN" "default" "white_check_mark,cloud"
    fi
  done
}

# =============================================
# Bore tunnel per port (backup jika CF down)
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
      notify "⚠️ Bore Gagal [$label]" \
        "Port $lport gagal bore tunnel.\nRetry 5s..." "high" "warning"
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    notify "🔄 Bore Terputus [$label]" \
      "Port $lport terputus. Reconnect..." "default" "arrows_counterclockwise"
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
  local UPTIME=$(uptime -p 2>/dev/null || echo 'baru start')
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3, $2}' || echo 'n/a')
  local IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo 'n/a')
  local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print "  • "$1}' | head -5 || echo '  (belum ada)')
  local CF_STATUS="⏳ Pending"
  [ -n "$CF_TUNNEL_TOKEN" ] && grep -q "Connection registered\|Registered tunnel\|conid=" /tmp/cloudflared.log 2>/dev/null \
    && CF_STATUS="✅ https://$CF_DOMAIN"

  notify "🖥️ Devculture VPS ONLINE!" \
"✅ Ubuntu 20.04 VPS AKTIF

☁️ Domain   : $CF_STATUS
🔑 SSH      : ssh root@bore.pub -p ${P22}
🔒 Password : ${ROOT_PASS}
🌐 Bore UI  : http://bore.pub:${P80:-pending}

🤖 Model Ollama:
${MODELS}

🌍 IP Publik : $IP
⏰ Uptime    : $UPTIME
💾 RAM       : $MEM
🕐 Start     : $START_TIME
📲 ntfy      : ntfy.sh/$NTFY_TOPIC" \
    "high" "computer,key,white_check_mark,tada"
}

# =============================================
# Auto-pull + auto-update model Ollama
# =============================================
ollama_auto_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "⏳ Menunggu Ollama siap..."

  local ready=false
  for i in $(seq 1 30); do
    sleep 2
    if curl -s --max-time 3 http://localhost:11434/api/tags > /dev/null 2>&1; then
      ready=true; break
    fi
  done

  if [ "$ready" = false ]; then
    notify "⚠️ Auto-Pull Ditunda" \
      "Ollama belum ready.\nPull manual: ollama pull $model" "low" "warning,robot_face"
    return
  fi

  local CF_URL=""
  [ -n "$CF_TUNNEL_TOKEN" ] && CF_URL="\n🌐 https://$CF_DOMAIN"

  if ollama list 2>/dev/null | grep -q "^$model"; then
    log "🔄 Update model $model..."
    notify "🔄 Update Model..." "Memperbarui '$model' ke versi terbaru..." "low" "arrows_counterclockwise,robot_face"
    IS_UPDATE=true
  else
    log "⬇️ Pull model: $model"
    notify "⬇️ Mengunduh Model AI..." \
      "Auto-pull: $model\nProses di background, notif saat selesai 🎉" "default" "robot_face,hourglass"
    IS_UPDATE=false
  fi

  if ollama pull "$model" >> /tmp/ollama-pull.log 2>&1; then
    local SIZE=$(ollama list 2>/dev/null | grep "^$model" | awk '{print $3, $4}')
    if [ "$IS_UPDATE" = true ]; then
      notify "✅ Model Di-Update!" \
        "Model '$model' versi terbaru! 🎉\n📦 Ukuran: ${SIZE}\n🤖 SSH: ollama run $model${CF_URL}" \
        "default" "robot_face,white_check_mark,arrows_counterclockwise"
    else
      notify "✅ Model AI Siap!" \
        "Model '$model' siap dipakai! 🎉\n📦 Ukuran: ${SIZE}\n💬 SSH: ollama run $model${CF_URL}\n\nModel lain:\n  ollama pull phi3 (2.3GB)\n  ollama pull tinyllama (637MB)" \
        "high" "robot_face,white_check_mark,tada"
    fi
    update_summary
  else
    notify "❌ Pull Model Gagal" \
      "Gagal: $model\n$(tail -2 /tmp/ollama-pull.log 2>/dev/null)\nCoba: ollama pull $model" \
      "high" "warning,robot_face"
  fi
}

# =============================================
# Monitor setiap 5 menit
# =============================================
monitor_loop() {
  local check=0
  while true; do
    sleep 300; check=$((check + 1))
    local P22=$(cat /tmp/port_22.txt 2>/dev/null)
    [ -z "$P22" ] && continue
    local UPTIME=$(uptime -p 2>/dev/null || echo 'running')
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB (%.0f%%)", $3,$2,$3/$2*100}')
    local LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')
    local DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $5}')
    local OLLAMA_STATUS="❌ Mati"
    pgrep ollama > /dev/null && OLLAMA_STATUS="✅ Aktif"
    local CF_STATUS="❌ Off (set CLOUDFLARE_TUNNEL_TOKEN)"
    [ -n "$CF_TUNNEL_TOKEN" ] && CF_STATUS="✅ https://$CF_DOMAIN"
    local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
    notify "📊 Status VPS #${check}" \
      "⏰ Uptime  : $UPTIME\n💾 RAM     : $MEM\n⚡ Load    : $LOAD\n💽 Disk    : $DISK\n🤖 Ollama  : $OLLAMA_STATUS\n☁️ Domain   : $CF_STATUS\n📦 Model   : ${MODELS:-(none)}\n🔑 SSH     : bore.pub:$P22" \
      "min" "bar_chart,clock4"
  done
}

# =============================================
# Watchdogs
# =============================================
ssh_watchdog() {
  while true; do sleep 60
    pgrep sshd > /dev/null || { notify "🚨 SSH MATI!" "Restart SSH..." "urgent" "sos"
      /usr/sbin/sshd && notify "🔄 SSH OK" "SSH restart OK." "high" "white_check_mark"; }
  done
}

nginx_watchdog() {
  while true; do sleep 60
    pgrep nginx > /dev/null || { notify "🚨 Nginx MATI!" "Restart nginx..." "urgent" "rotating_light"
      nginx && notify "🔄 Nginx OK" "Nginx restart OK." "high" "white_check_mark"; }
  done
}

ollama_watchdog() {
  while true; do sleep 60
    pgrep ollama > /dev/null || { notify "🚨 Ollama MATI!" "Restart ollama..." "urgent" "robot_face"
      ollama serve > /tmp/ollama.log 2>&1 &
      sleep 10; pgrep ollama > /dev/null && notify "🔄 Ollama OK" "Ollama restart OK." "high" "robot_face"; }
  done
}

# =============================================
# MAIN
# =============================================
log "============================================="
log "  Devculture VPS — Ubuntu 20.04"
log "  Domain : $CF_DOMAIN (Cloudflare Tunnel)"
log "  ntfy   : $NTFY_TOPIC"
log "  Model  : $AUTO_PULL_MODEL (auto-pull)"
log "  CF     : ${CF_TUNNEL_TOKEN:+SET}${CF_TUNNEL_TOKEN:-NOT SET}"
log "  Start  : $START_TIME"
log "============================================="

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

notify "🚀 Devculture VPS Booting..." \
  "Ubuntu 20.04 startup...

🌐 Domain : $CF_DOMAIN
📲 ntfy   : ntfy.sh/$NTFY_TOPIC
🕐 Start  : $START_TIME

${CF_TUNNEL_TOKEN:+☁️ Cloudflare Tunnel aktif!}${CF_TUNNEL_TOKEN:-⚠️ Set CLOUDFLARE_TUNNEL_TOKEN untuk domain statis}" \
  "default" "rocket,hourglass"

# 1. SSH
/usr/sbin/sshd && log "✅ SSH started"

# 2. Ollama
ollama serve > /tmp/ollama.log 2>&1 & sleep 3

# 3. Nginx
nginx -t 2>&1 | tail -1 && nginx && log "✅ Nginx started"

# 4. Cloudflare Tunnel (domain statis)
start_cloudflare_tunnel

# 5. Placeholder ports
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

# 6. Auto-pull/update model
ollama_auto_pull &

# 7. Bore tunnels (backup & SSH)
bore_tunnel 22   "SSH-22"    &
bore_tunnel 80   "HTTP-80"   &
bore_tunnel 443  "HTTPS-443" &
bore_tunnel 3000 "APP-3000"  &
bore_tunnel 8080 "APP-8080"  &
bore_tunnel 8888 "APP-8888"  &

# 8. Watchdogs & monitor
ssh_watchdog &
nginx_watchdog &
ollama_watchdog &
monitor_loop &

# 9. Health check Railway (port 8080)
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
