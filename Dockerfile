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

ENTRYPOINT ["/opt/hermes/docker/entrypoint.sh"]
