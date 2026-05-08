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

# pip packages and camoufox
RUN set -eu; \
    python3 -m pip install --no-cache-dir --break-system-packages -U "camoufox[geoip]==0.4.11" "yt-dlp==2026.3.17" "docling==2.92.0" || \
      python3 -m pip install --no-cache-dir -U "camoufox[geoip]==0.4.11" "yt-dlp==2026.3.17" "docling==2.92.0"; \
    python3 -m camoufox fetch

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

ENTRYPOINT [ "/usr/bin/tini", "-g", "--", "/opt/hermes/docker/entrypoint.sh" ]
