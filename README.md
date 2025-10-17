dockerized-signal-desktop

Build Signal Desktop Linux packages (AppImage/DEB/RPM) inside a clean
Docker environment using pnpm via Corepack. The host system stays
untouched --- only the final artifacts are copied out.

Features

Node 22 (Debian 13 / Trixie) base image with a modern, reproducible
toolchain

pnpm via Corepack, pinned and activated safely during build

Electron Builder pinned to v24 for reproducible packaging

Supports multiple Linux targets via LINUX_TARGETS (appimage, deb, rpm,
or comma-separated combinations)

Automatic tag detection from the Signal repository using the GitHub API
or refs as fallback

Robust build script (build_signal-desktop.sh) for one-command builds,
cleanup, and artifact export

Uses Docker BuildKit for improved caching, performance, and cleaner
builds

Consistent permissions and ownership handling via umask 022 and
tar-based extraction

Prerequisites

Docker (BuildKit recommended)

Quick start (Docker CLI)

# Build the image (latest stable tag automatically detected, or specify one)

docker build --pull\
--build-arg SIGNAL_REF=v7.75.1\
-t signal-desktop-builder .

# Run the builder (choose targets: appimage \| deb \| rpm \| combinations)

docker run --rm\
-e LINUX_TARGETS="appimage"\
-e GH_TOKEN=skip\
--name signal-temp\
signal-desktop-builder

# Copy artifacts to host

CID="$(docker create signal-desktop-builder)"
mkdir -p out
docker cp "$CID:/opt/Signal-Desktop/dist/." ./out/ docker rm -f "\$CID"
\>/dev/null

ls -lh out

Quick start (build script)

The helper script provides automatic tag detection, logging, and
cleanup. It can build from any tag, branch, or ref without modifying the
Dockerfile.

# Default: build latest stable release (AppImage)

./build_signal-desktop.sh

# Build specific targets

LINUX_TARGETS="deb,rpm" ./build_signal-desktop.sh

# Build from a custom ref or branch

SIGNAL_REF="v7.75.1" LINUX_TARGETS="appimage" ./build_signal-desktop.sh

What it does

Automatically determines the latest stable release via GitHub API or git
tags

Builds the Docker image using Debian 13 (Trixie)

Runs electron-builder@24 inside the container for your selected targets

Copies /out/ to the host (default ./out)

Cleans up temporary containers and images automatically

Configuration Variable Description Default SIGNAL_REF Git ref or tag to
build latest release (auto) LINUX_TARGETS Comma-separated list of build
targets appImage PNPM_VERSION Version of pnpm to activate via Corepack
10.6.4 ELECTRON_BUILDER_VERSION Electron Builder version 24 ARTIFACT_UID
/ ARTIFACT_GID UID/GID ownership for exported files 1000 OUT_DIR
Destination directory for exported artifacts ./out NO_CACHE Disable
Docker layer cache 1 PROGRESS Docker build output format auto
Troubleshooting

Permission denied during export: fixed by the export mechanism --- files
are copied using tar with normalized ownership.

Corepack issues: the build uses corepack enable as root. In restricted
environments, ensure /usr/local/bin is writable.

Tag detection fails: the script falls back to git refs if the GitHub API
is unavailable.

Build stuck or slow: ensure BuildKit is enabled (export
DOCKER_BUILDKIT=1).

License & Credits

This repository provides a Dockerized build environment for Signal
Desktop. All code, trademarks, and licenses for Signal belong to their
respective owners.
