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

set -euo pipefail

IMAGE_NAME="signal-desktop-builder"
CONTAINER_NAME="signal-desktop-out"
OUTPUT_DIR="${OUTPUT_DIR:-./out}"
# You can override these on the docker build command with --build-arg
SIGNAL_REF="${SIGNAL_REF:-v7.69.0}"
LINUX_TARGETS="${LINUX_TARGETS:-appImage}"
PNPM_VERSION="${PNPM_VERSION:-10.6.4}"
ARTIFACT_UID="${ARTIFACT_UID:-1000}"
ARTIFACT_GID="${ARTIFACT_GID:-1000}"

echo "[*] Building image (Signal ref: ${SIGNAL_REF}, targets: ${LINUX_TARGETS})..."
docker build --no-cache -t "${IMAGE_NAME}" \
  --build-arg SIGNAL_REF="${SIGNAL_REF}" \
  --build-arg LINUX_TARGETS="${LINUX_TARGETS}" \
  --build-arg PNPM_VERSION="${PNPM_VERSION}" \
  --build-arg ARTIFACT_UID="${ARTIFACT_UID}" \
  --build-arg ARTIFACT_GID="${ARTIFACT_GID}" \
  .

echo "[*] Exporting artifacts..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
cid="$(docker create --name "${CONTAINER_NAME}" "${IMAGE_NAME}")"
trap 'docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true' EXIT
docker cp "${cid}:/out/." "${OUTPUT_DIR}/"
docker rm -f "${CONTAINER_NAME}" >/dev/null
trap - EXIT

echo "[*] Done. Artifacts in: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}" || true
