<div align="center">

# 🤖 Devculture — Free Ollama VPS

**Jalankan AI lokal gratis dengan kualitas premium**

*Ubuntu 20.04 · Docker · Railway · Nginx · ntfy Notifications · Auto-Pull & Auto-Update*

---

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04-E95420?logo=ubuntu&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)
![Ollama](https://img.shields.io/badge/Ollama-Latest-000000?logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-Proxy-009639?logo=nginx&logoColor=white)
![Branch](https://img.shields.io/badge/Branch-Devculture-blue?logo=git)
![License](https://img.shields.io/badge/License-MIT-green)

</div>

---

## ✨ Fitur Unggulan

| Fitur | Keterangan |
|-------|-----------|
| 🤖 **Auto-Pull Model** | Download model AI otomatis saat startup |
| 🔄 **Auto-Update Mingguan** | Model selalu versi terbaru via GitHub Actions |
| 🌐 **Nginx + Web UI** | Chat interface di browser via `/` |
| 🔑 **SSH Access** | Terminal penuh via bore tunnel |
| 📲 **ntfy Notifikasi** | Alert real-time: startup, model ready, login SSH |
| 🐳 **Multi-Port** | 22, 80, 443, 3000, 8080, 8888, 11434 |
| 🆓 **100% Gratis** | Railway $5 credit/bulan, model open-source |

---

## 📋 Daftar Isi

- [Deploy Gratis di Railway](#-deploy-gratis-di-railway)
- [Konfigurasi Environment](#️-konfigurasi-environment)
- [Cara Menjalankan Ollama di VPS](#-cara-menjalankan-ollama-di-vps)
- [Menggunakan via Web UI](#-menggunakan-via-web-ui)
- [Menggunakan via API](#-menggunakan-via-api)
- [Menggunakan via SSH Terminal](#-menggunakan-via-ssh-terminal)
- [Integrasi Kode Python / Node.js](#-integrasi-kode)
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
2. Pilih **Deploy from GitHub repo**
3. Pilih repo fork Anda: `username/rairu-kun`
4. Klik **Deploy Now**

### 3 — Set Environment Variables

Di Railway dashboard → **Variables**, tambahkan:

```env
NTFY_TOPIC=nama-unik-anda        # Ganti dengan nama unik!
ROOT_PASS=password-ssh-anda
AUTO_PULL_MODEL=smollm2          # Model yang otomatis di-pull saat start
TZ=Asia/Jakarta
```

### 4 — Subscribe ntfy di HP

Install aplikasi **ntfy** → subscribe ke:
```
ntfy.sh/nama-unik-anda
```

Setelah build selesai (~10-15 menit), Anda dapat notifikasi berisi SSH command + URL Web UI! 🎉

---

## ⚙️ Konfigurasi Environment

| Variable | Default | Keterangan |
|----------|---------|-----------|
| `NTFY_TOPIC` | `rairu-devculture67` | Topic ntfy (buat unik!) |
| `ROOT_PASS` | `craxid` | Password SSH root |
| `AUTO_PULL_MODEL` | `smollm2` | Model yang auto-pull saat startup |
| `BORE_SERVER` | `bore.pub` | Server tunnel publik |
| `TZ` | `Asia/Jakarta` | Timezone VPS |

---

## 🤖 Cara Menjalankan Ollama di VPS

Ollama berjalan **otomatis** saat container start. Tidak perlu setup manual.

### Alur Otomatis:

```
Container start
     ↓
✅ SSH + Nginx + Ollama aktif
     ↓
📲 Notifikasi "VPS ONLINE" + SSH command
     ↓
⬇️ Auto-pull smollm2 (270MB) di background
     ↓
📲 Notifikasi "Model AI Siap!" + cara pakai
     ↓
🔄 Auto-update model tiap Minggu (GitHub Actions)
```

### Pull Model Tambahan via SSH

Login SSH → pull model sesuai kebutuhan:

```bash
# === MODEL GRATIS RINGAN (cocok Railway free) ===

ollama pull smollm2        # 270 MB — terkecil, sudah auto-pull
ollama pull tinyllama      # 637 MB — TinyLlama 1.1B
ollama pull phi3           # 2.3 GB — Microsoft Phi-3 Mini (recommended)
ollama pull gemma:2b       # 1.4 GB — Google Gemma 2B

# === MODEL MENENGAH ===

ollama pull llama3.2       # 2.0 GB — Meta Llama 3.2 3B
ollama pull mistral        # 4.1 GB — Mistral 7B
ollama pull neural-chat    # 4.1 GB — Intel Neural Chat

# === MODEL CODING ===

ollama pull codellama:7b   # 3.8 GB — Code Llama
ollama pull qwen2.5-coder  # 4.7 GB — Qwen Coder
ollama pull deepseek-coder # 776 MB — DeepSeek Coder 1.3B

# === CEK STATUS ===

ollama list                # Tampilkan semua model yang sudah di-pull
ollama ps                  # Model yang sedang berjalan
```

---

## 🌐 Menggunakan via Web UI

Setelah VPS online, buka di browser:

```
http://bore.pub:<PORT_HTTP>
```

> Port HTTP ada di notifikasi ntfy saat VPS online.

**Cara pakai Web UI:**

1. Pilih model dari dropdown (otomatis detect dari Ollama)
2. Isi System Prompt jika perlu (opsional)
3. Ketik pesan → Enter untuk kirim
4. Respons muncul streaming real-time

---

## 🔌 Menggunakan via API

Semua request lewat Nginx proxy di port 80:

### Generate teks

```bash
curl -X POST http://bore.pub:<PORT>/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smollm2",
    "prompt": "Jelaskan machine learning dalam 2 kalimat",
    "stream": false
  }'
```

### Chat dengan riwayat

```bash
curl -X POST http://bore.pub:<PORT>/api/chat \
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
curl -X POST http://bore.pub:<PORT>/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smollm2",
    "messages": [{"role": "user", "content": "Cerita pendek tentang robot"}],
    "stream": true
  }'
```

### List model

```bash
curl http://bore.pub:<PORT>/api/tags
```

### Info model

```bash
curl http://bore.pub:<PORT>/api/show \
  -d '{"name": "smollm2"}'
```

---

## 💻 Menggunakan via SSH Terminal

```bash
# Login SSH (cek port di ntfy)
ssh root@bore.pub -p <PORT>

# Chat interaktif
ollama run smollm2

# Chat dengan system prompt
ollama run smollm2 "Kamu adalah asisten coding. Bantu saya debug Python"

# Multi-line prompt
ollama run phi3 <<'EOF'
Buatkan REST API endpoint Python Flask untuk:
- GET /users → list semua user
- POST /users → buat user baru
EOF

# Pipeline dengan file
cat kode.py | ollama run codellama "Review kode ini dan temukan bug:"

# Simpan output ke file
ollama run llama3.2 "Buat artikel tentang AI" > artikel.md

# Jalankan di background (screen)
screen -S ollama
ollama run mistral
# Ctrl+A, D untuk detach
```

---

## 🔗 Integrasi Kode

### Python (requests)

```python
import requests

BASE_URL = "http://bore.pub:<PORT>/api"

def chat(message, model="smollm2", system=""):
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": message})
    
    r = requests.post(f"{BASE_URL}/chat", json={
        "model": model,
        "messages": messages,
        "stream": False
    })
    return r.json()["message"]["content"]

# Contoh penggunaan
print(chat("Apa itu neural network?"))
print(chat("Fix bug ini", model="deepseek-coder", system="Kamu expert Python"))
```

### Python streaming

```python
import requests, json

def chat_stream(message, model="smollm2"):
    r = requests.post("http://bore.pub:<PORT>/api/chat",
        json={"model": model, "messages": [{"role":"user","content":message}], "stream": True},
        stream=True
    )
    for line in r.iter_lines():
        if line:
            data = json.loads(line)
            print(data["message"]["content"], end="", flush=True)
            if data.get("done"):
                break
    print()

chat_stream("Cerita tentang AI")
```

### Python + OpenAI SDK (drop-in replacement)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://bore.pub:<PORT>/api",
    api_key="ollama"  # tidak perlu key asli!
)

# Gunakan persis seperti OpenAI API
response = client.chat.completions.create(
    model="smollm2",
    messages=[
        {"role": "system", "content": "Kamu asisten yang helpful"},
        {"role": "user", "content": "Halo, siapa kamu?"}
    ]
)
print(response.choices[0].message.content)
```

### Node.js / JavaScript

```javascript
const BASE_URL = "http://bore.pub:<PORT>/api";

async function chat(message, model = "smollm2") {
  const res = await fetch(`${BASE_URL}/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: message }],
      stream: false,
    }),
  });
  const data = await res.json();
  return data.message.content;
}

// Async streaming
async function chatStream(message, model = "smollm2", onChunk) {
  const res = await fetch(`${BASE_URL}/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model, messages: [{ role: "user", content: message }], stream: true,
    }),
  });
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    for (const line of decoder.decode(value).split("\n").filter(Boolean)) {
      const data = JSON.parse(line);
      onChunk(data.message?.content || "");
    }
  }
}

// Contoh
chat("Apa itu Ollama?").then(console.log);
```

---

## 📊 Model Gratis yang Tersedia

### Rekomendasi untuk Railway Free Tier

| Model | Ukuran | RAM | Kecepatan | Kualitas | Terbaik untuk |
|-------|--------|-----|-----------|----------|---------------|
| `smollm2` ⭐ | 270 MB | ~400MB | ⚡⚡⚡ | ⭐⭐ | Testing, demo |
| `tinyllama` | 637 MB | ~800MB | ⚡⚡⚡ | ⭐⭐ | Chat ringan |
| `gemma:2b` | 1.4 GB | ~2GB | ⚡⚡ | ⭐⭐⭐ | General purpose |
| `phi3` ⭐ | 2.3 GB | ~3GB | ⚡⚡ | ⭐⭐⭐⭐ | **Recommended** |
| `llama3.2` | 2.0 GB | ~3GB | ⚡⚡ | ⭐⭐⭐⭐ | Chat berkualitas |
| `deepseek-coder` | 776 MB | ~1GB | ⚡⚡⚡ | ⭐⭐⭐⭐ | Coding |
| `mistral` | 4.1 GB | ~5GB | ⚡ | ⭐⭐⭐⭐⭐ | Butuh RAM lebih |

> **💡 Ganti model default** lewat Railway Variables: `AUTO_PULL_MODEL=phi3`

---

## 🔄 Auto-Update Mingguan

GitHub Actions otomatis trigger redeploy Railway setiap **Senin 00:00 WIB**.
Saat redeploy, container fresh → `ollama pull` otomatis update model ke versi terbaru.

**Cara kerja:**
```
Setiap Senin 00:00
       ↓
GitHub Actions: trigger Railway redeploy
       ↓
Container restart dengan image terbaru
       ↓
ollama pull (update model ke versi terbaru)
       ↓
📲 ntfy: "Model AI Siap!" (versi terbaru)
```

Anda juga bisa trigger manual di tab **Actions** → **Weekly Update** → **Run workflow**.

---

## 📲 Notifikasi ntfy

Subscribe di HP: `https://ntfy.sh/<NTFY_TOPIC>`

| Notifikasi | Kapan |
|-----------|-------|
| 🚀 VPS Booting | Container start |
| ✅ VPS ONLINE | SSH port + URL siap |
| ⬇️ Mengunduh Model | Auto-pull mulai |
| ✅ Model AI Siap! | Pull selesai, cara pakai |
| 🔄 Auto-Update | Update mingguan selesai |
| 📊 Status 5-menit | RAM, CPU, Disk, Uptime |
| 🔑 SSH Login | Ada yang login (IP tercatat) |
| 🚨 Service MATI | SSH/Nginx/Ollama crash |
| ✅ Deploy Berhasil | GitHub Actions deploy OK |
| ❌ Deploy Gagal | GitHub Actions deploy error |

---

## 🛠️ Troubleshooting

### ❓ Model lambat / tidak respond?

```bash
# SSH ke VPS, cek RAM
free -h

# Gunakan model lebih kecil
ollama pull smollm2  # 270MB, paling ringan

# Stop model yang sedang jalan untuk bebaskan RAM
ollama stop nama-model
```

### ❓ Ollama tidak bisa diakses dari browser?

```bash
# Cek nginx jalan
pgrep nginx && echo "nginx OK" || nginx

# Cek ollama jalan
pgrep ollama && echo "ollama OK" || ollama serve &

# Test API lokal
curl http://localhost:11434/api/tags
```

### ❓ Port HTTP berubah setiap restart?

Normal — bore menggunakan port dinamis. Selalu cek **notifikasi ntfy terbaru** untuk port aktif.

### ❓ Model terhapus setelah restart?

Railway tidak punya persistent storage by default. Model otomatis **di-pull ulang** setiap restart via `AUTO_PULL_MODEL`. Untuk model permanen, tambahkan Railway Volume di `/root/.ollama`.

### ❓ Railway kehabisan $5 credit?

Model `smollm2` (270MB) + VPS minimal bisa jalan ~**500+ jam/bulan** dalam $5 credit. Jika melebihi, upgrade Railway atau gunakan Render.com sebagai alternatif gratis.

---

## 🏗️ Struktur Proyek

```
rairu-kun/                          # Branch: Devculture
├── Dockerfile                      # Ubuntu 20.04 + Nginx + Ollama + Bore
├── entrypoint.sh                   # Startup: SSH, Nginx, Ollama, auto-pull
├── nginx-ollama.conf               # Nginx proxy /api/ → Ollama + UI di /
├── notify-ssh-login.sh             # Notif ntfy saat SSH login
├── railway.toml                    # Config Railway deploy
├── ollama-ui/
│   └── index.html                  # Web UI chat (streaming, model picker)
├── .github/
│   └── workflows/
│       ├── railway-deploy.yml      # Auto-deploy saat push ke Devculture
│       └── weekly-update.yml      # Auto-update model tiap Senin
├── fly.toml                        # Config Fly.io (opsional)
└── render.yaml                     # Config Render.com (opsional)
```

---

<div align="center">

**Dibuat dengan ❤️ oleh [devculture67](https://github.com/devculture67)**

*AI lokal gratis — tanpa API key, tanpa limit, tanpa bayar!*

⭐ **Star repo ini jika membantu!** ⭐

</div>
