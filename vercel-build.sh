#!/usr/bin/env bash
set -e

# Install Flutter SDK for the build environment
FLUTTER_VERSION="3.24.3"
FLUTTER_TAR="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -d "$PWD/flutter" ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION}..."
  curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TAR}" -o flutter.tar.xz
  tar -xf flutter.tar.xz
fi

export PATH="$PWD/flutter/bin:$PATH"
flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
