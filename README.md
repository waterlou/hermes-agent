# hermes-agent

Docker image setup for a custom Hermes Agent environment based on `nousresearch/hermes-agent`.

## Included tools

### System packages

| Package | Via |
|---|---|
| `ca-certificates`, `curl`, `ffmpeg`, `gh`, `gnupg`, `htop`, `jq`, `netcat-openbsd` (`nc`), `libasound2` (or `libasound2t64`), `libgtk-3-0`, `libx11-xcb1`, `nodejs`, `npm`, `pandoc`, `python3`, `python3-pip`, `ripgrep`, `tmux`, `unzip`, `wget` | apt / apk |
| `google-cloud-cli` (`gcloud`) | apt only (Google Cloud SDK repo) |

Package names above reflect Debian/Ubuntu. Alpine equivalents: `github-cli`, `alsa-lib`, `gtk+3.0`, `libx11`, `py3-pip`.

### npm global packages

| Package | Version | CLI command |
|---|---|---|
| `playwright` | `1.64.0` | |
| `tldr` | `3.5.0` | `tldr` |
| `@bitwarden/cli` | `2026.9.1` | `bw` |
| `@jackwener/opencli` | `1.8.8` | `opencli` |
| `@googleworkspace/cli` | `0.22.5` | `gws` |

### pip packages

| Package | Version |
|---|---|
| `camoufox[geoip]` | `0.5.6` |
| `yt-dlp` | `2026.8.19` |
| `docling` | `2.137.0` |

### Other

- `tdl` — Telegram downloader (latest from GitHub releases, binary at `/usr/local/bin/tdl`)
- OpenCLI browser extension (latest from GitHub releases) extracted to `/opt/opencli/extension`
- Convenience symlinks: `rg` → `rp`, `yt-dlp` → `yt-ylp`
- `hermes-webui` — Web UI installed to `/opt/hermes-webui`, served on port `8787`.
  Run as an `s6-rc` longrun service (see [Run](#run)) so it is supervised and
  restart-on-crash, independent of the container command.
  Defaults: `HERMES_WEBUI_AGENT_DIR=/opt/hermes`, `HERMES_WEBUI_HOST=0.0.0.0`,
  `HERMES_WEBUI_PORT=8787`, `HERMES_WEBUI_STATE_DIR=/opt/data/webui`.

## Build locally

```bash
docker build -t hermes-agent-custom .
```

## Run

```bash
docker run --rm -it hermes-agent-custom
```

Entrypoint: `/opt/hermes/docker/entrypoint-dispatch.sh` (from the base image).
On the PID-1 path it execs `/init`, giving the full s6-overlay supervision
tree; on wrapped runtimes (`docker run --init`, Fly, K8s) it falls back to a
direct bootstrap + `main-wrapper.sh`.

The web UI runs as the `hermes-webui` **s6-rc longrun service**
(`/etc/s6-overlay/s6-rc.d/hermes-webui`, added to the `user` bundle so it
auto-starts). It mirrors the base image's `dashboard` service: `s6-supervise`
owns the process and restarts it on crash. It runs `bootstrap.py --foreground`
so s6 tracks the real server instead of a daemonized orphan.

## Packaging notes

- **npm global prefix.** The base image sets npm's global prefix to a versioned
  tools dir (`/opt/hermes/tools/node-<version>-linux-<arch>`), which
  `/etc/profile` drops from PATH on login shells. Global bins installed there are
  therefore unreachable — e.g. `sh -lc 'opencli --version'` exits 127. Globals
  are installed with `NPM_CONFIG_PREFIX=/usr/local`, which is on PATH in every
  shell mode.
- **playwright CLI shadow.** The base image ships the pip `playwright` (console
  script at `/usr/local/bin/playwright`) alongside the npm one, so the Python
  CLI shadows the npm CLI at the same path. The Dockerfile re-points
  `/usr/local/bin/playwright` at the npm `cli.js`; the pip package stays
  installed for its Python library API only.
- **camoufox pin.** Held at `0.5.6`. `0.5.7+` depends on `fpgen` →
  `indexed-zstd`, which publishes no Linux aarch64 wheel (x86_64 only), so the
  arm64 image leg cannot build. Bump only once upstream ships aarch64 wheels or
  a `libzstd-dev` build path is added.

## Launch Chromium with OpenCLI extension

```bash
docker run --rm hermes-agent-custom sh -lc '
CHROME_BIN="$(find /root/.cache/ms-playwright -name chrome -type f -path "*/chrome-linux/*" | head -1)" &&
test -n "$CHROME_BIN" &&
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
- Runs a smoke test (via login shell) to verify `opencli` and `gws` are available
  in the built image — this catches PATH regressions like
  [npm global prefix](#packaging-notes)
