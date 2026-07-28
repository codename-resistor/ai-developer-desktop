#!/bin/bash
# Install moby-engine (Docker) alongside Podman.

set -euo pipefail

dnf5 install -y moby-engine moby-engine-rootless-extras

systemctl enable docker.socket
