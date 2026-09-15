#!/usr/bin/env bash
set -euo pipefail

# Always fetch a fresh Linux Flutter SDK so stale local cache folders cannot break the build.
FLUTTER_VERSION="3.44.6"
FLUTTER_TAR="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_DIR="$PWD/flutter"

rm -rf "$FLUTTER_DIR" "flutter.tar.xz"

echo "Downloading Flutter ${FLUTTER_VERSION}..."
curl -fL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TAR}" -o flutter.tar.xz
tar -xf flutter.tar.xz

export PATH="$FLUTTER_DIR/bin:$PATH"

# The extracted SDK is owned by a different uid than the build user, which
# makes git refuse to read it ("dubious ownership") and every flutter command
# fail. Marking it safe up front avoids that.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
