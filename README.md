# dockerized-signal-desktop

Build **Signal Desktop** Linux packages (AppImage/DEB/RPM) inside Docker, with pnpm managed by Corepack (or preinstalled where required). The host remains clean; only the final artifacts are copied out.

## Features

- **Node 22 (bookworm)** base image and modern toolchain.
- **pnpm via Corepack** (with safe fallback when needed).
- Supports multiple Linux targets via `LINUX_TARGETS` (e.g. `appimage`, `deb`, `rpm`, or comma-separated like `deb,rpm,appimage`).
- Uses upstream `electron-builder` with CI-safe defaults (no publishing unless you set a token).
- **One-command helper script** (`build_signal-desktop.sh`) that clones source, builds inside Docker, and copies artifacts out.

## Prerequisites

- Docker

## Quick start (Docker CLI)

~~~bash
# Build the image (latest stable tag recommended; example uses v7.69.0)
docker build --pull \
  --build-arg SIGNAL_REF=v7.69.0 \
  -t signal-desktop-builder .

# Run the builder (choose targets: appimage | deb | rpm | "deb,rpm,appimage")
# Pass GH_TOKEN=skip to silence publish checks
docker run --rm \
  -e LINUX_TARGETS="appimage" \
  -e GH_TOKEN=skip \
  --name signal-temp \
  signal-desktop-builder

# Copy artifacts to host (from container path used by Dockerfile/script)
# If your Dockerfile builds to /opt/Signal-Desktop/dist:
CID="$(docker create signal-desktop-builder)"
mkdir -p out
docker cp "$CID:/opt/Signal-Desktop/dist/." ./out/
docker rm -f "$CID" >/dev/null

ls -lh out
~~~

## Quick start (wrapper script)

Use the helper script for a single command that builds **and** copies artifacts:

~~~bash
# Build default target (AppImage) from latest stable/main and copy artifacts
./build_signal-desktop.sh

# Build specific targets and copy artifacts automatically
LINUX_TARGETS="deb,rpm" ./build_signal-desktop.sh

# Override repository/branch easily if you want to test changes:
REPO_URL="https://github.com/signalapp/Signal-Desktop.git" \
BRANCH="main" \
LINUX_TARGETS="appimage" \
./build_signal-desktop.sh
~~~

What it does:

- Clones/updates Signal Desktop (hard-reset mirror) to the requested branch.
- Builds the Docker image based on the included Dockerfile.
- Runs `electron-builder` inside the container for your `LINUX_TARGETS`.
- **Copies `dist/` out to `./out/`** on your host.
- Cleans up the ephemeral container.

## Configuration & knobs

- **Targets:** Set `LINUX_TARGETS` to any combination supported by electron-builder (`appimage`, `deb`, `rpm`).
- **Publishing:** By default we avoid publishing. If you set `GH_TOKEN` to a real token and have a draft release, electron-builder may try to publish. To silence CI checks, set `GH_TOKEN=skip` (or run with `--publish=never` in your pipeline).
- **pnpm/Corepack:** The Dockerfile enables pnpm via Corepack. If Corepack can’t symlink to `/usr/local/bin` in your environment, the file falls back to a user-local install of pnpm (so builds keep working).

## Troubleshooting

- **Corepack permission error:** If Corepack can’t enable pnpm due to permissions, the Dockerfile uses `sudo corepack enable` (when available) or falls back to a local pnpm. If you’ve removed `sudo`, run as root or preinstall pnpm.
- **GH_TOKEN warning:** If you see “artifacts will be published if draft release exists,” pass `-e GH_TOKEN=skip` to `docker run` or add `--publish=never` to the build command inside your Dockerfile.

## License & Credits

This repo only provides a Dockerized build wrapper for **Signal Desktop**. All code, licenses, and trademarks for Signal belong to their respective owners.
