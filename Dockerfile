# dockerized-signal-desktop
# Copyright (C) 2025 hsld <62700359+hsld@users.noreply.github.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Contact: https://github.com/hsld/dockerized-signal-desktop/issues

FROM node:22-bookworm AS builder
SHELL ["/bin/bash","-o","pipefail","-lc"]
ARG DEBIAN_FRONTEND=noninteractive

# ---- tweakables ----
ARG SIGNAL_REPO=https://github.com/signalapp/Signal-Desktop.git
# Default can be overridden by the build script which picks the latest tag.
ARG SIGNAL_REF=main
ARG LINUX_TARGETS=appimage
ARG PNPM_VERSION=10.6.4

# Helpful non-interactive defaults
ENV CI=1 \
    npm_config_fund=false \
    npm_config_audit=false

# System dependencies for build + packaging
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs curl wget gnupg build-essential python3 python3-pip \
    libx11-dev libxkbfile-dev libsecret-1-dev \
    libgtk-3-dev libnss3 libasound2 libxss1 libxtst6 libnotify4 libx11-xcb1 \
    libgbm-dev squashfs-tools xz-utils rpm zsync \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install --system

# Enable pnpm globally via Corepack *while root* (so /usr/local/bin shims can be written)
RUN corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && pnpm --version

WORKDIR /opt

# Clone the repo at a pinned ref (the build script will inject the latest tag)
RUN git clone --depth=1 --branch "${SIGNAL_REF}" "${SIGNAL_REPO}" Signal-Desktop

WORKDIR /opt/Signal-Desktop

# Install deps (lockfile respected if present)
RUN pnpm install --frozen-lockfile || pnpm install

# Optional pre-steps (some branches use these; harmless if missing)
RUN pnpm run build || true
RUN pnpm run transpile || true

# Build packages with electron-builder (targets set via ARG)
ENV SIGNAL_ENV=production
# Explicitly disable publishing so GH_TOKEN isn't required
RUN ELECTRON_BUILDER_PUBLISH=never CI=false \
    ./node_modules/.bin/electron-builder --linux "${LINUX_TARGETS}" --publish=never

FROM debian:12-slim AS exporter
SHELL ["/bin/bash","-o","pipefail","-lc"]
ARG ARTIFACT_UID=1000
ARG ARTIFACT_GID=1000
RUN groupadd -g ${ARTIFACT_GID} app && useradd -l -m -u ${ARTIFACT_UID} -g ${ARTIFACT_GID} app
USER app
WORKDIR /out

# Copy built artifacts out of the image
COPY --from=builder --chown=app:app /opt/Signal-Desktop/dist/ /out/
