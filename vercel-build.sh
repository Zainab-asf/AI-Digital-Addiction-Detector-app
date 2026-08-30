#!/usr/bin/env bash
set -e

# Use a Flutter version compatible with the project's Dart SDK requirement.
# This repo builds successfully with Flutter 3.44.6 locally.
FLUTTER_VERSION="3.44.6"
FLUTTER_TAR="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_DIR="$PWD/flutter"

if [ ! -d "$FLUTTER_DIR/bin" ]; then
  echo "Downloading Flutter ${FLUTTER_VERSION}..."
  curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TAR}" -o flutter.tar.xz
  tar -xf flutter.tar.xz
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter build web --release
