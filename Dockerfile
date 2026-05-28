FROM nousresearch/hermes-agent:latest

# System packages
RUN set -eu; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      if apt-cache show libasound2t64 >/dev/null 2>&1; then \
        ALSA_PKG="libasound2t64"; \
      else \
        ALSA_PKG="libasound2"; \
      fi; \
      apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ffmpeg \
        gh \
        gnupg \
        htop \
        jq \
        netcat-openbsd \
        "${ALSA_PKG}" \
        libgtk-3-0 \
        libx11-xcb1 \
        nodejs \
        npm \
        pandoc \
        python3 \
        python3-pip \
        ripgrep \
        tmux \
        unzip \
        wget; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache \
        alsa-lib \
        ca-certificates \
        curl \
        ffmpeg \
        github-cli \
        gtk+3.0 \
        htop \
        jq \
        netcat-openbsd \
        libx11 \
        nodejs \
        npm \
        pandoc \
        py3-pip \
        python3 \
        ripgrep \
        tmux \
        unzip \
        wget; \
    else \
      echo "No supported package manager found to install dependencies"; \
      exit 1; \
    fi

# Google Cloud SDK
RUN set -eu; \
    if command -v apt-get >/dev/null 2>&1; then \
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg; \
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list; \
      apt-get update; \
      apt-get install -y --no-install-recommends google-cloud-cli; \
      rm -rf /var/lib/apt/lists/*; \
    fi

# npm global packages
RUN set -eu; \
    npm install -g playwright@1.59.1 tldr@3.5.0 @bitwarden/cli@2026.4.1 @jackwener/opencli@1.7.11 @googleworkspace/cli@0.22.5

# Playwright browsers
RUN set -eu; \
    if command -v apt-get >/dev/null 2>&1; then \
      playwright install --with-deps chromium firefox webkit; \
    else \
      playwright install chromium firefox webkit; \
    fi

# pip packages and camoufox (use system python, not the base image's venv)
RUN set -eu; \
    /usr/bin/python3 -m pip install --no-cache-dir --break-system-packages -U "camoufox[geoip]==0.4.11" "yt-dlp==2026.3.17" "docling==2.92.0" || \
      /usr/bin/python3 -m pip install --no-cache-dir -U "camoufox[geoip]==0.4.11" "yt-dlp==2026.3.17" "docling==2.92.0"; \
    /usr/bin/python3 -m camoufox fetch

# Convenience symlinks and opencli extension
RUN set -eu; \
    if command -v rg >/dev/null 2>&1 && ! command -v rp >/dev/null 2>&1; then \
      ln -s "$(command -v rg)" /usr/local/bin/rp; \
    fi; \
    if command -v yt-dlp >/dev/null 2>&1 && ! command -v yt-ylp >/dev/null 2>&1; then \
      ln -s "$(command -v yt-dlp)" /usr/local/bin/yt-ylp; \
    fi; \
    mkdir -p /opt/opencli/extension; \
    EXT_URL="$(curl -fsSL https://api.github.com/repos/jackwener/opencli/releases/latest | jq -r '.assets[]? | select(.name | test("opencli-extension.*\\.zip$")) | .browser_download_url' | head -n1)"; \
    test -n "${EXT_URL}"; \
    curl -fsSL "${EXT_URL}" -o /tmp/opencli-extension.zip; \
    unzip -q /tmp/opencli-extension.zip -d /opt/opencli/extension; \
    rm -f /tmp/opencli-extension.zip

# tdl (Telegram downloader)
RUN set -eu; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
      x86_64) TDL_ARCH="64bit" ;; \
      aarch64) TDL_ARCH="arm64" ;; \
      *) echo "Unsupported architecture for tdl: ${ARCH}"; exit 1 ;; \
    esac; \
    TDL_VER="$(curl -fsSL https://api.github.com/repos/iyear/tdl/releases/latest | jq -r '.tag_name')"; \
    test -n "${TDL_VER}"; \
    curl -fsSL "https://github.com/iyear/tdl/releases/download/${TDL_VER}/tdl_Linux_${TDL_ARCH}.tar.gz" -o /tmp/tdl.tar.gz; \
    tar -xzf /tmp/tdl.tar.gz -C /usr/local/bin; \
    rm -f /tmp/tdl.tar.gz

# Install hermes-webui (clone then archive to exclude .git)
RUN set -eu; \
    git clone --depth 1 --branch master \
      https://github.com/nesquena/hermes-webui.git /tmp/hermes-webui-clone; \
    git -C /tmp/hermes-webui-clone archive --format=tar --output=/tmp/hermes-webui.tar HEAD; \
    mkdir -p /opt/hermes-webui; \
    tar -xf /tmp/hermes-webui.tar -C /opt/hermes-webui; \
    rm -rf /tmp/hermes-webui-clone /tmp/hermes-webui.tar; \
    /usr/bin/python3 -m pip install --no-cache-dir --break-system-packages -r /opt/hermes-webui/requirements.txt || \
      /usr/bin/python3 -m pip install --no-cache-dir -r /opt/hermes-webui/requirements.txt

# Environment for webui
ENV HERMES_WEBUI_AGENT_DIR=/opt/hermes \
    HERMES_WEBUI_HOST=0.0.0.0 \
    HERMES_WEBUI_PORT=8787 \
    HERMES_WEBUI_STATE_DIR=/opt/data/webui

EXPOSE 8787

# Patch entrypoint: start webui after privilege drop to hermes, before gateway
RUN cp /opt/hermes/docker/entrypoint.sh /opt/hermes/docker/entrypoint-webui.sh && \
    sed -i '/^# Final exec:/i \
# Start hermes-webui (spawns server in background, then returns)\
python3 /opt/hermes-webui/bootstrap.py --no-browser' /opt/hermes/docker/entrypoint-webui.sh

ENTRYPOINT [ "/usr/bin/tini", "-g", "--", "/opt/hermes/docker/entrypoint-webui.sh" ]
