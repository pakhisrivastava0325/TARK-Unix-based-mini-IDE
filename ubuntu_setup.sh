#!/usr/bin/env bash
# Install TARK's required Ubuntu packages. Run: sudo bash ubuntu_setup.sh
set -euo pipefail
if ! command -v apt-get >/dev/null 2>&1; then
  echo 'This setup script is intended for Ubuntu/Debian systems.' >&2
  exit 1
fi
sudo apt-get update
sudo apt-get install -y bash gcc make nano coreutils findutils grep util-linux
printf '\nTARK dependencies installed. Start with: ./tark.sh\n'
