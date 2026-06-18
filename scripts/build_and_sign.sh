#!/bin/bash
# Build KOReader Android APK (Gradle only — reuses existing native/asset cache)
# and sign it with the Android debug keystore.
# Usage: bash scripts/build_and_sign.sh [--install]
#
# The koreader.7z asset bundle is pre-built (not rebuilt here). Before Gradle
# runs, the three Lua files modified by nook-personal are spliced into the 7z
# from the current koreader checkout so the APK always matches the source tree.
set -e

KOREADER_DIR="/home/point/nook/koreader"
LAUNCHER_DIR="$KOREADER_DIR/platform/android/luajit-launcher"
BUILD_DIR="$KOREADER_DIR/koreader-android-armv7a-unknown-linux-android18/luajit-launcher"
ASSETS_DIR="$BUILD_DIR/assets"
LIBS_DIR="$BUILD_DIR/libs"
ANDROID_SDK="/home/point/android-sdk"
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
APKSIGNER="$ANDROID_SDK/build-tools/34.0.0/apksigner"

ARCHIVE="$ASSETS_DIR/module/koreader.7z"
PATCH_TMP="$BUILD_DIR/7z-patch-tmp"

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
echo "  Branch  : $(git -C "$KOREADER_DIR" branch --show-current)"
echo "  Assets  : $ASSETS_DIR"
echo ""

# ── 1. Patch koreader.7z with current Lua files ───────────────────────────────
echo "[1/4] Patching koreader.7z with Lua files from current branch..."
rm -rf "$PATCH_TMP"
mkdir -p "$PATCH_TMP"
7z x "$ARCHIVE" -o"$PATCH_TMP" > /dev/null

cp "$KOREADER_DIR/frontend/device/android/device.lua" \
   "$PATCH_TMP/frontend/device/android/device.lua"
cp "$KOREADER_DIR/frontend/device/android/powerd.lua" \
   "$PATCH_TMP/frontend/device/android/powerd.lua"
cp "$KOREADER_DIR/frontend/ui/network/manager.lua" \
   "$PATCH_TMP/frontend/ui/network/manager.lua"

rm -f "$ARCHIVE"
(cd "$PATCH_TMP" && 7z a -t7z -m0=lzma2 -mx=9 "$ARCHIVE" . > /dev/null)
rm -rf "$PATCH_TMP"
echo "  → device.lua, powerd.lua, manager.lua patched"

# ── 2. Gradle build ───────────────────────────────────────────────────────────
echo "[2/4] Running Gradle..."
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

# ── 3. Sign ───────────────────────────────────────────────────────────────────
echo "[3/4] Signing with debug keystore..."
"$APKSIGNER" sign \
    --ks "$DEBUG_KEYSTORE" \
    --ks-pass pass:android \
    --ks-key-alias androiddebugkey \
    --key-pass pass:android \
    --out "$SIGNED_APK" \
    "$UNSIGNED_APK"

rm -f "$UNSIGNED_APK"
echo "  → $SIGNED_APK"

# ── 4. Install (optional) ─────────────────────────────────────────────────────
if [[ "$1" == "--install" ]]; then
    echo "[4/4] Installing via ADB..."
    if ! adb install -r "$SIGNED_APK" 2>/dev/null; then
        echo "  Direct install failed (version downgrade?). Uninstalling first..."
        adb uninstall org.koreader.launcher
        adb install "$SIGNED_APK"
    fi
    echo "  Installed."
else
    echo "[4/4] Skipping install (pass --install to install automatically)."
    echo ""
    echo "  To install: adb install -r \"$SIGNED_APK\""
    echo "  Or run   : bash scripts/build_and_sign.sh --install"
fi

echo ""
echo "Done."
