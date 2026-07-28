#!/bin/bash
# Podman is included in the base image. This script installs Podman Desktop
# and enables the Podman socket.

set -euo pipefail

dnf5 -y copr enable gordonmessmer/nodejs-electron
dnf5 -y install podman-desktop

systemctl enable podman.socket
