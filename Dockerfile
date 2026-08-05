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

# Register hermes-webui as an s6-rc longrun service, mirroring the base
# image's dashboard service pattern (see /etc/s6-overlay/s6-rc.d/dashboard).
# s6-rc compiles this tree at boot; adding the name to the "user" bundle
# (an empty contents.d file, same as dashboard/main-hermes) auto-starts it.
# The service is therefore supervised independently of the container CMD:
# if the webui crashes, s6-supervise restarts it.
#
# --foreground is required: bootstrap.py daemonizes and exits unless told
# otherwise, which would make s6-supervise restart the slot in a tight loop
# while the orphaned server keeps port 8787 bound. --foreground implies
# --no-browser and skips the post-launch health probe (s6 handles liveness).
RUN set -eu; \
    SVC=/etc/s6-overlay/s6-rc.d/hermes-webui; \
    mkdir -p "$SVC/dependencies.d"; \
    printf 'longrun\n' > "$SVC/type"; \
    : > "$SVC/dependencies.d/base"; \
    printf '%s\n' \
      '#!/command/with-contenv sh' \
      '# shellcheck shell=sh' \
      '# hermes-webui service — mirrors the base image dashboard s6-rc pattern.' \
      '# Runs the webui server in-process (--foreground) so s6-supervise' \
      '# tracks the actual server and restarts it on crash.' \
      'export HOME=/opt/data' \
      'cd /opt/data' \
      '[ "$(id -u)" = 0 ] || exec /usr/bin/python3 /opt/hermes-webui/bootstrap.py --foreground' \
      'exec s6-setuidgid hermes /usr/bin/python3 /opt/hermes-webui/bootstrap.py --foreground' \
      > "$SVC/run"; \
    printf '%s\n' \
      '#!/command/with-contenv sh' \
      '# shellcheck shell=sh' \
      '# hermes-webui finish script. Always exit non-125 so s6-supervise' \
      '# restarts the service whenever the run script exits (crash-restart).' \
      'exit 0' \
      > "$SVC/finish"; \
    chmod +x "$SVC/run" "$SVC/finish"; \
    : > /etc/s6-overlay/s6-rc.d/user/contents.d/hermes-webui

# Restore the base image entrypoint (the dispatcher). On the PID-1 path it
# execs /init (full s6 supervision tree); on wrapped runtimes (docker run
# --init, Fly, K8s) it falls back to direct bootstrap + main-wrapper. The
# container CMD (`gateway run`, passed by compose) is unchanged.
ENTRYPOINT [ "/opt/hermes/docker/entrypoint-dispatch.sh" ]
