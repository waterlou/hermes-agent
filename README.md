# hermes-agent

Docker image setup for a custom Hermes Agent environment based on `nousresearch/hermes-agent`.

## Included tools

- GitHub CLI (`gh`)
- Common CLI tools: `rg`/`rp`, `jq`, `curl`, `wget`, `yt-dlp`/`yt-ylp`, `tldr`, `htop`, `ffmpeg`, `pandoc`
- Playwright with browser binaries (`chromium`, `firefox`, `webkit`)
- Camoufox browser (installed via `camoufox fetch`)
- OpenCLI (`@jackwener/opencli`)
- Google Workspace CLI (`@googleworkspace/cli`, command: `gws`)
- OpenCLI browser extension extracted to `/opt/opencli/extension`

## Build locally

```bash
docker build -t hermes-agent-custom .
```

## Run

```bash
docker run --rm -it hermes-agent-custom
```

The image keeps the same entrypoint as the base image:
`/opt/hermes/docker/entrypoint.sh`

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
