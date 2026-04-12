# hermes-agent

Docker image setup for a custom Hermes Agent environment based on `nousresearch/hermes-agent`.

## Included tools

- GitHub CLI (`gh`)
- Playwright with browser binaries (`chromium`, `firefox`, `webkit`)
- Camoufox browser (installed via `camoufox fetch`)

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

## CI/CD

GitHub Actions workflow:

- Builds on push/pull request/manual trigger
- Rebuilds daily to pick up base image updates
- Publishes image to GitHub Container Registry (`ghcr.io/<owner>/<repo>`)
