FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    NTFY_TOPIC=rairu-devculture67 \
    BORE_SERVER=bore.pub \
    ROOT_PASS=craxid \
    TZ=Asia/Jakarta \
    OLLAMA_HOST=0.0.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates openssh-server curl python3 \
        vim nano sudo net-tools wget htop git unzip \
        iproute2 iputils-ping procps passwd tmux screen \
        lsof dnsutils jq tzdata \
        nginx && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install bore v0.5.0
RUN curl -fsSL "https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/bore.tar.gz && \
    tar -xzf /tmp/bore.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/bore && \
    rm /tmp/bore.tar.gz

# Install cloudflared (Cloudflare Tunnel — domain statis gratis)
RUN curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
        -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Configure SSH
RUN mkdir -p /run/sshd && \
    echo "root:craxid" | chpasswd && \
    ssh-keygen -A && \
    sed -i \
      -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
      -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' \
      -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
      -e 's/PasswordAuthentication no/PasswordAuthentication yes/' \
      -e 's/#ClientAliveInterval.*/ClientAliveInterval 60/' \
      -e 's/#ClientAliveCountMax.*/ClientAliveCountMax 10/' \
      -e 's/#MaxSessions.*/MaxSessions 20/' \
      -e 's/#TCPKeepAlive.*/TCPKeepAlive yes/' \
      /etc/ssh/sshd_config && \
    printf "==============================================\n  Ubuntu 20.04 VPS — Devculture\n  Domain  : methatech.eu.org\n  Notifikasi aktif via ntfy.sh\n==============================================\n" > /etc/ssh/banner.txt && \
    echo "Banner /etc/ssh/banner.txt" >> /etc/ssh/sshd_config

# Configure nginx for Ollama proxy
RUN rm -f /etc/nginx/sites-enabled/default
COPY nginx-ollama.conf /etc/nginx/sites-available/ollama
RUN ln -s /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/ollama

# Ollama Web UI
COPY ollama-ui /var/www/ollama-ui
RUN chmod -R 755 /var/www/ollama-ui

# SSH login notification
COPY notify-ssh-login.sh /etc/profile.d/notify-ssh-login.sh
RUN chmod +x /etc/profile.d/notify-ssh-login.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Multi-port expose
EXPOSE 22 80 443 3000 8080 8888 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD pgrep nginx > /dev/null || exit 1

CMD ["/entrypoint.sh"]
