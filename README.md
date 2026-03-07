# dockerized-signal-desktop

Build Signal Desktop for Linux inside a clean Docker environment.

The build runs entirely in a container, and only the finished artifacts are exported to your host system.

## Features

- Debian 13 (Trixie) / Node 22 based build environment
- Uses pnpm via Corepack with a pinned version for reproducibility
- Supports multiple Linux targets via the `LINUX_TARGETS` build argument
- Uses `electron-builder` from the repo when available, with a pinned fallback version
- Uses Docker BuildKit cache mounts for:
  - pnpm store
  - electron-builder downloads
- Includes a helper build script (`build_signal-desktop.sh`) that:
  - finds the latest Signal Desktop release automatically
  - builds with Docker BuildKit / buildx
  - exports the resulting artifacts directly to `./out`
  - optionally persists BuildKit cache on the host

## Requirements

- Docker installed and accessible by your user
- Docker Buildx available
- Internet access for fetching source code and build dependencies

## Quick Start (wrapper script)

The included build script automates the whole process.

Default build (latest stable tag, AppImage target):

```bash
./build_signal-desktop.sh
```

Build specific targets:

```bash
LINUX_TARGETS="appImage deb rpm" ./build_signal-desktop.sh
```

Build a specific ref:

```bash
./build_signal-desktop.sh v7.75.1
```

Use persistent local BuildKit cache:

```bash
NO_CACHE=0 PERSIST_CACHE=1 ./build_signal-desktop.sh
```

Build for a specific platform:

```bash
PLATFORM=linux/amd64 ./build_signal-desktop.sh
```

The script:

- determines the latest Signal release automatically if no ref is given
- creates or reuses a dedicated buildx builder
- builds the `exporter` stage from the Dockerfile
- exports artifacts directly to `./out` via `--output type=local`
- can persist BuildKit cache in `.buildx-cache`

## Quick Start (manual buildx commands)

Build and export artifacts directly to `./out`:

```bash
docker buildx build \
  --pull \
  --target exporter \
  --build-arg SIGNAL_REF=v7.75.1 \
  --build-arg LINUX_TARGETS="appImage" \
  --output type=local,dest=./out \
  .
```

List exported artifacts:

```bash
ls -lh ./out
```

## Configuration

You can override these environment variables when using the wrapper script:

- `OUT_DIR` — destination directory for exported artifacts
- `DOCKERFILE` — alternate Dockerfile path
- `NO_CACHE` — set to `0` to allow cache reuse
- `PROGRESS` — build output mode (`auto`, `plain`)
- `PERSIST_CACHE` — set to `1` to persist BuildKit cache on disk
- `CACHE_DIR` — host directory for persisted BuildKit cache
- `PLATFORM` — optional platform override for buildx, for example `linux/amd64`
- `LINUX_TARGETS` — Linux targets passed to `electron-builder`  
  Example: `appImage`, or `appImage deb rpm`
- `PNPM_VERSION` — pnpm version prepared via Corepack
- `ARTIFACT_UID` / `ARTIFACT_GID` — ownership of exported files on the host

Build-specific Docker args include:

- `SIGNAL_REF` — Git tag, branch, or commit to build
- `SIGNAL_REPO` — alternate repository URL
- `ELECTRON_BUILDER_VERSION` — fallback version if the repo does not provide one

## Notes

- The helper script now uses `docker buildx build --output type=local` instead of building an image, creating a temporary container, and copying files out afterward.
- The exporter stage is a minimal `scratch` image that contains only the final artifacts.
- The Dockerfile currently exports AppImage artifacts and common companions from `dist/`.

## Troubleshooting

If Docker permission errors occur:

- ensure your user is in the `docker` group
- run `newgrp docker` after changing group membership
- use `sudo` only if you really have to

If pnpm or Corepack setup fails:

- check Docker network connectivity
- try again with `NO_CACHE=1`

If buildx is unavailable or the builder fails to start:

- confirm `docker buildx version` works
- recreate the builder and rerun the script

If packaging succeeds but expected artifacts are missing:

- inspect the `dist/` contents inside the build log
- verify the requested `LINUX_TARGETS` value is supported by the current Signal Desktop release

## License and Credits

This project provides a Docker-based build environment only.

Signal Desktop and all associated source code, licenses, and trademarks belong to their respective owners.
