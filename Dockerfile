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

FROM node:22-trixie AS builder
SHELL ["/bin/bash","-o","pipefail","-lc"]
ARG DEBIAN_FRONTEND=noninteractive

# ---- tweakables ----
ARG SIGNAL_REPO=https://github.com/signalapp/Signal-Desktop.git
ARG SIGNAL_REF=main
ARG LINUX_TARGETS=AppImage
ARG PNPM_VERSION=10.6.4
ARG ELECTRON_BUILDER_VERSION=24.13.3
ARG UID=1000
ARG GID=1000

# Helpful non-interactive defaults
ENV CI=1 \
    HUSKY=0 \
    NODE_OPTIONS=--max_old_space_size=4096 \
    npm_config_fund=false \
    npm_config_audit=false \
    npm_config_update_notifier=false \
    COREPACK_ENABLE_AUTO_PIN=0 \
    USE_HARD_LINKS=false

# System dependencies for build + packaging
RUN set -euo pipefail; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    git git-lfs curl wget gnupg build-essential python3 python3-pip \
    libx11-dev libxkbfile-dev libsecret-1-dev \
    libgtk-3-dev libnss3 libasound2 libxss1 libxtst6 libnotify4 libx11-xcb1 \
    libgbm-dev squashfs-tools xz-utils rpm zsync; \
    rm -rf /var/lib/apt/lists/*; \
    git lfs install --system

# Enable pnpm via Corepack (deterministic)
RUN set -euo pipefail; \
    corepack enable; \
    corepack prepare "pnpm@${PNPM_VERSION}" --activate; \
    pnpm --version

# Build as non-root (avoids root-owned node_modules and cache weirdness)
RUN set -euo pipefail; \
    groupmod -g "${GID}" node; \
    usermod  -u "${UID}" -g "${GID}" node; \
    mkdir -p /opt; \
    chown -R node:node /opt
USER node
WORKDIR /opt

# Clone pinned ref
RUN set -euo pipefail; \
    git clone --depth=1 --branch "${SIGNAL_REF}" "${SIGNAL_REPO}" Signal-Desktop
WORKDIR /opt/Signal-Desktop

# Install deps (fail if lockfile mismatch; remove the fallback for reproducibility)
RUN set -euo pipefail; \
    pnpm install --frozen-lockfile

# Optional pre-steps (run only if the script exists; do not mask failures)
RUN set -euo pipefail; \
    node -e 'const p=require("./package.json");process.exit(p.scripts?.build?0:1)' && pnpm run build || true
RUN set -euo pipefail; \
    node -e 'const p=require("./package.json");process.exit(p.scripts?.transpile?0:1)' && pnpm run transpile || true

# Package (prefer repo's electron-builder; if missing, use a pinned dlx fallback)
ENV SIGNAL_ENV=production \
    ELECTRON_BUILDER_CACHE=/home/node/.cache/electron-builder

RUN set -euo pipefail; \
    rm -rf dist; \
    if pnpm exec electron-builder --version >/dev/null 2>&1; then \
    ELECTRON_BUILDER_PUBLISH=never CI=false pnpm exec electron-builder --linux "${LINUX_TARGETS}" --publish=never; \
    else \
    ELECTRON_BUILDER_PUBLISH=never CI=false pnpm dlx "electron-builder@${ELECTRON_BUILDER_VERSION}" --linux "${LINUX_TARGETS}" --publish=never; \
    fi

# -------- exporter (artifacts with chosen ownership) --------
FROM debian:13-slim AS exporter
SHELL ["/bin/bash","-o","pipefail","-lc"]

ARG ARTIFACT_UID=1000
ARG ARTIFACT_GID=1000
ARG OUT_DIR=/out

RUN set -euo pipefail; \
    groupadd -g "${ARTIFACT_GID}" app; \
    useradd -l -m -u "${ARTIFACT_UID}" -g "${ARTIFACT_GID}" app
USER app
WORKDIR ${OUT_DIR}

COPY --from=builder --chown=app:app /opt/Signal-Desktop/dist/ ${OUT_DIR}/
