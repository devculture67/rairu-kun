#!/bin/bash
set -e

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
CF_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
CF_DOMAIN="methatech.eu.org"
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$(date '+%H:%M:%S')] $*"; }

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" -H "Priority: $priority" \
    -H "Tags: $tags" -H "Content-Type: text/plain" \
    -d "$body" >/dev/null 2>&1 || true
}

# =============================================
# Cloudflare Tunnel
# =============================================
start_cloudflare_tunnel() {
  if [ -z "$CF_TUNNEL_TOKEN" ]; then
    log "⚠️  CLOUDFLARE_TUNNEL_TOKEN tidak diset — skip tunnel"
    return
  fi

  if ! command -v cloudflared >/dev/null 2>&1; then
    log "⚠️  cloudflared binary tidak ada, skip tunnel"
    return
  fi

  log "☁️  Starting Cloudflare Tunnel → $CF_DOMAIN"
  cloudflared tunnel --no-autoupdate --loglevel info run \
    --token "$CF_TUNNEL_TOKEN" > /tmp/cloudflared.log 2>&1 &
  CF_PID=$!

  # Poll sampai connected (max 60 detik)
  local connected=false
  for i in $(seq 1 20); do
    sleep 3
    if grep -qiE "Connection established|Registered tunnel|connection registered|conid=|registered conn" \
        /tmp/cloudflared.log 2>/dev/null; then
      connected=true; break
    fi
    # juga cek kalau cloudflared masih jalan
    kill -0 $CF_PID 2>/dev/null || break
  done

  if [ "$connected" = true ]; then
    log "✅ Cloudflare Tunnel AKTIF → https://$CF_DOMAIN"
    echo "$CF_PID" > /tmp/cf_pid.txt
    notify "☁️ Domain Live!" \
"Cloudflare Tunnel aktif! 🎉

🌐 Web UI  : https://$CF_DOMAIN
🤖 API     : https://$CF_DOMAIN/api/
🔐 HTTPS   : otomatis gratis!

Domain STATIS — tidak berubah walau restart
Bisa langsung chat di browser sekarang!" \
    "high" "white_check_mark,cloud,globe_with_meridians,tada"
  else
    log "⚠️  CF Tunnel belum connect setelah 60s"
    log "   Log: $(tail -5 /tmp/cloudflared.log 2>/dev/null)"
    notify "⚠️ CF Tunnel Belum Connect" \
"Tunnel ke $CF_DOMAIN belum terhubung.
Log: $(tail -3 /tmp/cloudflared.log 2>/dev/null)

Masih mencoba di background..." \
    "default" "warning,cloud"
  fi

  # Watchdog
  (while true; do
    sleep 30
    if [ -n "$(cat /tmp/cf_pid.txt 2>/dev/null)" ]; then
      PID=$(cat /tmp/cf_pid.txt)
      kill -0 $PID 2>/dev/null || {
        log "🔄 CF Tunnel mati, restart..."
        cloudflared tunnel --no-autoupdate --loglevel info run \
          --token "$CF_TUNNEL_TOKEN" >> /tmp/cloudflared.log 2>&1 &
        echo $! > /tmp/cf_pid.txt
      }
    fi
  done) &
}

# =============================================
# Bore tunnel
# =============================================
bore_tunnel() {
  local lport="$1" label="$2"
  local log_file="/tmp/bore_${lport}.log"
  while true; do
    > "$log_file"
    bore local "$lport" --to "$BORE_SERVER" >"$log_file" 2>&1 &
    local PID=$! PORT=""
    for i in $(seq 1 40); do
      sleep 1
      PORT=$(grep -oE "${BORE_SERVER}:[0-9]+" "$log_file" 2>/dev/null | head -1 | cut -d: -f2)
      [ -n "$PORT" ] && break
    done
    if [ -n "$PORT" ]; then
      log "[$label] bore.pub:$PORT"
      echo "$PORT" > "/tmp/port_${lport}.txt"
      update_summary
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    sleep 5
  done
}

update_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3, $2}')
  local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print "  •",$1}' | head -5)
  local CF_LINE=""
  [ -n "$CF_TUNNEL_TOKEN" ] && CF_LINE="☁️ Domain   : https://$CF_DOMAIN"$'\n'

  notify "🖥️ VPS ONLINE!" \
"✅ Devculture Ubuntu 20.04

${CF_LINE}🔑 SSH      : ssh root@bore.pub -p $P22
🔒 Password : $ROOT_PASS
🌐 Bore Web : http://bore.pub:$(cat /tmp/port_80.txt 2>/dev/null || echo pending)

🤖 Models:
${MODELS:-(belum ada, sedang pull...)}

💾 RAM: $MEM
🕐 $START_TIME
📲 ntfy.sh/$NTFY_TOPIC" \
  "high" "computer,key,white_check_mark,tada"
}

# =============================================
# Auto-pull Ollama model
# =============================================
ollama_auto_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "⏳ Tunggu Ollama ready..."
  local ready=false
  for i in $(seq 1 30); do
    sleep 2
    curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1 && { ready=true; break; }
  done
  [ "$ready" = false ] && { log "⚠️ Ollama tidak ready"; return; }

  local IS_UPDATE=false
  ollama list 2>/dev/null | grep -q "^$model" && IS_UPDATE=true

  if [ "$IS_UPDATE" = true ]; then
    notify "🔄 Update Model..." "Memperbarui $model..." "low" "arrows_counterclockwise,robot_face"
  else
    notify "⬇️ Download Model..." \
      "Mengunduh $model...\nAkan ada notif saat selesai 🎉\n\nModel lain:\n  ollama pull phi3 (2.3GB)\n  ollama pull tinyllama (637MB)" \
      "default" "robot_face,hourglass"
  fi

  if ollama pull "$model" >>/tmp/ollama-pull.log 2>&1; then
    local SIZE=$(ollama list 2>/dev/null | grep "^$model" | awk '{print $3,$4}')
    local CF_URL=""; [ -n "$CF_TUNNEL_TOKEN" ] && CF_URL="\n🌐 https://$CF_DOMAIN"
    notify "✅ Model Siap!" \
      "Model '$model' ready! 🎉\n📦 $SIZE${CF_URL}\n\nChat:\n  curl -X POST https://$CF_DOMAIN/api/chat\n  atau buka di browser!" \
      "high" "robot_face,white_check_mark,tada"
    update_summary
  else
    notify "❌ Pull Gagal" "$(tail -2 /tmp/ollama-pull.log)" "high" "warning"
  fi
}

# Watchdogs
monitor_loop() {
  local n=0
  while true; do
    sleep 300; n=$((n+1))
    local P22=$(cat /tmp/port_22.txt 2>/dev/null); [ -z "$P22" ] && continue
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB(%.0f%%)",$3,$2,$3/$2*100}')
    local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
    local CF="❌"; grep -q "Registered tunnel\|Connection established" /tmp/cloudflared.log 2>/dev/null && CF="✅ https://$CF_DOMAIN"
    notify "📊 Status #$n" \
      "💾 RAM: $MEM\n⚡ Load: $(cat /proc/loadavg|awk '{print $1,$2,$3}')\n💽 Disk: $(df -h/|awk 'NR==2{print $5}')\n🤖 Ollama: $(pgrep ollama>/dev/null&&echo ✅||echo ❌)\n☁️ CF: $CF\n📦 Model: ${MODELS:-(none)}\n🔑 SSH: bore.pub:$P22" \
      "min" "bar_chart"
  done
}

ssh_wd()    { while true; do sleep 60; pgrep sshd>/dev/null || { /usr/sbin/sshd && notify "🔄 SSH restart" "SSH OK" "high" "white_check_mark"; }; done; }
nginx_wd()  { while true; do sleep 60; pgrep nginx>/dev/null || { nginx && notify "🔄 Nginx restart" "Nginx OK" "high" "white_check_mark"; }; done; }
ollama_wd() { while true; do sleep 60; pgrep ollama>/dev/null || { ollama serve>/tmp/ollama.log 2>&1 & sleep 10; pgrep ollama>/dev/null && notify "🔄 Ollama restart" "Ollama OK" "high" "robot_face"; }; done; }

# =============================================
# MAIN
# =============================================
log "=== Devculture VPS Start ==="
log "Domain: $CF_DOMAIN | Model: $AUTO_PULL_MODEL | ntfy: $NTFY_TOPIC"
log "CF Token: ${CF_TUNNEL_TOKEN:+SET ($(echo -n $CF_TUNNEL_TOKEN|wc -c) chars)}${CF_TUNNEL_TOKEN:-NOT SET}"

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

notify "🚀 VPS Booting..." \
  "Ubuntu 20.04 startup...\n\n${CF_TUNNEL_TOKEN:+☁️ Cloudflare Tunnel → https://$CF_DOMAIN}${CF_TUNNEL_TOKEN:-⚠️ Set CLOUDFLARE_TUNNEL_TOKEN}\n\n📲 ntfy.sh/$NTFY_TOPIC" \
  "default" "rocket,hourglass"

# 1. SSH
/usr/sbin/sshd && log "✅ SSH"

# 2. Ollama
ollama serve >/tmp/ollama.log 2>&1 & sleep 3 && log "✅ Ollama serving"

# 3. Nginx
nginx -t 2>&1 | tail -1 && nginx && log "✅ Nginx"

# 4. Cloudflare Tunnel
start_cloudflare_tunnel

# 5. Port placeholders 443/3000/8888
python3 -c "
import http.server,socketserver,threading,time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'OK')
[threading.Thread(target=lambda p=p:socketserver.TCPServer(('',p),H).serve_forever(),daemon=True).start() for p in [443,3000,8888]]
time.sleep(86400*365)
" &
sleep 1

# 6. Pull model
ollama_auto_pull &

# 7. Bore tunnels (SSH + backup HTTP)
bore_tunnel 22   "SSH"   &
bore_tunnel 80   "HTTP"  &
bore_tunnel 443  "HTTPS" &
bore_tunnel 3000 "P3000" &
bore_tunnel 8080 "P8080" &
bore_tunnel 8888 "P8888" &

# 8. Watchdogs + monitor
ssh_wd & nginx_wd & ollama_wd & monitor_loop &

# 9. Health check port 8080 (Railway requirement)
log "✅ Health check :8080"
exec python3 -c "
import http.server,socketserver
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'OK')
socketserver.TCPServer(('',8080),H).serve_forever()
"
