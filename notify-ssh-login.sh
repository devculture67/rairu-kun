#!/bin/bash
# Notifikasi ntfy saat ada SSH login/logout
# Dipanggil dari /etc/profile.d/ saat user login

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
USER_LOGIN="${USER:-root}"
CLIENT_IP="${SSH_CLIENT%% *}"
SSH_TTY_INFO="${SSH_TTY:-local}"

if [ -n "$SSH_CLIENT" ]; then
  notify() {
    curl -s --max-time 8 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
      -H "Title: $1" -H "Priority: $2" -H "Tags: $3" \
      -d "$4" > /dev/null 2>&1 || true
  }
  notify \
    "🔑 SSH Login Terdeteksi" \
    "high" \
    "key,warning" \
    "User    : $USER_LOGIN
IP      : ${CLIENT_IP:-unknown}
TTY     : $SSH_TTY_INFO
Waktu   : $(date '+%Y-%m-%d %H:%M:%S')
Host    : $(hostname)
VPS     : devculture67/rairu-kun"
fi
