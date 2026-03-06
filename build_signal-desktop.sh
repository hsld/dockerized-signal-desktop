#!/usr/bin/env bash

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

# Exit immediately if any command fails
# Treat unset variables as errors
# Ensure the whole pipeline fails if any one command in it fails
set -euo pipefail

# ----------------------------- config ---------------------------------
REPO_SLUG="signalapp/Signal-Desktop"
IMAGE_BASENAME="${IMAGE_BASENAME:-signal-desktop-builder}" \
    # kept for compatibility/logging
OUT_DIR="${OUT_DIR:-out}" \
    # override: OUT_DIR=/some/path ./build_signal-desktop.sh
DOCKERFILE="${DOCKERFILE:-Dockerfile}" \
    # override if needed
NO_CACHE="${NO_CACHE:-1}" \
    # set to 0 to allow cache
PROGRESS="${PROGRESS:-auto}" \
    # auto|plain

# Optional: persist BuildKit cache across runs on this machine.
# - If NO_CACHE=1, caching is disabled regardless.
# - If NO_CACHE=0 and PERSIST_CACHE=0, BuildKit still caches *inside* the
#   buildx builder container.
# - If NO_CACHE=0 and PERSIST_CACHE=1, cache is also stored on disk
#   (CACHE_DIR) so it's resilient to pruning.
PERSIST_CACHE="${PERSIST_CACHE:-0}" # 0|1
CACHE_DIR="${CACHE_DIR:-.buildx-cache}"

# Optional: platform (usually leave empty for local artifact builds)
# Examples: linux/amd64, linux/arm64
PLATFORM="${PLATFORM:-}"

# Signal build args you can override
LINUX_TARGETS="${LINUX_TARGETS:-appImage}" # e.g. "appImage snap deb rpm"
PNPM_VERSION="${PNPM_VERSION:-10.6.4}"
ARTIFACT_UID="${ARTIFACT_UID:-1000}"
ARTIFACT_GID="${ARTIFACT_GID:-1000}"
# ----------------------------------------------------------------------

# Proivde some user comfort by telling them what we're doing
say() { printf "\033[1;36m>> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m!! %s\033[0m\n" "$*"; }
die() {
    printf "\033[1;31mXX %s\033[0m\n" "$*"
    exit 1
}

# Make sure all dependancies are satisfied
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
need docker
need curl
need git

# Ensure we have a buildx builder that supports the full BuildKit feature set.
# The docker-container driver runs an isolated buildkit daemon, which unlocks:
# - --output type=local
# - cache export/import
# - multi-platform (if you ever need it)
ensure_builder() {
    if ! docker buildx inspect sigd >/dev/null 2>&1; then
        say "Creating buildx builder 'sigd' (docker-container)…"
        docker buildx create --name sigd --driver docker-container --use \
            >/dev/null
    else
        docker buildx use sigd >/dev/null
    fi
    docker buildx inspect --bootstrap >/dev/null
}

# Get whatever is currently latest (from API)
latest_tag_from_api() {
    local tag=""
    if command -v jq >/dev/null 2>&1; then
        tag="$(
            curl -fsSL \
                "https://api.github.com/repos/${REPO_SLUG}/releases/latest" |
                jq -r .tag_name 2>/dev/null || true
        )"
    else
        tag="$(
            curl -fsSL \
                "https://api.github.com/repos/${REPO_SLUG}/releases/latest" |
                grep -m1 -Eo '"tag_name"\s*:\s*"[^"]+"' |
                sed -E 's/.*"tag_name"\s*:\s*"([^"]+)".*/\1/' || true
        )"
    fi
    printf "%s" "${tag}"
}

# Get whatever is currently latest (from refs)
latest_tag_from_refs() {
    git ls-remote --tags "https://github.com/${REPO_SLUG}.git" |
        awk -F/ '/refs\/tags\/v?[0-9]/{print $3}' |
        sed 's/\^{}//' |
        sort -V |
        tail -1
}

# Pick a ref to build if none was specified
pick_ref() {
    local arg_ref="${1:-}"
    if [[ -n "${arg_ref}" ]]; then
        printf "%s" "${arg_ref}"
        return
    fi
    if [[ -n "${SIGNAL_REF:-}" ]]; then
        printf "%s" "${SIGNAL_REF}"
        return
    fi
    local t=""
    t="$(latest_tag_from_api)"
    if [[ -z "${t}" ]]; then
        warn "GitHub API lookup failed or empty; trying refs…"
        t="$(latest_tag_from_refs)"
    fi
    [[ -n "${t}" ]] || die "Could not determine latest release tag."
    printf "%s" "${t}"
}

# Enable the build kit
enable_buildkit() {
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
}

#
# The actual build process looks like this:
#
# 1. Determine build ref
# 2. Announce target
# 3. Enable build kit
# 4. Validate docker file
# 5. Ensure a buildx builder exists
# 6. Prepare build args
# 7. Build with buildx and export artifacts directly to the host filesystem
# 8. Optionally persist cache
# 9. List artifacts
#
main() {
    local want_ref
    want_ref="$(pick_ref "${1:-}")"
    say "Building Signal Desktop @ ${want_ref}"

    enable_buildkit
    [[ -f "${DOCKERFILE}" ]] || die "Dockerfile not found at: ${DOCKERFILE}"

    ensure_builder

    # Prepare host output directory for the BuildKit exporter.
    # This replaces the old flow:
    #   docker build -> docker create -> docker cp
    # with:
    #   docker buildx build --output type=local
    say "Preparing output directory: ${OUT_DIR}"
    umask 022
    rm -rf "${OUT_DIR}"
    mkdir -p "${OUT_DIR}"

    # Prepare build args
    local build_args=(
        --builder sigd
        --pull
        --file "${DOCKERFILE}"
        --progress "${PROGRESS}"

        # We only want the artifact-exporting stage on the host.
        --target exporter

        # Export /out from the exporter stage to the host directory directly.
        --output "type=local,dest=${OUT_DIR}"

        --build-arg "SIGNAL_REF=${want_ref}"
        --build-arg "LINUX_TARGETS=${LINUX_TARGETS}"
        --build-arg "PNPM_VERSION=${PNPM_VERSION}"
        --build-arg "ARTIFACT_UID=${ARTIFACT_UID}"
        --build-arg "ARTIFACT_GID=${ARTIFACT_GID}"
    )

    # Optional: set platform explicitly (usually not needed for local builds)
    if [[ -n "${PLATFORM}" ]]; then
        build_args+=(--platform "${PLATFORM}")
    fi

    # Cache behavior:
    # - NO_CACHE=1 disables caching (slowest but cleanest)
    # - NO_CACHE=0 uses BuildKit cache in the builder container (fast)
    # - NO_CACHE=0 PERSIST_CACHE=1 also stores cache on disk at CACHE_DIR
    if [[ "${NO_CACHE}" == "1" ]]; then
        build_args+=(--no-cache)
    else
        if [[ "${PERSIST_CACHE}" == "1" ]]; then
            mkdir -p "${CACHE_DIR}"
            build_args+=(
                --cache-from "type=local,src=${CACHE_DIR}"
                --cache-to "type=local,dest=${CACHE_DIR}.tmp,mode=max"
            )
        fi
    fi

    say "Docker buildx build → exporting artifacts to ${OUT_DIR}"
    docker buildx build "${build_args[@]}" .

    # If we exported cache, swap it into place atomically-ish
    if [[ "${NO_CACHE}" != "1" && "${PERSIST_CACHE}" == "1" ]]; then
        rm -rf "${CACHE_DIR}"
        mv "${CACHE_DIR}.tmp" "${CACHE_DIR}"
    fi

    say ">> Done. Artifacts in: ${OUT_DIR}"
    ls -lh "${OUT_DIR}" || true
}

main "$@"
