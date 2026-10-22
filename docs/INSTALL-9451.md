# Reviewed App installation and rollback

This is a plan and an executable procedure, not permission to install.
The installed App is left untouched until the user approves the acceptance
report and the specific replacement artifact.

## Before approval

Build the complete debug and release Apps, run the regression suite and verify
actual remote-to-`vRemoteDr 2ch`-to-Doubao output. Inspect the signed release
artifact and record its SHA-256 and Git commit in the local acceptance report.
No PKG, HAL-driver installation, TCC modification or Bluetooth repair is needed.

For the reviewed App-only local DMG, use:

```sh
VREMOTER_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  scripts/build-local-dmg.sh
```

This builds the Release App, gives it a custom patch revision separate from the
official base version, and packages `vRemote.app` with installation instructions.
The companion manifest records the source commit and App/DMG SHA-256 values.
It never installs or launches the App, runs a driver installer or changes settings.
Use the existing reviewed swap script after approval rather than overwriting the
installed App without a verified backup. Ordinary Release launches use existing
preferences; the debug validation window and mandatory isolated profile are absent.

The debug text window is omitted from release. Record separately which binary
received hardware testing; a successful release build is not itself a hardware
test. Current hardware findings are in `ACCEPTANCE-9451.md`.

## After explicit approval

1. Gracefully quit both the development and installed Apps. A held Fn must be
   released by normal cleanup before replacing files.
2. Run the prepared script, passing the reviewed release artifact:

   ```sh
   scripts/swap-reviewed-app.sh --approved "$PWD/dist/release/vRemote9451.app"
   ```

   The script first copies and verifies the existing App in a timestamped,
   Git-ignored `.local/backups` directory. It saves a copy of the App's existing
   preference plist for reference. It stages the reviewed source, verifies it,
   retains the original installed bundle and swaps the App into
   `/Applications/vRemote.app`. It does not start the App automatically.
   macOS administrator authorization is used for the staged replacement.
   A writable `/Applications` directory is not sufficient to rename every
   root-owned installed App. If old resources are root-only readable, a scoped
   administrator-authorized copy is also used; ownership is adjusted only on
   the user's backup, never on the installed source.

3. Launch `/Applications/vRemote.app` normally, without test environment variables.
   Existing application data and preferences are retained. In the console select
   Fn and enable **豆包使用按住 Fn 录音** to match the already configured Doubao
   hold shortcut. These are vRemoter-only settings. Preserve the user's other
   choices; remote-only input is recommended for the microphone-source check.
4. Confirm the output driver is the existing `vRemoteDr 2ch`, Doubao actually
   captures it, and a short press/stop produces text. Verify a long press release
   and normal App quit as the installed-version smoke test.

The script prints the exact backup and rollback command. Its `--approved`
argument is a deliberate operator acknowledgment; it does not replace getting
the user's approval in the conversation.

## Executable rollback

Quit the App normally and pass the previous backup as the reviewed source:

```sh
scripts/swap-reviewed-app.sh --approved "/absolute/path/to/.local/backups/TIMESTAMP/vRemote.app"
```

This uses the same staged swap and preserves a backup of the version being
replaced. It restores the old App bundle without touching the existing HAL
driver, pairing records, privacy permissions, default audio devices or Doubao
configuration. The old App ignores the new optional Fn preference. If reverting
vRemoter's own trigger choice is desired, change it through the App console;
the script does not overwrite live preferences or call `defaults import`.

Capabilities after rollback depend on the chosen backup. An original upstream
App lacks the custom 9451 support; the previously accepted 9451 build retains
voice support but also its original idle microphone indicator behavior.
The original experimental workspace remains available throughout.

The user explicitly approved selecting `vRemoteDr 2ch` inside Doubao during
acceptance. That selection persists independently of replacing or rolling back
vRemoter; the rollback script does not change another application's settings.
