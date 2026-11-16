#!/usr/bin/env bash
# Linux server installer.
# Latest: curl -fsSL https://raw.githubusercontent.com/arefhere51/arman-vpn/main/install.sh | sudo bash
set -euo pipefail
REPO="${REPO:-arefhere51/arman-vpn}"
VERSION="${VERSION:-latest}"
if [ "$VERSION" = latest ]; then
  BASE="${BASE_URL:-https://github.com/$REPO/releases/latest/download}"
else
  VERSION="v${VERSION#v}"
  BASE="${BASE_URL:-https://github.com/$REPO/releases/download/$VERSION}"
fi
fail() { printf 'arman-vpn installer: %s\n' "$*" >&2; exit 1; }
[ "$(uname -s)" = Linux ] || fail 'Linux is required.'
[ "$(id -u)" -eq 0 ] || fail 'run with sudo: curl -fsSL https://raw.githubusercontent.com/arefhere51/arman-vpn/main/install.sh | sudo bash'
command -v systemctl >/dev/null 2>&1 || fail 'systemd is required.'
command -v curl >/dev/null 2>&1 || fail 'curl is required.'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required.'
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  armv7l|armv8l) arch=armv7 ;;
  *) fail "unsupported CPU architecture: $(uname -m)" ;;
esac
archive="arman-vpn-core-linux-$arch.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf 'Downloading %s from %s…\n' "$archive" "$REPO"
curl -fsSL --retry 3 "$BASE/$archive" -o "$tmp/$archive" || fail "could not download $BASE/$archive; publish a tagged GitHub Release first."
curl -fsSL --retry 3 "$BASE/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt" || fail 'could not download release checksums.'
line="$(awk -v f="$archive" '$2 == f || $2 == "*" f {print; exit}' "$tmp/SHA256SUMS.txt")"
[ -n "$line" ] || fail "$archive is missing from release checksums."
(cd "$tmp" && printf '%s\n' "$line" | sha256sum -c --status) || fail 'archive checksum mismatch.'
printf 'Checksum verified.\n'
tar -xzf "$tmp/$archive" -C "$tmp"
dir="$tmp/arman-vpn-core-linux-$arch"
[ -x "$dir/arman-vpn-core" ] && [ -f "$dir/install-systemd.sh" ] || fail 'invalid server release archive.'
export INSTALL_DIR="${INSTALL_DIR:-/opt/arman-vpn}"
export SERVICE_NAME="${SERVICE_NAME:-arman-vpn}"
export SERVICE_USER="${SERVICE_USER:-arman-vpn}"
export INSTALLER_URL="https://raw.githubusercontent.com/$REPO/main/install.sh"
export RELEASES_URL="https://github.com/$REPO/releases"
export BINARY="$dir/arman-vpn-core"
export SELF=/usr/local/bin/arman-vpn
fresh=0
[ -f "$INSTALL_DIR/user-data/config.json" ] || fresh=1
bash "$dir/install-systemd.sh" install
install -m 0755 "$dir/install-systemd.sh" /usr/local/bin/arman-vpn
if [ "$fresh" = 1 ]; then
  printf '\nConfiguring separate dashboard and proxy logins…\n'
  /usr/local/bin/arman-vpn setup-server
fi
printf '\nInstallation complete. Open http://YOUR-SERVER-IP:10820/app/#locations\n'
printf 'Allow TCP 10820 and every enabled proxy port in the server and cloud firewalls.\n'
printf 'Manage service: sudo arman-vpn status | start | stop | restart | logs | update\n'
