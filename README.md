<div align="center">

<img src="https://ollama.ai/public/ollama.png" width="120" alt="Ollama Logo" />

# 🤖 Rairu-kun — Free Ollama VPS

**Jalankan Ollama AI secara gratis dengan kualitas premium**
*Ubuntu 20.04 · Docker · Railway · Nginx · ntfy Notifications*

---

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-Latest-000000?logo=ollama&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-Proxy-009639?logo=nginx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

</div>

---

## ✨ Fitur Unggulan

| Fitur | Keterangan |
|-------|-----------|
| 🤖 **Ollama AI** | Jalankan LLM lokal (Llama3, Mistral, Phi, dll) |
| 🌐 **Nginx Proxy** | API Ollama di `/api/` + Web UI di `/` |
| 🔑 **SSH Access** | Akses terminal penuh via SSH |
| 📡 **Bore Tunnel** | Expose port ke publik tanpa domain |
| 📲 **ntfy Notifikasi** | Alert real-time di HP (startup, SSH login, status) |
| 🔄 **Auto Watchdog** | SSH, Nginx, Ollama restart otomatis jika crash |
| 📊 **Monitor 5 Menit** | Laporan RAM, CPU, Disk, Uptime berkala |
| 🐳 **Multi-Port** | 22, 80, 443, 3000, 8080, 8888, 11434 |

---

## 📋 Daftar Isi

- [Prasyarat](#-prasyarat)
- [Deploy di Railway (Gratis)](#-deploy-di-railway-gratis)
- [Konfigurasi Environment](#️-konfigurasi-environment)
- [Akses VPS via SSH](#-akses-vps-via-ssh)
- [Menggunakan Ollama](#-menggunakan-ollama)
- [Web UI Ollama](#-web-ui-ollama)
- [Model yang Tersedia](#-model-yang-tersedia)
- [Notifikasi ntfy](#-notifikasi-ntfy)
- [Port & Endpoint](#-port--endpoint)
- [Troubleshooting](#-troubleshooting)

---

## 📦 Prasyarat

Sebelum memulai, pastikan Anda memiliki:

- ✅ Akun [Railway](https://railway.app) (gratis)
- ✅ Akun [GitHub](https://github.com) (untuk fork repo ini)
- ✅ Aplikasi **ntfy** di HP ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/app/ntfy/id1625396347))

> **💡 Railway Free Tier** memberikan **$5 credit/bulan** — cukup untuk menjalankan VPS 24 jam penuh tanpa biaya!

---

## 🚀 Deploy di Railway (Gratis)

### Langkah 1 — Fork Repo Ini

Klik tombol **Fork** di pojok kanan atas halaman ini.

### Langkah 2 — Buat Project Railway Baru

1. Buka [railway.app](https://railway.app) → **New Project**
2. Pilih **Deploy from GitHub repo**
3. Pilih repo hasil fork Anda `username/rairu-kun`
4. Klik **Deploy Now**

### Langkah 3 — Set Environment Variables

Di Railway dashboard → **Variables**, tambahkan:

```env
NTFY_TOPIC=nama-unik-anda          # Ganti dengan nama unik!
BORE_SERVER=bore.pub
ROOT_PASS=password-anda            # Password SSH root
TZ=Asia/Jakarta
```

> **⚠️ Penting:** Ganti `NTFY_TOPIC` dengan nama unik agar notifikasi tidak tercampur dengan orang lain!

### Langkah 4 — Tunggu Build Selesai

Railway akan build Docker image secara otomatis (~5-15 menit). Pantau progress di tab **Deployments**.

### Langkah 5 — Terima Notifikasi

Buka aplikasi **ntfy** di HP → subscribe ke topic Anda:

```
ntfy.sh/nama-unik-anda
```

Setelah VPS online, Anda akan menerima notifikasi berisi **perintah SSH lengkap** beserta port-nya! 🎉

---

## ⚙️ Konfigurasi Environment

| Variable | Default | Keterangan |
|----------|---------|-----------|
| `NTFY_TOPIC` | `rairu-devculture67` | Topic ntfy untuk notifikasi |
| `BORE_SERVER` | `bore.pub` | Server bore tunnel |
| `ROOT_PASS` | `craxid` | Password root SSH |
| `TZ` | `Asia/Jakarta` | Timezone |
| `OLLAMA_HOST` | `0.0.0.0` | Bind address Ollama |

---

## 🔑 Akses VPS via SSH

Setelah VPS online, cek notifikasi ntfy untuk mendapatkan port SSH:

```bash
ssh root@bore.pub -p <PORT_DARI_NTFY>
```

**Contoh:**
```bash
ssh root@bore.pub -p 12345
# Password: sesuai ROOT_PASS yang di-set
```

> **💡 Tips:** Tambahkan ke `~/.ssh/config` untuk koneksi cepat:
> ```
> Host rairu
>     HostName bore.pub
>     Port 12345
>     User root
> ```
> Lalu cukup `ssh rairu`

---

## 🤖 Menggunakan Ollama

### Pull Model via SSH

Setelah login SSH, pull model yang Anda inginkan:

```bash
# Model ringan & cepat (direkomendasikan untuk RAM terbatas)
ollama pull phi3            # 2.3 GB — Microsoft Phi-3
ollama pull llama3.2        # 2.0 GB — Meta Llama 3.2 3B
ollama pull mistral         # 4.1 GB — Mistral 7B
ollama pull gemma2          # 5.4 GB — Google Gemma 2 9B

# Model coding
ollama pull codellama       # 3.8 GB — Code Llama
ollama pull qwen2.5-coder   # 4.7 GB — Qwen 2.5 Coder

# Model kecil (super cepat)
ollama pull tinyllama       # 637 MB — TinyLlama 1.1B
ollama pull smollm2         # 270 MB — SmolLM2 135M
```

### Chat via Terminal

```bash
# Interactive chat
ollama run llama3.2

# Single question
ollama run phi3 "Jelaskan machine learning dalam 3 kalimat"

# List model yang sudah di-pull
ollama list

# Hapus model
ollama rm nama-model
```

### Gunakan via API (curl)

```bash
# Generate teks
curl http://bore.pub:<PORT_HTTP>/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "prompt": "Siapa kamu?",
    "stream": false
  }'

# Chat dengan riwayat
curl http://bore.pub:<PORT_HTTP>/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "messages": [
      {"role": "user", "content": "Halo!"}
    ]
  }'

# List model tersedia
curl http://bore.pub:<PORT_HTTP>/api/tags
```

### Gunakan dengan Python

```python
import requests

BASE_URL = "http://bore.pub:<PORT_HTTP>/api"

def chat(message, model="llama3.2"):
    r = requests.post(f"{BASE_URL}/chat", json={
        "model": model,
        "messages": [{"role": "user", "content": message}],
        "stream": False
    })
    return r.json()["message"]["content"]

print(chat("Apa itu kecerdasan buatan?"))
```

### Integrasi dengan OpenAI SDK

Ollama kompatibel dengan OpenAI API format!

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://bore.pub:<PORT_HTTP>/api",
    api_key="ollama"  # tidak perlu key asli
)

response = client.chat.completions.create(
    model="llama3.2",
    messages=[{"role": "user", "content": "Halo!"}]
)
print(response.choices[0].message.content)
```

---

## 🌐 Web UI Ollama

Akses Web UI di browser:

```
http://bore.pub:<PORT_HTTP>
```

**Fitur Web UI:**
- 💬 Chat interface dengan streaming real-time
- 🔄 Dropdown pilih model (auto-detect dari Ollama)
- 📝 System prompt kustom
- 🗑️ Clear chat history
- 📱 Responsive (bisa di HP)

---

## 📱 Model yang Tersedia

### Perbandingan Model Populer

| Model | Size | RAM Min | Kecepatan | Kualitas |
|-------|------|---------|-----------|----------|
| `tinyllama` | 637 MB | 1 GB | ⚡⚡⚡ | ⭐⭐ |
| `phi3` | 2.3 GB | 3 GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| `llama3.2` | 2.0 GB | 3 GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| `mistral` | 4.1 GB | 5 GB | ⚡⚡ | ⭐⭐⭐⭐⭐ |
| `llama3.1:8b` | 4.7 GB | 6 GB | ⚡⚡ | ⭐⭐⭐⭐⭐ |
| `codellama` | 3.8 GB | 5 GB | ⚡⚡ | ⭐⭐⭐⭐ (coding) |

> **💡 Untuk Railway free tier**, rekomendasikan: `phi3` atau `llama3.2` (RAM paling efisien)

---

## 📲 Notifikasi ntfy

Subscribe di HP atau browser ke:
```
https://ntfy.sh/<NTFY_TOPIC_ANDA>
```

### Daftar Notifikasi

| Event | Prioritas | Keterangan |
|-------|-----------|-----------|
| 🚀 VPS Booting | Normal | Container baru start |
| 🔑 SSH Aktif | Low | SSH daemon berhasil start |
| 🤖 Ollama Starting | Low | Ollama mulai berjalan |
| 🤖 Ollama Siap | Normal | Daftar model tersedia |
| ✅ VPS ONLINE | **High** | SSH port + semua tunnel siap |
| 📊 Status 5-menit | Min | RAM, CPU, Disk, Uptime |
| 🔑 SSH Login | **High** | Ada yang login SSH (IP tercatat) |
| 🔄 Tunnel Terputus | Normal | Bore disconnect, reconnecting |
| 🚨 SSH/Nginx/Ollama MATI | **Urgent** | Service crash |
| 🔄 Service Direstart | High | Watchdog berhasil restart |

### Contoh Notifikasi "VPS ONLINE"

```
✅ Ubuntu 20.04 VPS AKTIF

🔑 SSH      : ssh root@bore.pub -p 12345
🔒 Password : yourpassword
🌐 Nginx/UI : http://bore.pub:23456
🤖 Ollama   : http://bore.pub:23456/api/
🔐 HTTPS    : bore.pub:34567

🌍 IP Publik : 1.2.3.4
⏰ Uptime    : up 2 minutes
💾 RAM       : 512MB / 2048MB
💽 Disk      : 1.2GB / 10GB (12%)
🕐 Start     : 2025-01-01 10:00:00 WIB
```

---

## 🔌 Port & Endpoint

| Port | Layanan | Endpoint |
|------|---------|----------|
| `22` | SSH | `ssh root@bore.pub -p <PORT>` |
| `80` | Nginx → Ollama UI | `http://bore.pub:<PORT>/` |
| `80` | Nginx → Ollama API | `http://bore.pub:<PORT>/api/` |
| `443` | HTTPS redirect | `bore.pub:<PORT>` |
| `3000` | Custom app | `bore.pub:<PORT>` |
| `8080` | Health check | `bore.pub:<PORT>` |
| `8888` | Custom app | `bore.pub:<PORT>` |
| `11434` | Ollama direct | `localhost:11434` (internal) |

> Semua port di-expose via [bore](https://github.com/ekzhang/bore) tunnel secara otomatis. Port publik bersifat dinamis — selalu cek notifikasi ntfy terbaru.

---

## 🛠️ Troubleshooting

### ❓ Tidak menerima notifikasi ntfy?

1. Pastikan sudah subscribe ke topic yang benar
2. Cek `NTFY_TOPIC` di Railway Variables
3. Buka `https://ntfy.sh/<NTFY_TOPIC>` di browser

### ❓ Ollama lambat atau crash?

```bash
# SSH ke VPS, cek log Ollama
tail -f /tmp/ollama.log

# Cek penggunaan RAM
free -h

# Gunakan model yang lebih kecil
ollama pull phi3  # lebih ringan dari llama3
```

### ❓ SSH tidak bisa connect?

```bash
# Cek notifikasi ntfy terbaru untuk port terbaru
# Port berubah setiap container restart

# Cek apakah SSH jalan (dari dalam Railway Console)
pgrep sshd
```

### ❓ Port HTTP berubah setiap restart?

Ini normal karena bore tunnel menggunakan port dinamis. **Selalu cek ntfy** untuk port terbaru, atau gunakan Railway domain untuk port 80.

### ❓ Model terhapus setelah restart?

Railway tidak persistent storage by default. Solusi:
- Gunakan **Railway Volume** untuk menyimpan `/root/.ollama`
- Atau pull ulang model setiap kali via SSH

---

## 🏗️ Struktur Proyek

```
rairu-kun/
├── Dockerfile              # Ubuntu 20.04 + Nginx + Ollama + Bore
├── entrypoint.sh           # Script startup utama
├── nginx-ollama.conf       # Nginx proxy config untuk Ollama
├── notify-ssh-login.sh     # Notifikasi SSH login
├── railway.toml            # Konfigurasi Railway deploy
├── ollama-ui/
│   └── index.html          # Web UI chat Ollama
├── fly.toml                # Config Fly.io (opsional)
└── render.yaml             # Config Render.com (opsional)
```

---

## 🤝 Kontribusi

Pull request sangat disambut! Beberapa ide kontribusi:
- [ ] Tambah autentikasi Basic Auth nginx
- [ ] Support model download otomatis via env var
- [ ] Dashboard monitoring dengan grafik
- [ ] Integrasi Telegram bot

---

## 📄 Lisensi

MIT License — bebas digunakan, dimodifikasi, dan didistribusikan.

---

<div align="center">

**Dibuat dengan ❤️ oleh [devculture67](https://github.com/devculture67)**

*Jalankan AI lokal gratis — tanpa bayar API, tanpa batas!*

⭐ **Star repo ini jika membantu!** ⭐

</div>
