#!/usr/bin/env bash
# Simple setup script to install Flutter and Dart on Linux
# Not for production use. Adjust as needed for your environment.
set -e
if [ "$(uname)" != "Linux" ]; then
  echo "This setup script currently supports only Linux." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y curl unzip xz-utils git

FLUTTER_VERSION="3.13.6"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
if [ ! -f "$FLUTTER_ARCHIVE" ]; then
  curl -O "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
fi

mkdir -p "${HOME}/development"
tar xf "$FLUTTER_ARCHIVE" -C "${HOME}/development"

export PATH="${HOME}/development/flutter/bin:${PATH}"
echo "Flutter installed at ${HOME}/development/flutter" >&2
echo "Add the following line to your shell profile to permanently update PATH:" >&2
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >&2

flutter doctor
