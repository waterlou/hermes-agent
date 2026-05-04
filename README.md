# hermes-agent

Docker image setup for a custom Hermes Agent environment based on `nousresearch/hermes-agent`.

## Included tools

### System packages

| Package | Via |
|---|---|
| `ca-certificates`, `curl`, `ffmpeg`, `gh`, `gnupg`, `htop`, `jq`, `libasound2`, `libgtk-3-0`, `libx11-xcb1`, `nodejs`, `npm`, `pandoc`, `python3`, `python3-pip`, `ripgrep`, `tmux`, `unzip`, `wget` | apt / apk |
| `google-cloud-cli` (`gcloud`) | apt (Google Cloud SDK repo) |

### npm global packages

| Package | Version | CLI command |
|---|---|---|
| `playwright` | `1.59.1` | |
| `tldr` | `3.5.0` | `tldr` |
| `@bitwarden/cli` | `2026.4.1` | `bw` |
| `@jackwener/opencli` | `1.7.11` | `opencli` |
| `@googleworkspace/cli` | `0.22.5` | `gws` |

### Playwright browsers

Installed via `playwright install`: `chromium`, `firefox`, `webkit`

### pip packages

| Package | Version |
|---|---|
| `camoufox[geoip]` | `0.4.11` |
| `yt-dlp` | `2026.3.17` |
| `docling` | `2.92.0` |

### Other

- OpenCLI browser extension (latest from GitHub releases) extracted to `/opt/opencli/extension`
- Convenience symlinks: `rg` → `rp`, `yt-dlp` → `yt-ylp`

## Build locally

```bash
docker build -t hermes-agent-custom .
```

## Run

```bash
docker run --rm -it hermes-agent-custom
```

Entrypoint: `tini -g -- /opt/hermes/docker/entrypoint.sh`

## Launch Chromium with OpenCLI extension

```bash
docker run --rm hermes-agent-custom sh -lc '
CHROME_BIN="$(command -v chromium || command -v chromium-browser)" &&
"$CHROME_BIN" --headless=new --no-sandbox --disable-gpu \
  --disable-extensions-except=/opt/opencli/extension \
  --load-extension=/opt/opencli/extension about:blank
'
```

## CI/CD

GitHub Actions workflow:

- Builds on push/pull request/manual trigger
- Rebuilds daily to pick up base image updates
- Publishes image to GitHub Container Registry (`ghcr.io/<owner>/<repo>`)
- Runs a smoke test to verify `opencli` is available in the built image
