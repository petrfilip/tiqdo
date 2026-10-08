#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
MODULE_CACHE_DIR="$BUILD_DIR/ModuleCache"
APP_NAME="Tiqdo"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
BUNDLE_ID="cz.tix.tiqdo"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "APP_VERSION must be X.Y.Z" >&2; exit 2; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo "BUILD_NUMBER must be numeric" >&2; exit 2; }

INSTALL=false
LAUNCH=false

usage() {
    echo "Usage: ./build.sh [--install] [--launch]"
    echo ""
    echo "  --install  Install a symlink at $INSTALL_DIR/$APP_NAME.app"
    echo "  --launch   Launch the built app after a successful build"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --install)
            INSTALL=true
            ;;
        --launch)
            LAUNCH=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

echo "=== Building $APP_NAME ==="

SOURCES=()
while IFS= read -r -d '' source; do
    SOURCES+=("$source")
done < <(find "$SCRIPT_DIR/Sources" -name "*.swift" -type f -print0)

if [ "${#SOURCES[@]}" -eq 0 ]; then
    echo "No Swift source files found." >&2
    exit 1
fi

echo "[1/4] Found ${#SOURCES[@]} Swift source files"

SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos14.0"
echo "       SDK: $SDK"
echo "       Target: $TARGET"

echo "[2/4] Compiling..."
mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR"

swiftc \
    -O \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -sdk "$SDK" \
    -target "$TARGET" \
    -o "$BUILD_DIR/$APP_NAME" \
    -module-name "$APP_NAME" \
    -swift-version 5 \
    "${SOURCES[@]}"

echo "       Binary: $BUILD_DIR/$APP_NAME"

echo "[3/4] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$SCRIPT_DIR/Sources/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 14.0" "$APP_BUNDLE/Contents/Info.plist"

cp "$SCRIPT_DIR/LICENSE" "$APP_BUNDLE/Contents/Resources/"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"
echo "       App bundle: $APP_BUNDLE"

OPEN_TARGET="$APP_BUNDLE"
if [ "$INSTALL" = true ]; then
    echo "[4/4] Installing..."
    SYMLINK="$INSTALL_DIR/$APP_NAME.app"

    if [ -L "$SYMLINK" ]; then
        rm "$SYMLINK"
    elif [ -e "$SYMLINK" ]; then
        echo "  Warning: $SYMLINK already exists and is not a symlink." >&2
        echo "  Remove it manually or choose another INSTALL_DIR." >&2
        exit 1
    fi

    ln -s "$APP_BUNDLE" "$SYMLINK"
    OPEN_TARGET="$SYMLINK"
    echo "       Installed: $SYMLINK -> $APP_BUNDLE"
else
    echo "[4/4] Install skipped"
fi

if [ "$LAUNCH" = true ]; then
    if pgrep -xq "$APP_NAME"; then
        pkill -x "$APP_NAME"
        sleep 0.5
    fi
    open "$OPEN_TARGET"
fi

echo ""
echo "=== Done! ==="
echo "  App: $APP_BUNDLE"
echo "  Install: ./build.sh --install"
echo "  Launch:  ./build.sh --launch"
