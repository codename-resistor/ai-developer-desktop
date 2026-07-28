---
layout: feature
name: "Podman"
status: "experimental"
---

Podman provides a daemonless container runtime for building, running, and managing OCI containers without requiring root privileges. Podman Desktop provides a graphical interface for managing containers, images, and Kubernetes resources.

## Status and Fedora Plans

Work in progress. Before proposing to Fedora:
- Chromium source for Electron needs to be synchronized with other packages
- Pre-built binaries must be stripped from Podman Desktop's node_modules directory

## Technical Details

Podman Desktop built from source with modifications for Fedora packaging compliance.
