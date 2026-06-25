<div align="center">

# 🤖 Devculture — Free Ollama VPS

**Jalankan AI lokal gratis dengan kualitas premium**

*Ubuntu 20.04 · Docker · Railway · Nginx · Cloudflare Tunnel · ntfy Notifications*

---

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-Latest-000000?logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-Tunnel-F38020?logo=cloudflare&logoColor=white)
![Branch](https://img.shields.io/badge/Branch-Devculture-blue?logo=git)
![License](https://img.shields.io/badge/License-MIT-green)

</div>

---

## ✨ Fitur Unggulan

| Fitur | Keterangan |
|-------|-----------|
| ☁️ **Cloudflare Tunnel** | Domain statis `methatech.eu.org` — tidak berubah walau restart |
| 🔒 **HTTPS Otomatis** | SSL gratis via Cloudflare, tanpa sertifikat manual |
| 🤖 **Auto-Pull Model** | Download model AI otomatis saat startup |
| 🔄 **Auto-Update Mingguan** | Model selalu versi terbaru via GitHub Actions |
| 🌐 **Nginx + Web UI** | Chat interface di browser |
| 🔑 **SSH Access** | Terminal penuh via bore tunnel |
| 📲 **ntfy Notifikasi** | Alert real-time: startup, model ready, login SSH |
| 🐳 **Multi-Port** | 22, 80, 443, 3000, 8080, 8888, 11434 |
| 🆓 **100% Gratis** | Railway $5 credit/bulan, Cloudflare free, model open-source |

---

## 📋 Daftar Isi

- [Deploy Gratis di Railway](#-deploy-gratis-di-railway)
- [Setup Cloudflare Tunnel ⭐ WAJIB](#-setup-cloudflare-tunnel-untuk-domain-methatecehuorg)
- [Konfigurasi Environment](#️-konfigurasi-environment)
- [Cara Menjalankan Ollama](#-cara-menjalankan-ollama-di-vps)
- [Menggunakan via Web UI](#-menggunakan-via-web-ui)
- [Menggunakan via API](#-menggunakan-via-api)
- [Menggunakan via SSH Terminal](#-menggunakan-via-ssh-terminal)
- [Integrasi Python / Node.js](#-integrasi-kode)
- [Model yang Tersedia Gratis](#-model-gratis-yang-tersedia)
- [Auto-Update Mingguan](#-auto-update-mingguan)
- [Notifikasi ntfy](#-notifikasi-ntfy)
- [Troubleshooting](#-troubleshooting)

---

## 🚀 Deploy Gratis di Railway

### 1 — Fork repo ini

Klik tombol **Fork** di pojok kanan atas.

### 2 — Buat project Railway

1. Buka [railway.app](https://railway.app) → **New Project**
2. Pilih **Deploy from GitHub repo** → pilih fork Anda
3. Klik **Deploy Now**

### 3 — Setup Cloudflare Tunnel (wajib untuk domain statis)

Lihat panduan lengkap di bagian bawah → **[Setup Cloudflare Tunnel](#-setup-cloudflare-tunnel-untuk-domain-methatecehuorg)**

### 4 — Set Environment Variables Railway

```env
NTFY_TOPIC=nama-unik-anda
ROOT_PASS=password-ssh-anda
AUTO_PULL_MODEL=smollm2
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoixxxxxxxxxx...   # dari langkah CF Tunnel
TZ=Asia/Jakarta
```

### 5 — Subscribe ntfy

Install **ntfy** di HP → subscribe `ntfy.sh/nama-unik-anda`

Setelah build (~10-15 menit), notifikasi masuk berisi domain + SSH command 🎉

---

## ☁️ Setup Cloudflare Tunnel untuk Domain `methatech.eu.org`

> Ini yang membuat domain Anda **statis dan tidak berubah** walau VPS restart berkali-kali.

### Langkah 1 — Buka Cloudflare Zero Trust

1. Login [dash.cloudflare.com](https://dash.cloudflare.com)
2. Klik **Zero Trust** di sidebar kiri
3. (Jika pertama kali) buat nama team bebas, pilih **Free plan**

### Langkah 2 — Buat Tunnel Baru

1. Di sidebar Zero Trust → **Networks** → **Tunnels**
2. Klik **Create a tunnel**
3. Pilih **Cloudflared** → klik **Next**
4. Beri nama tunnel: `devculture-vps` → klik **Save Tunnel**

### Langkah 3 — Salin Token Tunnel

Setelah tunnel dibuat, Cloudflare menampilkan perintah install. Salin token dari bagian ini:

```
cloudflared tunnel --no-autoupdate run --token eyJhIjoiXXXXXXXXXXX...
```

> Salin teks panjang setelah `--token` — itulah **CLOUDFLARE_TUNNEL_TOKEN** Anda.

### Langkah 4 — Set Token di Railway

1. Buka Railway → project Anda → **Variables**
2. Tambah variable baru:
   ```
   CLOUDFLARE_TUNNEL_TOKEN = eyJhIjoiXXXXXXXXX...  (paste token tadi)
   ```
3. Klik **Deploy** untuk redeploy

### Langkah 5 — Konfigurasi Routing Domain

Kembali ke Cloudflare Zero Trust → tunnel `devculture-vps` → tab **Public Hostname**:

| Field | Value |
|-------|-------|
| **Subdomain** | *(kosong)* |
| **Domain** | `methatech.eu.org` |
| **Type** | `HTTP` |
| **URL** | `localhost:80` |

Klik **Save hostname**.

Tambah juga untuk subdomain AI API (opsional):

| Subdomain | Domain | Type | URL |
|-----------|--------|------|-----|
| *(kosong)* | `methatech.eu.org` | HTTP | `localhost:80` |
| `api` | `methatech.eu.org` | HTTP | `localhost:80` |

### Langkah 6 — Verifikasi DNS Cloudflare

Di Cloudflare dashboard → domain `methatech.eu.org` → **DNS**:

Harus ada record CNAME yang dibuat otomatis oleh Zero Trust:
```
CNAME  @  devculture-vps.cfargotunnel.com  (Proxied ☁️)
```

> Jika belum ada, tambah manual:
> - **Type**: CNAME
> - **Name**: `@` (atau `methatech`)
> - **Target**: `devculture-vps.cfargotunnel.com`
> - **Proxy**: ON (ikon ☁️ oranye)

### ✅ Hasil Akhir

```
https://methatech.eu.org          ← Web UI Ollama (HTTPS otomatis!)
https://methatech.eu.org/api/     ← Ollama API
https://api.methatech.eu.org/     ← API subdomain (jika dikonfigurasi)
```

**Domain TIDAK BERUBAH walau Railway restart berkali-kali!** 🎉

---

## ⚙️ Konfigurasi Environment

| Variable | Default | Keterangan |
|----------|---------|-----------|
| `CLOUDFLARE_TUNNEL_TOKEN` | *(wajib diset)* | Token tunnel dari Cloudflare Zero Trust |
| `NTFY_TOPIC` | `rairu-devculture67` | Topic ntfy (buat unik!) |
| `ROOT_PASS` | `craxid` | Password SSH root |
| `AUTO_PULL_MODEL` | `smollm2` | Model yang auto-pull saat startup |
| `BORE_SERVER` | `bore.pub` | Server tunnel (backup SSH) |
| `TZ` | `Asia/Jakarta` | Timezone VPS |

---

## 🤖 Cara Menjalankan Ollama di VPS

Ollama berjalan **otomatis** saat container start.

### Alur Startup Otomatis

```
Container start
     ↓
SSH + Nginx + Ollama aktif
     ↓
☁️ Cloudflare Tunnel → methatech.eu.org
     ↓
📲 "VPS ONLINE" + domain + SSH port
     ↓
⬇️ Auto-pull smollm2 (background)
     ↓
📲 "Model AI Siap!" + URL
     ↓
🔄 Auto-update tiap Senin
```

### Pull Model Tambahan via SSH

```bash
# Ringan (Railway free tier)
ollama pull smollm2        # 270 MB — default
ollama pull tinyllama      # 637 MB
ollama pull gemma:2b       # 1.4 GB

# Recommended
ollama pull phi3           # 2.3 GB ⭐
ollama pull llama3.2       # 2.0 GB

# Coding
ollama pull deepseek-coder # 776 MB
ollama pull codellama:7b   # 3.8 GB

# Cek status
ollama list
ollama ps
```

---

## 🌐 Menggunakan via Web UI

```
https://methatech.eu.org
```

1. Pilih model dari dropdown
2. Isi System Prompt (opsional)
3. Ketik pesan → Enter
4. Respons streaming real-time

---

## 🔌 Menggunakan via API

Gunakan domain statis `methatech.eu.org`:

### Generate teks

```bash
curl -X POST https://methatech.eu.org/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smollm2",
    "prompt": "Jelaskan machine learning dalam 2 kalimat",
    "stream": false
  }'
```

### Chat dengan riwayat

```bash
curl -X POST https://methatech.eu.org/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smollm2",
    "messages": [
      {"role": "system", "content": "Kamu asisten AI yang ramah"},
      {"role": "user", "content": "Halo!"}
    ],
    "stream": false
  }'
```

### Streaming response

```bash
curl -X POST https://methatech.eu.org/api/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2","messages":[{"role":"user","content":"Cerita tentang robot"}],"stream":true}'
```

### List & info model

```bash
curl https://methatech.eu.org/api/tags
curl https://methatech.eu.org/api/show -d '{"name":"smollm2"}'
```

---

## 💻 Menggunakan via SSH Terminal

```bash
# Login (port dari notifikasi ntfy)
ssh root@bore.pub -p <PORT>

# Chat interaktif
ollama run smollm2
ollama run phi3

# Multi-line prompt
ollama run phi3 <<'EOF'
Buatkan REST API Python Flask dengan endpoint:
- GET /users → list user
- POST /users → buat user baru
EOF

# Pipeline
cat kode.py | ollama run codellama "Review dan temukan bug:"
```

---

## 🔗 Integrasi Kode

### Python (requests)

```python
import requests

BASE_URL = "https://methatech.eu.org/api"  # domain statis!

def chat(message, model="smollm2", system=""):
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": message})
    r = requests.post(f"{BASE_URL}/chat", json={
        "model": model, "messages": messages, "stream": False
    })
    return r.json()["message"]["content"]

print(chat("Apa itu Ollama?"))
print(chat("Fix bug ini", model="deepseek-coder", system="Kamu expert Python"))
```

### Python + OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://methatech.eu.org/api",
    api_key="ollama"
)

response = client.chat.completions.create(
    model="smollm2",
    messages=[{"role": "user", "content": "Halo!"}]
)
print(response.choices[0].message.content)
```

### Node.js

```javascript
const BASE_URL = "https://methatech.eu.org/api";

async function chat(message, model = "smollm2") {
  const res = await fetch(`${BASE_URL}/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model, messages: [{ role: "user", content: message }], stream: false,
    }),
  });
  return (await res.json()).message.content;
}

chat("Apa itu neural network?").then(console.log);
```

---

## 📊 Model Gratis yang Tersedia

| Model | Ukuran | RAM | Kecepatan | Kualitas | Terbaik untuk |
|-------|--------|-----|-----------|----------|---------------|
| `smollm2` ⭐ | 270 MB | ~400MB | ⚡⚡⚡ | ⭐⭐ | Default, ringan |
| `tinyllama` | 637 MB | ~800MB | ⚡⚡⚡ | ⭐⭐ | Chat ringan |
| `gemma:2b` | 1.4 GB | ~2GB | ⚡⚡ | ⭐⭐⭐ | General |
| `phi3` ⭐ | 2.3 GB | ~3GB | ⚡⚡ | ⭐⭐⭐⭐ | **Recommended** |
| `llama3.2` | 2.0 GB | ~3GB | ⚡⚡ | ⭐⭐⭐⭐ | Chat |
| `deepseek-coder` | 776 MB | ~1GB | ⚡⚡⚡ | ⭐⭐⭐⭐ | Coding |
| `mistral` | 4.1 GB | ~5GB | ⚡ | ⭐⭐⭐⭐⭐ | Butuh RAM besar |

---

## 🔄 Auto-Update Mingguan

Setiap **Senin 00:00 WIB** — GitHub Actions trigger Railway redeploy otomatis → model update ke versi terbaru → notifikasi ntfy.

Trigger manual: GitHub → **Actions** → **Weekly Ollama Update** → **Run workflow**

---

## 📲 Notifikasi ntfy

| Notifikasi | Kapan |
|-----------|-------|
| 🚀 Booting | Container start |
| ☁️ Domain Aktif! | Cloudflare Tunnel terhubung |
| ✅ VPS ONLINE | SSH + domain siap |
| ⬇️ Mengunduh Model | Auto-pull mulai |
| ✅ Model AI Siap! | Pull selesai |
| 🔄 Auto-Update | Update mingguan |
| 📊 Status 5-menit | RAM, CPU, CF status |
| 🔑 SSH Login | Ada yang login |
| 🚨 Service MATI | Crash alert |
| ✅ Deploy OK | GitHub Actions berhasil |

---

## 🛠️ Troubleshooting

### ❓ `methatech.eu.org` tidak bisa diakses?

```bash
# Cek cloudflared jalan
pgrep cloudflared && echo "OK" || echo "MATI"
cat /tmp/cloudflared.log | tail -20

# Pastikan CLOUDFLARE_TUNNEL_TOKEN sudah diset di Railway Variables
# Pastikan routing domain sudah dikonfigurasi di Zero Trust → Tunnels → Public Hostname
```

### ❓ Cloudflare Tunnel error "token invalid"?

1. Buat ulang tunnel di Zero Trust → **Delete** tunnel lama → **Create new**
2. Salin token baru → update `CLOUDFLARE_TUNNEL_TOKEN` di Railway
3. Redeploy

### ❓ Model lambat / tidak respond?

```bash
free -h                    # cek RAM
ollama stop nama-model     # bebaskan RAM
ollama pull smollm2        # pakai model terkecil
```

### ❓ Port SSH berubah setiap restart?

Normal — bore port dinamis. Domain `methatech.eu.org` (port 80/443) **tidak berubah** karena pakai Cloudflare Tunnel. Hanya SSH yang perlu cek notifikasi ntfy.

---

## 🏗️ Struktur Proyek

```
rairu-kun/                      # Branch: Devculture
├── Dockerfile                  # Ubuntu 20.04 + Nginx + Ollama + cloudflared + bore
├── entrypoint.sh               # Startup: SSH, Nginx, Ollama, CF Tunnel, auto-pull
├── nginx-ollama.conf           # Nginx proxy /api/ → Ollama + UI di /
├── notify-ssh-login.sh         # Notif ntfy saat SSH login
├── railway.toml                # Config Railway deploy
├── ollama-ui/index.html        # Web UI chat (streaming, model picker)
└── .github/workflows/
    ├── railway-deploy.yml      # Auto-deploy saat push ke Devculture
    └── weekly-update.yml       # Auto-update model tiap Senin
```

---

<div align="center">

**Dibuat dengan ❤️ oleh [devculture67](https://github.com/devculture67)**

*Domain statis · AI gratis · Tanpa API key · Tanpa limit*

⭐ **Star repo ini jika membantu!** ⭐

</div>
