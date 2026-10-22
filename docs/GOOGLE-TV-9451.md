# Google TV Remote 9451 voice development

This fork adds voice support for Google VID `18D1`, PID `9451`, alongside
`9450` and X6. It reuses the existing ATVV implementation, ADPCM decoder and
tap/hold session coordinator. The ordinary-button extension reuses the existing
Chromecast mapping profile; see [button acceptance](ACCEPTANCE-9451-BUTTONS.md).

## Changes and configuration

- Google devices are located using connected ATVV/HID peripherals and read-only
  IORegistry identity, with cached UUID and name hints as fallbacks. The GATT
  PnP ID must confirm a supported vendor/product before ATVV is used.
- Google subscribes only to ATVV voice characteristics. GET_CAPS waits for both
  audio and control notifications. X6 keeps its existing discovery path.
- The console still offers the original modifier choices. With Fn selected,
  **Doubao uses hold-to-talk Fn** enables the `functionHoldEnabled` preference.
  Its default is false, preserving existing toggle configurations.
- With that option enabled, a remote tap starts a synthetic Fn hold and the
  next tap releases it; a physical long press releases on the remote's stop
  edge. Existing gesture timing and keep-alive code are reused.
- Session cleanup, loss of the last active remote, normal App termination,
  SIGTERM and SIGINT release this App's synthetic Fn. SIGKILL or an OS crash
  cannot execute application cleanup.
- Output remains **vRemoteDr 2ch**. No MiRemoteV dependency or output-device
  override is required. Do not change macOS default devices to run these tests.

The preference affects only this App's generated Fn events; it does not change
Doubao's shortcut configuration. Physical keyboard events continue to pass
through the existing observer.

## Build and test a complete independent App

```sh
scripts/build-development-app.sh
scripts/run-voice-tests.sh
scripts/launch-development-app.sh
```

On a machine whose default SDK is missing SwiftUI macro plugins, select an
already installed SDK for this command only, for example:

```sh
VREMOTER_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  scripts/build-development-app.sh
```

No global SDK selection is changed. The script uses SwiftPM's native build
backend as a compatibility workaround; that backend is deprecated in the local
toolchain and can be removed when the default backend builds successfully.

The debug App is `dist/debug/vRemote9451.app`. It contains the complete console,
production bridges and audio/session code. A debug-only text window records
actual input-method text commits; it never injects recognition results.

The launcher creates `.local/runtime/Preferences.plist` on first use, selecting
Fn hold, remote input on, Mac input off, diagnostics on and update checks off.
It never overwrites an existing test profile. All test configuration, UUIDs,
logs, recordings and transcripts remain in that workspace. The profile is
selected with the process-local `VREMOTER_DATA_ROOT` variable. Normal launches
retain the existing application preferences and storage paths.

Do not launch the debug App by double-clicking without the development launcher:
without its profile environment it uses the normal application data paths.
The launcher and App reject parallel instances with the same application identity.
The bundle identifier/designated requirement are retained to use existing
permissions. No privacy permission is granted or reset by the scripts.

The launcher does **not** change Doubao's selected microphone. Verify it is
`vRemoteDr 2ch` before counting text output as a successful remote test. Changing
that selection requires the user's explicit approval.

For an independent official-driver loopback check:

```sh
mkdir -p .local/acceptance .build/module-cache
swiftc -module-cache-path .build/module-cache Validation/AudioRouteCheck.swift \
  -o .local/acceptance/audio-route-check
.local/acceptance/audio-route-check
# Record only the explicit virtual input for 45 seconds, without a test tone:
.local/acceptance/audio-route-check --record \
  --output .local/acceptance/official-input.float32
```

The raw recording is 48 kHz stereo Float32. No default device, sample rate,
driver or system configuration is changed. Keep all recordings private.

For a release build (build only; never installs):

```sh
VREMOTER_CONFIGURATION=release scripts/build-development-app.sh
```

It produces `dist/release/vRemote9451.app`, with test telemetry disabled and
the debug text window omitted. The Fn option remains available in the console.

## Hardware acceptance

1. Confirm `18D1:9451`, ATVV v1.0, ADPCM 16 kHz, 240-byte frames and official
   output binding in the App log.
2. With Mac input disabled, verify short-tap start/stop and long-press release.
   Require actual committed text and Doubao's active device `vRemoteDr 2ch`.
3. Speak continuously for about 30 seconds, stop and inspect saved PCM/WAV,
   capture-device state and actual text.
4. Leave the remote idle with the App running, then verify the next voice
   gesture. Record the idle duration and whether BLE actually disconnected.
5. Keep occasional macOS/remote disconnection recovery separate. Do not repeatedly
   remove batteries, reset Home, re-pair or alter Bluetooth settings for this gate.

Unit tests cover both Google PIDs, rejection of unrelated identities, legacy
toggle behavior, held Fn lifecycle/configuration changes, session shutdown and
disconnect cleanup, WAV finalization, isolated preferences and existing ATVV
regressions. X6/9450 session regression tests are not hardware regression tests;
those devices still require physical checks when available.

## Installation and rollback

### Ordinary button mappings

9450 and 9451 share the existing Chromecast mapping UI, preference keys and
mapping IDs. No migration or reset is performed. Enable the Chromecast mapping
switch; voice input may remain off. Verified 9451 keys are the four directions,
Select, Back, Home, Mute, YouTube, Netflix and Volume Up/Down. Power/Input were
not sampled and are not enabled by the 9451 parser. Their existing saved mappings
remain intact for 9450.

9451 is not wire-compatible with 9450: report 2 contains two consumer-array
selectors, while report 1 contains six keyboard-array selectors for volume.
The parser accepts the observed report-ID prefix and exact-length prefix-free
payloads, tracks each report independently and releases held mappings on stop,
disable or device removal. 9450 retains its existing report-1 interpretation.

macOS rejects unprivileged exclusive opens of 9451's keyboard interface. A
separate non-exclusive manager handles 9451; the 9450 manager retains its old
exclusive behavior. The existing accessibility event tap filters matching native
volume/mute events within 150 ms of a raw edge, plus native repeat while that
remote key remains held. Synthetic mapping events are marked and pass through.
Ordinary keyboard events and unrelated media keys pass. CGEventTap cannot
identify the source device: an identical media key from another device at the
same instant can also be filtered. If the existing event tap is unavailable,
9451 media keys retain native behavior and do not emit a second mapped action;
no additional permissions, privileged helper or system configuration are added.

The direction targets synthesize keyboard arrows to the focused App, moving a
text caret or interface selection. They do not move the mouse pointer.

```sh
scripts/run-button-tests.sh
```

Only scoped button, trigger and voice-session checks are needed for this change.
Actual hardware findings and limits are in [button acceptance](ACCEPTANCE-9451-BUTTONS.md).

Do not install until the user reviews actual acceptance results and approves.
Use the separate [installation/rollback procedure](INSTALL-9451.md). Keep the
existing HAL driver and application preferences; a full PKG is unnecessary.

## Updating from the original repository

`origin` is the user's fork; `upstream` is VincentKingHsu/vRemoter. Local `main`
tracks `upstream/main`; the feature branch tracks the fork after its first push.
Do not push this work to either main or open upstream issues/PRs automatically.

For a fresh clone, use the fork and configure the original repository explicitly:

```sh
git clone https://github.com/taineng1919/vRemoter.git
cd vRemoter
git remote add upstream https://github.com/VincentKingHsu/vRemoter.git
git fetch upstream
git branch --set-upstream-to=upstream/main main
git switch --track origin/feat/google-tv-9451-voice
git config pull.ff only
```

```sh
git status --short                 # commit or stash your changes first
git fetch upstream
git switch main
git merge --ff-only upstream/main
git switch feat/google-tv-9451-voice
git merge upstream/main            # retain published feature history; no force push
# Resolve conflicts, then rebuild and repeat unit + hardware acceptance.
git push origin feat/google-tv-9451-voice
```

Device identity/ATVV compatibility and WAV finalization are separate commits
from the optional Fn preference and independent development tooling, so generic
fixes can be reviewed or cherry-picked separately. Do not merge the old
experimental working directory as a second implementation.

Before every push, inspect `git diff --cached` and `git ls-files`; `.local`,
builds, Apps, logs, recordings, UUID caches and validation results are excluded.
Only source code, tests and sanitized documentation should enter Git history.
