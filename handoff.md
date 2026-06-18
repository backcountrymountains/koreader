# Session Handoff — 2026-06-18

## Summary of today's work

Discovered that B&N's Android 8.1 adds `ViewRootImpl.setRefreshMode(int)` directly
to `ViewRootImpl` (found via runtime reflection / field+method enumeration). Rewrote
`NookEmperorEPDController` to use it. GC16 confirmed rootless in kernel dmesg without
the Magisk `epd_gc16` module. Module has been disabled on device and is retired.

Sorted PR structure: lights stays as PR #592, EPD controller becomes a new standalone
PR #597. Cleaned up both PR descriptions and replied to reviewer comments.

---

## Open PRs

### PR #592 — Lights (nook-gl4plus-lights)
**URL:** https://github.com/koreader/android-luajit-launcher/pull/592
**Status:** Open, awaiting review
**Branch:** `backcountrymountains:nook-gl4plus-lights`
**Files:** `DeviceInfo.kt`, `EPDFactory.kt` (NOOK_GL4PLUS in NGL4 group), `LightsFactory.kt`, `NookGL4plusController.kt`

Key notes:
- Description updated today — stale EPD section removed, setup docs added inline
- `com.nook.partner` section explains the selective re-disable procedure for users
  who had previously disabled the package to remove the B&N launcher/OTA
- `pm disable` for system components requires root (`su`); `pm enable` does not
- Replied to hugleo's comment: EInk test addressed in #597, wiki content inline in description
- Wiki edit (Android-tips-and-tricks.md) is committed locally at `/tmp/koreader-wiki`
  but could not be pushed — no write access to koreader/koreader wiki. Content is
  in PR #592 description instead. Should request wiki access from a maintainer.

### PR #597 — EPD controller (nook-gl4plus-epd)
**URL:** https://github.com/koreader/android-luajit-launcher/pull/597
**Status:** Open, awaiting review
**Branch:** `backcountrymountains:nook-gl4plus-epd` (clean branch from upstream master)
**Files:** `DeviceInfo.kt`, `EPDFactory.kt`, `NookEmperorEPDController.kt`, `TestActivity.kt`

Key notes:
- Single clean commit — all changes squashed
- `DeviceInfo.kt` change overlaps with #592 (same bnrv1300 split). Should be merged
  after #592, or rebased onto #592's head.
- `EPDFactory.kt` in #592 adds NOOK_GL4PLUS to the NGL4 group; #597 moves it to its
  own `NookEmperorEPDController` case. These conflict — #597 supersedes #592's EPD routing.
- `TestActivity.kt`: "Nook GL4 Plus" added to epdMap (addresses hugleo's review comment)
- EPD controller is confirmed working on device (this clean build was installed and tested)

### PR #596 — EPD thread fix (fix/epd-non-ui-thread)
**URL:** https://github.com/koreader/android-luajit-launcher/pull/596
**Status:** Open — maintainers not interested, no known crash on affected devices.
  Consider closing. Does not affect our device.

### koreader PR #15561 — Lua warmth support
**URL:** https://github.com/koreader/koreader/pull/15561
**Status:** Awaiting #592 merge before this can be updated (submodule bump needed).
  Currently points to our fork branch, not upstream.

---

## Key discovery: ViewRootImpl.setRefreshMode

B&N's Android 8.1 `ViewRootImpl` does NOT have `mSurfaceControl` (AOSP Android 10+
addition), but DOES have `setRefreshMode(int)` added directly as a method.

**B&N ViewRootImpl EPD methods (confirmed by runtime enumeration):**
- `setRefreshMode(int) : void` — used, routes to SurfaceFlinger → HWC → EPDC driver
- `setGu16RefreshLimit(int) : void` — not used (limits GU16 partial refresh count)
- `forceGlobalRefresh(boolean) : void` — not used

**B&N Surface EPD methods (found, not used):**
- `addEpdc(int[]) : void` — per-buffer EPDC path; `int[]` format unknown (future work)
- `nativeAddEpdc(long, int[]) : void` — native backing
- `setAutoRefreshEnabled(boolean) : void`
- `isAutoRefreshEnabled() : boolean`

**GC16 confirmed:** `setRefreshMode(0x4)` → kernel sees `mode=0x200004` on page turns.
**GLR16 unavailable:** `setRefreshMode(0x40)` accepted but HWC maps to GU16 (`0x200084`).
  `Surface.addEpdc(int[])` is the only remaining path to GLR16 — format not yet known.

---

## NookEmperorEPDController fallback order

1. `ViewRootImpl.setRefreshMode(int)` — B&N Android 8.1 (confirmed working)
2. `SurfaceControl.setRefreshMode(int)` via `mSurfaceControl` field — AOSP Android 10+
3. sysfs `force_update_mode` write — requires Magisk `epd_gc16` module

The Magisk `epd_gc16` module has been **disabled** on device and can be uninstalled.

---

## Branch map

| Repo | Branch | Purpose | Status |
|------|--------|---------|--------|
| luajit-launcher | `nook-gl4plus-pr1-clean` | personal working branch | local + fork, ahead of upstream |
| luajit-launcher | `nook-gl4plus-epd` | clean PR #597 branch | pushed to fork, PR open |
| luajit-launcher | `nook-gl4plus-lights` | PR #592 branch | pushed to fork, PR open |
| luajit-launcher | `nook-gl4plus-pr2-clean` | WiFi PR branch | pushed to fork, no PR yet |
| koreader | `nook-gl4plus-pr1-clean` | Lua warmth / PR #15561 | local + fork |

**Current submodule state:** luajit-launcher submodule is on `nook-gl4plus-epd`.
To switch back to personal working branch: `cd platform/android/luajit-launcher && git checkout nook-gl4plus-pr1-clean`

**Installed on device:** build from `nook-gl4plus-epd` (the clean PR #597 branch).

---

## After PRs merge — next steps (in order)

### 1. After #592 merges
Update #597's EPDFactory: remove NOOK_GL4PLUS from the NGL4 group (added by #592)
and keep only the NookEmperorEPDController case. Rebase `nook-gl4plus-epd` onto new
upstream master, force-push.

### 2. After #597 merges
Update koreader PR #15561 submodule pointer to upstream master. Force-push
`nook-gl4plus-pr1-clean` branch on koreader fork. Mark PR #15561 ready for review.

### 3. WiFi PR (PR2)
Changes ready on `nook-gl4plus-pr2-clean` (luajit-launcher) and koreader working
branch. Needs clean PR branch + PR in both repos. Submit after #592/#597 settle.

### 4. Wiki access
Request contributor access to koreader/koreader wiki from Frenzie or hugleo.
Wiki edit is committed at `/tmp/koreader-wiki` (ephemeral — will need to re-clone
and re-apply if that directory is gone). Content is preserved in PR #592 description
and `nook-gl4plus-research/frontlight.md`.

---

## Key files

| File | Repo | Notes |
|------|------|-------|
| `NookEmperorEPDController.kt` | luajit-launcher | VRI path + SC fallback + sysfs |
| `NookGL4plusController.kt` | luajit-launcher | brightness + warmth, no root |
| `TestActivity.kt` | luajit-launcher | "Nook GL4 Plus" in epdMap |
| `frontend/device/android/powerd.lua` | koreader | volatile_warmth restore on init/resume |
| `frontend/device/android/device.lua` | koreader | powerd construction, WiFi |
| `nook-gl4plus-research/frontlight.md` | research | WRITE_SETTINGS GUI path, com.nook.partner re-disable |
| `nook-gl4plus-research/handoff-surfacecontrol-path.md` | research | VRI discovery final results |
| `nook-gl4plus-research/hwc-hal-reverse-engineering.md` | research | full HWC HAL RE |
| `nook-gl4plus-research/bdt_wakeup/claude_battery_drain.log` | research | 11-hour deepsleep test evidence |
