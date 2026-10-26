#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.

rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys

# Install packages from Fedora/Terra and the official ChatGPT desktop RPM.
CHATGPT_RPM_URL="https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm"
dnf5 install -y tmux kitty zed "$CHATGPT_RPM_URL"

# Install a pinned Herdr UI release from the upstream installer's RPM source.
HERDR_VERSION="20261020.1"
HERDR_ARCH="$(uname -m)"
case "$HERDR_ARCH" in
  x86_64|aarch64) ;;
  *) echo "Unsupported Herdr UI architecture: $HERDR_ARCH" >&2; exit 1 ;;
esac
HERDR_RPM="Herdr-${HERDR_VERSION}-${HERDR_ARCH}-unknown-linux-gnu.rpm"
HERDR_BASE_URL="https://github.com/penso/herdr-gpui/releases/download/v${HERDR_VERSION}"
HERDR_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$HERDR_TMP_DIR"' EXIT
curl -fsSL --proto '=https' -o "$HERDR_TMP_DIR/$HERDR_RPM" "$HERDR_BASE_URL/$HERDR_RPM"
curl -fsSL --proto '=https' -o "$HERDR_TMP_DIR/$HERDR_RPM.sha256" "$HERDR_BASE_URL/$HERDR_RPM.sha256"
(cd "$HERDR_TMP_DIR" && sha256sum -c "$HERDR_RPM.sha256")
dnf5 install -y "$HERDR_TMP_DIR/$HERDR_RPM"
rm -rf "$HERDR_TMP_DIR"
trap - EXIT

dnf5 install -y code-insiders

dnf5 install -y rocminfo

dnf5 install -y libglvnd-devel mesa-libGL-devel

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
