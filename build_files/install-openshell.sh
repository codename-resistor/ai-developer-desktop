#!/bin/bash
# Install OpenShell RPM packages from a GitHub release.
#
# Derived from https://github.com/NVIDIA/OpenShell/blob/main/install.sh
# (Apache-2.0). Stripped to the RPM-only path needed for a Fedora Atomic
# container build — no macOS/Debian/Homebrew, no runtime service start,
# no interactive upgrade guards.

set -euo pipefail

REPO="NVIDIA/OpenShell"
GITHUB_URL="https://github.com/${REPO}"
CHECKSUMS_NAME="openshell-checksums-sha256.txt"
RELEASE_TAG="${OPENSHELL_VERSION:-}"

resolve_release_tag() {
    if [[ -n "$RELEASE_TAG" ]]; then
        echo "$RELEASE_TAG"
        return
    fi
    local resolved
    resolved="$(curl -fLsS -o /dev/null -w '%{url_effective}' "${GITHUB_URL}/releases/latest")"
    local version="${resolved##*/}"
    if [[ -z "$version" || "$version" == "latest" ]]; then
        echo "error: could not determine latest release version" >&2
        exit 1
    fi
    echo "$version"
}

find_rpm_asset() {
    local checksums="$1" arch="$2" package="$3"
    local dev_name="${package}-dev-${arch}.rpm"
    local fallback_re="^${package}-[0-9].*\\.${arch}\\.rpm\$"
    awk -v dev_name="$dev_name" -v fallback_re="$fallback_re" '
        {
            name = $2; sub("^\\*", "", name)
            if (name == dev_name) { print name; exit }
            if (fallback == "" && name ~ fallback_re) fallback = name
        }
        END { if (fallback != "") print fallback }
    ' "$checksums"
}

download_release_asset() {
    local tag="$1" filename="$2" output="$3"
    if curl -fLs --retry 3 --max-redirs 5 -o "$output" \
        "${GITHUB_URL}/releases/download/${tag}/${filename}"; then
        return 0
    fi
    # GitHub normalizes ~ to . in asset names
    local normalized="${filename//\~/.}"
    if [[ "$normalized" != "$filename" ]]; then
        curl -fLs --retry 3 --max-redirs 5 -o "$output" \
            "${GITHUB_URL}/releases/download/${tag}/${normalized}"
        return
    fi
    return 1
}

verify_checksum() {
    local archive="$1" checksums="$2" filename="$3"
    local expected
    expected="$(awk -v name="$filename" '($2 == name || $2 == "*" name) { print $1; exit }' "$checksums")"
    if [[ -z "$expected" ]]; then
        echo "error: no checksum entry for ${filename}" >&2
        exit 1
    fi
    echo "${expected}  ${archive}" | sha256sum -c --quiet
}

main() {
    local arch
    arch="$(rpm --eval '%{_arch}')"
    case "$arch" in
        x86_64|aarch64) ;;
        *) echo "error: unsupported architecture: ${arch}" >&2; exit 1 ;;
    esac

    RELEASE_TAG="$(resolve_release_tag)"
    echo "Installing OpenShell ${RELEASE_TAG} for ${arch}"

    local tmpdir
    tmpdir="$(mktemp -d)"
    trap "rm -rf '$tmpdir'" EXIT

    echo "Downloading checksums..."
    curl -fLsS --retry 3 -o "${tmpdir}/${CHECKSUMS_NAME}" \
        "${GITHUB_URL}/releases/download/${RELEASE_TAG}/${CHECKSUMS_NAME}"

    local cli_rpm gateway_rpm
    cli_rpm="$(find_rpm_asset "${tmpdir}/${CHECKSUMS_NAME}" "$arch" openshell)"
    gateway_rpm="$(find_rpm_asset "${tmpdir}/${CHECKSUMS_NAME}" "$arch" openshell-gateway)"
    [[ -n "$cli_rpm" ]] || { echo "error: no openshell RPM for ${arch}" >&2; exit 1; }
    [[ -n "$gateway_rpm" ]] || { echo "error: no openshell-gateway RPM for ${arch}" >&2; exit 1; }

    for rpm_file in "$cli_rpm" "$gateway_rpm"; do
        echo "Downloading ${rpm_file}..."
        download_release_asset "$RELEASE_TAG" "$rpm_file" "${tmpdir}/${rpm_file}"
        echo "Verifying checksum..."
        verify_checksum "${tmpdir}/${rpm_file}" "${tmpdir}/${CHECKSUMS_NAME}" "$rpm_file"
    done

    echo "Installing RPM packages..."
    dnf5 install -y "${tmpdir}/${cli_rpm}" "${tmpdir}/${gateway_rpm}"

    echo "Installing gateway registration service..."
    cat > /usr/lib/systemd/user/openshell-gateway-register.service <<'UNIT'
[Unit]
Description=Register OpenShell local gateway
After=openshell-gateway.service
Requires=openshell-gateway.service
ConditionPathExists=!/run/user/%U/openshell-gateway-registered

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/bash -c 'for i in $(seq 1 30); do curl -sk --max-time 2 https://127.0.0.1:17670/ -o /dev/null 2>/dev/null && exit 0; sleep 1; done; exit 1'
ExecStart=/usr/bin/openshell gateway add https://127.0.0.1:17670 --local --name openshell
ExecStartPost=/bin/touch /run/user/%U/openshell-gateway-registered

[Install]
WantedBy=default.target
UNIT

    systemctl --global enable openshell-gateway.service
    systemctl --global enable openshell-gateway-register.service

    echo "OpenShell ${RELEASE_TAG} installed"
}

main "$@"
