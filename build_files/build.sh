#!/bin/bash

set -ouex pipefail

### Install packages

releasever="$(rpm -E %fedora)"

# Generic logos and release notes must replace Fedora's, as this is a Remix
dnf5 install -y --allowerasing generic-release generic-logos generic-release-notes

# copr.vendor.conf will be required to make "dnf copr enable" work. It will otherwise
# try to add a "generic-<rel>-<arch> chroot
install -d /usr/share/dnf/plugins
cat >> /usr/share/dnf/plugins/copr.vendor.conf << EOF
[main]
distribution = fedora
releasever = ${releasever}
EOF

# Keep Fedora's libdnf.conf defaults, currently in fedora-release-common
cat >> /usr/share/dnf5/libdnf.conf.d/20-fedora-defaults.conf <<EOF
[main]
best=False
pkg_gpgcheck=True
skip_if_unavailable=True
EOF

# Allow rpm-ostree actions to appropriate local users
cat >> /usr/share/polkit-1/rules.d/org.projectatomic.rpmostree1.rules <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.projectatomic.rpmostree1.repo-refresh" ||
         action.id == "org.projectatomic.rpmostree1.upgrade") &&
        subject.active == true &&
        subject.local == true) {
            return polkit.Result.YES;
    }

    if ((action.id == "org.projectatomic.rpmostree1.install-uninstall-packages" ||
         action.id == "org.projectatomic.rpmostree1.rollback" ||
         action.id == "org.projectatomic.rpmostree1.reload-daemon" ||
         action.id == "org.projectatomic.rpmostree1.cancel" ||
         action.id == "org.projectatomic.rpmostree1.cleanup" ||
         action.id == "org.projectatomic.rpmostree1.client-management") &&
        subject.active == true &&
        subject.local == true &&
        subject.isInGroup("wheel")) {
            return polkit.Result.YES;
    }
});
EOF

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

/ctx/install-podman.sh
/ctx/install-openshell.sh
