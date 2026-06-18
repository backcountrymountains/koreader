#!/bin/bash
# Build KOReader Android APK (Gradle only — reuses existing native/asset cache)
# and sign it with the Android debug keystore.
# Usage: bash scripts/build_and_sign.sh [--install]
set -e

KOREADER_DIR="/home/point/nook/koreader"
LAUNCHER_DIR="$KOREADER_DIR/platform/android/luajit-launcher"
BUILD_DIR="$KOREADER_DIR/koreader-android-armv7a-unknown-linux-android18/luajit-launcher"
ASSETS_DIR="$BUILD_DIR/assets"
LIBS_DIR="$BUILD_DIR/libs"
ANDROID_SDK="/home/point/android-sdk"
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
APKSIGNER="$ANDROID_SDK/build-tools/34.0.0/apksigner"

VERS_NAME=$(git -C "$KOREADER_DIR" describe --tags --long)
DATE=$(date +%Y-%m-%d)

# Add offset so dev builds always outrank public release version codes.
# Public builds use raw `git rev-list --count HEAD`; we add 1000 to stay ahead.
VERS_CODE=$(( $(git -C "$KOREADER_DIR" rev-list --count HEAD) + 1000 ))

UNSIGNED_APK="$KOREADER_DIR/koreader-android-arm-${VERS_NAME}_${DATE}-unsigned.apk"
SIGNED_APK="$KOREADER_DIR/koreader-android-arm-${VERS_NAME}_${DATE}-signed.apk"

export ANDROID_SDK_ROOT="$ANDROID_SDK"
export ANDROID_HOME="$ANDROID_SDK"

echo "=== KOReader Android build ==="
echo "  Version : $VERS_NAME ($VERS_CODE)"
echo "  Assets  : $ASSETS_DIR"
echo "  Libs    : $LIBS_DIR"
echo ""

# ── 1. Gradle build ───────────────────────────────────────────────────────────
echo "[1/3] Running Gradle..."
"$LAUNCHER_DIR/gradlew" \
    --project-dir="$LAUNCHER_DIR" \
    --project-cache-dir="$BUILD_DIR/gradle" \
    -PassetsPath="$ASSETS_DIR" \
    -PbuildDir="$BUILD_DIR" \
    -PlibsPath="$LIBS_DIR" \
    -PsevenZipLib="koreader-monolibtic" \
    -PprojectName="KOReader" \
    -PversCode="$VERS_CODE" \
    -PversName="$VERS_NAME" \
    'app:assembleArmRocksRelease'

cp "$BUILD_DIR/outputs/apk/armRocks/release/NativeActivity.apk" "$UNSIGNED_APK"
echo "  → $UNSIGNED_APK"

# ── 2. Sign ───────────────────────────────────────────────────────────────────
echo "[2/3] Signing with debug keystore..."
"$APKSIGNER" sign \
    --ks "$DEBUG_KEYSTORE" \
    --ks-pass pass:android \
    --ks-key-alias androiddebugkey \
    --key-pass pass:android \
    --out "$SIGNED_APK" \
    "$UNSIGNED_APK"

rm -f "$UNSIGNED_APK"
echo "  → $SIGNED_APK"

# ── 3. Install (optional) ─────────────────────────────────────────────────────
if [[ "$1" == "--install" ]]; then
    echo "[3/3] Installing via ADB..."
    if ! adb install -r "$SIGNED_APK" 2>/dev/null; then
        echo "  Direct install failed (version downgrade?). Uninstalling first..."
        adb uninstall org.koreader.launcher
        adb install "$SIGNED_APK"
    fi
    echo "  Installed."
else
    echo "[3/3] Skipping install (pass --install to install automatically)."
    echo ""
    echo "  To install: adb install -r \"$SIGNED_APK\""
    echo "  Or run   : bash scripts/build_and_sign.sh --install"
fi

echo ""
echo "Done."
