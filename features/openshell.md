---
layout: feature
name: "OpenShell"
status: "experimental"
---

OpenShell is an open-source runtime from NVIDIA that lets you run AI coding assistants like Claude Code in sandboxed environments with kernel-level isolation. It enforces controls over file access, credentials, and network connections through declarative YAML policies, so autonomous agents operate with exactly the permissions they need and nothing more.

## How It Works

A local gateway service starts automatically at login and uses Podman to create and manage isolated sandboxes. Each sandbox enforces filesystem, network, process, and inference routing policies defined in YAML.

## References

- [OpenShell documentation](https://docs.nvidia.com/openshell/latest/)
- [OpenShell on GitHub](https://github.com/NVIDIA/OpenShell)
