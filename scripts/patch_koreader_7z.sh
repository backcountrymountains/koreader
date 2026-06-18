#!/bin/bash
# Patch koreader.7z with updated Lua files from the current koreader branch,
# then rebuild and install the APK.
set -e

KOREADER_DIR="/home/point/nook/koreader"
ASSETS_MODULE="$KOREADER_DIR/koreader-android-armv7a-unknown-linux-android18/luajit-launcher/assets/module"
ARCHIVE="$ASSETS_MODULE/koreader.7z"
TMPDIR="$KOREADER_DIR/koreader-android-armv7a-unknown-linux-android18/7z-patch-tmp"

echo "=== Patching koreader.7z with updated Lua files ==="

# ── 1. Extract archive ────────────────────────────────────────────────────────
echo "[1/4] Extracting $ARCHIVE ..."
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"
7z x "$ARCHIVE" -o"$TMPDIR" > /dev/null
echo "  Extracted to $TMPDIR"

# ── 2. Copy updated Lua files from current koreader branch ───────────────────
echo "[2/4] Patching Lua files from $(git -C "$KOREADER_DIR" branch --show-current) ..."

# device.lua: GL4Plus detection, volatile_warmth flag, WiFi toggle, SSID display
cp "$KOREADER_DIR/frontend/device/android/device.lua" \
   "$TMPDIR/frontend/device/android/device.lua"
echo "  → frontend/device/android/device.lua"

# powerd.lua: volatile_warmth init/resume restore
cp "$KOREADER_DIR/frontend/device/android/powerd.lua" \
   "$TMPDIR/frontend/device/android/powerd.lua"
echo "  → frontend/device/android/powerd.lua"

# manager.lua: isWifiOn() properly separate from isConnected()
cp "$KOREADER_DIR/frontend/ui/network/manager.lua" \
   "$TMPDIR/frontend/ui/network/manager.lua"
echo "  → frontend/ui/network/manager.lua"

# ── 3. Repack archive ─────────────────────────────────────────────────────────
echo "[3/4] Repacking $ARCHIVE ..."
BACKUP="${ARCHIVE}.bak"
cp "$ARCHIVE" "$BACKUP"
rm -f "$ARCHIVE"
(cd "$TMPDIR" && 7z a -t7z -m0=lzma2 -mx=9 "$ARCHIVE" . > /dev/null)
echo "  Repacked (backup: $BACKUP)"

# ── 4. Clean up temp dir ──────────────────────────────────────────────────────
rm -rf "$TMPDIR"
echo "  Cleaned up temp dir"

echo ""
echo "=== Patch complete — run build_and_sign.sh --install to rebuild APK ==="
