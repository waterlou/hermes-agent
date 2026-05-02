FROM nousresearch/hermes-agent:latest

RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ffmpeg \
        gh \
        gnupg \
        htop \
        jq \
        libasound2 \
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
        wget || \
      apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ffmpeg \
        gh \
        gnupg \
        htop \
        jq \
        libasound2t64 \
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
      curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg; \
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list; \
      apt-get update; \
      apt-get install -y --no-install-recommends google-cloud-cli; \
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
    fi; \
    npm install -g playwright tldr@3.4.0 @bitwarden/cli @jackwener/opencli @googleworkspace/cli; \
    if command -v apt-get >/dev/null 2>&1; then \
      playwright install --with-deps chromium firefox webkit; \
    else \
      playwright install chromium firefox webkit; \
    fi; \
    python3 -m pip install --no-cache-dir --break-system-packages -U "camoufox[geoip]" yt-dlp || \
      python3 -m pip install --no-cache-dir -U "camoufox[geoip]" yt-dlp; \
    python3 -m camoufox fetch; \
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
