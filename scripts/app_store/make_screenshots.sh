#!/bin/zsh
# Genera las capturas del App Store: compila la app para el simulador, hace las capturas en
# bruto en iPhone 17 Pro Max y iPad Pro de 13" en los seis idiomas, y les pone titular y fondo.
#
# Uso: scripts/app_store/make_screenshots.sh [argumentos de capture.py, p. ej. --locales es-ES]
set -euo pipefail
cd "$(dirname "$0")/../.."

BUILD=$(mktemp -d)
xcodebuild build -project ClosetFinder.xcodeproj -scheme ClosetFinder \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$BUILD" CODE_SIGNING_ALLOWED=NO -quiet

python3 scripts/app_store/capture.py "$BUILD/Build/Products/Debug-iphonesimulator/ClosetFinder.app" "$@"
swiftc -O scripts/app_store/frame.swift -o "$BUILD/frame"
"$BUILD/frame" scripts/app_store/captions.json fastlane/screenshots_raw fastlane/screenshots
rm -rf "$BUILD"
