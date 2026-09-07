#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
case "$MODE" in run|--verify|--debug|--logs|--telemetry|--build|--universal) ;; *) echo "Usage: $0 [--verify|--debug|--logs|--telemetry|--build|--universal]"; exit 2;; esac
pkill -x Autotyper >/dev/null 2>&1 || true
APP_BUNDLE="$ROOT_DIR/dist/Autotyper.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
if [[ "$MODE" == "--universal" ]]; then
    for ARCH in x86_64 arm64; do
        ./script/swift.sh build --product Autotyper -c release --arch "$ARCH"
    done
    lipo -create "$(./script/swift.sh build -c release --arch x86_64 --show-bin-path)/Autotyper" "$(./script/swift.sh build -c release --arch arm64 --show-bin-path)/Autotyper" -output "$APP_BUNDLE/Contents/MacOS/Autotyper"
else
    ./script/swift.sh build --product Autotyper
    cp "$(./script/swift.sh build --show-bin-path)/Autotyper" "$APP_BUNDLE/Contents/MacOS/Autotyper"
fi
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Autotyper</string>
<key>CFBundleIdentifier</key><string>local.autotyper.app</string>
<key>CFBundleName</key><string>Autotyper</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
./script/build_icon.sh
./script/sign_app.sh "$APP_BUNDLE"
case "$MODE" in
 --build) exit 0 ;;
 --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/Autotyper" ;;
 --logs|--telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "Autotyper"' ;;
 --verify|--universal) open -n "$APP_BUNDLE"; sleep 1; pgrep -x Autotyper ;;
 run) open -n "$APP_BUNDLE" ;;
esac
