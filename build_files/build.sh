#!/bin/bash

set -ouex pipefail

### Install packages

# shellcheck disable=SC2016 # $basearch is expanded by dnf, not by the shell
printf '%s\n' '[rex]' 'name=Rex (snapshot)' 'baseurl=https://pkgs.superlogical.com/rex/rpm/snapshot/$basearch' 'enabled=1' 'gpgcheck=1' 'repo_gpgcheck=1' 'gpgkey=https://pkgs.superlogical.com/rex/keys/rex.asc' > /etc/yum.repos.d/rex.repo
dnf5 install -y rex

# Packages can be installed from any enabled yum repo on the image.

rpm --import https://packages.microsoft.com/keys/microsoft.asc &&
  echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

# Terra ships in the base image (/usr/share/dnf5/repos.d/terra.repo, disabled by
# default). Only add it via --repofrompath on older bases that lack it: dnf5 aborts
# with 'Failed to create repo "terra": Id is present more than once in the
# configuration' if the repo id is already defined.
if [[ ! -e /usr/share/dnf5/repos.d/terra.repo && ! -e /etc/yum.repos.d/terra.repo ]]; then
  # shellcheck disable=SC2016 # $releasever is expanded by dnf, not by the shell
  dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys
fi

# Install packages from Fedora/Terra and the official ChatGPT desktop RPM.
# zed is only available in the terra repo, which is disabled in the base image.
CHATGPT_RPM_URL="https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm"
dnf5 install -y --enable-repo=terra tmux zed "$CHATGPT_RPM_URL"

# Install the official Kitty binary release instead of Fedora's package.
KITTY_VERSION="0.51.1"
case "$(uname -m)" in
  x86_64) KITTY_ARCH="x86_64"; KITTY_SHA256="d309be978f017dbdcccae175d281092fefe7c8bc64478fa620581604ab0b53c0" ;;
  aarch64) KITTY_ARCH="arm64"; KITTY_SHA256="9c3e8e38a5068c511e3a94e065cbd2c5af4922d76d2d205d5084018e8572648d" ;;
  *) echo "Unsupported Kitty architecture: $(uname -m)" >&2; exit 1 ;;
esac
KITTY_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$KITTY_TMP_DIR"' EXIT
curl -fsSL --proto '=https' -o "$KITTY_TMP_DIR/kitty.txz" "https://github.com/kovidgoyal/kitty/releases/download/v$KITTY_VERSION/kitty-$KITTY_VERSION-$KITTY_ARCH.txz"
echo "$KITTY_SHA256  $KITTY_TMP_DIR/kitty.txz" | sha256sum -c -
mkdir -p /usr/lib/kitty /usr/share/applications /usr/share/icons/hicolor/256x256/apps
tar -xJf "$KITTY_TMP_DIR/kitty.txz" -C /usr/lib/kitty
ln -s /usr/lib/kitty/bin/{kitty,kitten} /usr/bin/
install -m 644 /usr/lib/kitty/share/applications/kitty{,-open}.desktop /usr/share/applications/
install -m 644 /usr/lib/kitty/share/icons/hicolor/256x256/apps/kitty.png /usr/share/icons/hicolor/256x256/apps/
if [[ "$(/usr/bin/kitty --version) " != "kitty $KITTY_VERSION "* ]]; then
  echo "Expected Kitty $KITTY_VERSION" >&2
  exit 1
fi
rm -rf "$KITTY_TMP_DIR"
trap - EXIT

# Install the official Herdr GUI (not herdr-core).
HERDR_VERSION="0.1.16"
HERDR_ARCH="$(uname -m)"
case "$HERDR_ARCH" in
  x86_64) HERDR_SHA256="282d2632196b238206cfe66bfb61c0faf299ca1c91843bd076521bbe36571216" ;;
  aarch64) HERDR_SHA256="efeef4f1759b0e8900f205c2c22b14287a112f874406539b4ea1b3be24b73631" ;;
  *) echo "Unsupported Herdr GUI architecture: $HERDR_ARCH" >&2; exit 1 ;;
esac
HERDR_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$HERDR_TMP_DIR"' EXIT
curl -fsSL --proto '=https' -o "$HERDR_TMP_DIR/app.tar.gz" "https://releases.herdr.dev/app/$HERDR_VERSION/herdr-app-linux-$HERDR_ARCH.tar.gz"
echo "$HERDR_SHA256  $HERDR_TMP_DIR/app.tar.gz" | sha256sum -c -
tar -xzf "$HERDR_TMP_DIR/app.tar.gz" -C "$HERDR_TMP_DIR"
mkdir -p /usr/lib/herdr-app /usr/share/applications /usr/share/icons/hicolor/scalable/apps
cp -a "$HERDR_TMP_DIR/herdr-app/." /usr/lib/herdr-app/
ln -s /usr/lib/herdr-app/herdr-app /usr/bin/herdr-app
install -m 644 "$HERDR_TMP_DIR/herdr-app/herdr-app.svg" /usr/share/icons/hicolor/scalable/apps/herdr-app.svg
cat > /usr/share/applications/herdr-app.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Herdr
Comment=Terminals and coding agents that keep running
Exec=/usr/bin/herdr-app
Icon=herdr-app
Terminal=false
Categories=Development;
StartupWMClass=herdr-app
EOF
rm -rf "$HERDR_TMP_DIR"
trap - EXIT

dnf5 install -y rocminfo

dnf5 install -y libglvnd-devel mesa-libGL-devel

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
