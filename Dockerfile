FROM nousresearch/hermes-agent:latest

RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends gh ca-certificates; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache github-cli ca-certificates; \
    else \
      echo "No supported package manager found to install GitHub CLI"; \
      exit 1; \
    fi

RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends nodejs npm; \
      npm install -g playwright; \
      playwright install --with-deps chromium firefox webkit; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache nodejs npm; \
      npm install -g playwright; \
      playwright install chromium firefox webkit; \
    else \
      echo "No supported package manager found to install Playwright"; \
      exit 1; \
    fi

RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends python3 python3-pip libgtk-3-0 libx11-xcb1 libasound2 || \
      apt-get install -y --no-install-recommends python3 python3-pip libgtk-3-0 libx11-xcb1 libasound2t64; \
      python3 -m pip install --no-cache-dir --break-system-packages -U "camoufox[geoip]"; \
      python3 -m camoufox fetch; \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
      apk add --no-cache python3 py3-pip gtk+3.0 libx11 alsa-lib; \
      python3 -m pip install --no-cache-dir -U "camoufox[geoip]"; \
      python3 -m camoufox fetch; \
    else \
      echo "No supported package manager found to install Camoufox"; \
      exit 1; \
    fi

ENTRYPOINT ["/opt/hermes/docker/entrypoint.sh"]
