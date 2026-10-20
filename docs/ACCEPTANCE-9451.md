# 9451 voice acceptance — 2026-10-21

**Result: the complete independent App passes the scoped voice integration
gate using the official `vRemoteDr 2ch` channel. After explicit user approval,
the reviewed Release App was installed and passed a separate short/hold voice
smoke test.**

Baseline: upstream `2d906f32b8fc06f98d998b1343d995e7ffed1840`.
Remote: Google TV Remote, `18D1:9451`, model ZTKA-IR57, firmware 26.5.
The previous experiment was inventoried and reused, not rewritten.

## Builds and regression checks

- Complete Debug and Release Apps build successfully with the existing macOS
  26.5 SDK, selected for each build command only. Both ad-hoc signatures verify.
- **61 PASS checks**: identity 6, trigger 7, recorder 1, isolated preferences 4,
  existing ATVV regression groups 3, session coordinator checks 40.
- The trigger tests preserve Option and unselected legacy Fn behavior, cover
  Fn release idempotence and configuration changes. Session checks cover last
  remote disconnection and normal shutdown.
- No ATVV protocol, ADPCM decoder, 9450 HID map, X6 HID map or AudioPipe source
  changes. The software's default output remains the official device.
- Physical testing used the **complete Debug App**, not the earlier replacement
  harness. The Release App subsequently passed the installed-version smoke test
  recorded below. The development-only storage lock and focus command were
  subsequently verified by rebuilding and rerunning all 61 checks; the voice,
  protocol, decoder and trigger implementation remained identical.

## Actual hardware results

Times below use Asia/Shanghai (+0800).

| Case | Observed result |
|---|---|
| Identity/handshake | Connected-peripheral retrieval found the remote; PnP confirmed 9451; ATVV v1.0, ADPCM 16 kHz, HTT, 240-byte frames negotiated |
| Official driver | Explicit 2.5-second 997 Hz loopback passed: peak 0.05, RMS about 0.0352; device stop/destroy returned 0 |
| Short toggle, 03:16:55–03:16:59 | Physical taps about 0.163/0.238 s; Fn held between taps, released on finish; actual committed text in the App window |
| Long hold, 03:17:05–03:17:17 | Physical hold 11.867 s; 395 frames, 189,600 samples / 11.85 s decoded audio; release ended capture and committed text |
| Continuous voice, 03:17:59–03:18:41 | Persistent-stream WAV contains 1,370 ATVV frames / 657,600 samples / **41.10 s**; actual text committed at 03:18:43; user confirmed complete output and normal ending |
| Normal idle wake | No voice gesture from 03:20:24 until 03:24:09, about **3 min 45 s**; voice started and the idle-test sentence was committed at 03:24:15 |
| Exit while recording | A new Fn DOWN at 03:24:21 was followed by App termination at 03:24:22; Fn UP logged, route closed, IOProc stop/destroy both 0; an independent post-exit snapshot found Doubao inactive; user confirmed normal behavior |

For accepted speech cases, CoreAudio reported **Doubao capturing `vRemoteDr
2ch`**, while the test App's Mac microphone input was disabled. An independent
45.003-second Float32 recording of the official virtual input contained real
audio (RMS about 0.2043). These observations distinguish remote audio from the
USB camera or Mac microphone.

The controlled 41.10-second source WAV has a valid finalized header, 1,315,244
bytes, PCM peak 11,199, RMS about 831.5 and zero full-scale source samples.
Additional local recordings exist but are not used to infer further committed
text. The inherited AudioPipe gain remains 10× and limits its output: about
0.59% of samples in the independent virtual-input recording reached the
limiting threshold. No Google-specific loudness calibration was added.

## Scope and limitations

- Idle recovery above occurred while BLE remained connected. It does **not**
  establish automatic reconnection after link loss or long sleep.
- The earlier battery/reset/re-pair recovery failure remains a separate known
  issue. This integration did not remove batteries, reset Home, re-pair, modify
  pairing records or change Mac Bluetooth configuration.
- Earlier physical power-loss cleanup passed in the experiment; this round
  verifies disconnect cleanup with regression checks and real App-exit cleanup.
- This is a short controlled stability sample, not an hours-long soak test or
  proof of zero dropped packets. No 9450 or X6 hardware was available for a new
  physical regression; their existing session tests pass.
- The user explicitly approved switching **only Doubao's own microphone
  selection** to the official virtual device. That was the only third-party
  configuration change made in this round. One-time UI-selection helpers were
  removed from the delivered App/source; it does not automate Doubao settings.
- System default input/output remained MiRemoteV 2ch / FiiO K5 Pro. There is no
  runtime dependency on MiRemoteV: the App binds directly to vRemoteDr 2ch.

## Preservation and next action

The original experiment's 175 inventoried source, test, evidence and binary
files are unchanged. Hashes of 13 protected installed-App/preference/driver/
Bluetooth-preference files matched their pre-test values before installation.
This checks the listed files, not every system file or database. No driver,
privacy permission or global toolchain was replaced. Independent test processes
were stopped; after approved installation only the installed App is running.

Raw logs, transcripts, recordings, UUIDs, configuration snapshots and artifact
hashes remain local under `.local`; they are excluded from Git. This sanitized
report is the only hardware-evidence summary intended for the fork.

The [installation and executable rollback](INSTALL-9451.md) procedure preserves
the existing driver and data. Build and upstream synchronization instructions are
in [the development guide](GOOGLE-TV-9451.md).

## Approved Release installation and smoke test

The user explicitly approved App-only installation after reviewing the earlier
results. The original App was completely backed up and verified before swapping
`/Applications/vRemote.app`. The source binary SHA-256 and installed binary
SHA-256 both equal:

```text
b3edb8766212d78272ad08cb8c7bee025001eb5811a5fe177024a8094394c8fa
```

The original backup binary retains its previously recorded SHA-256. Backup
locations, old preferences and an executable rollback entry remain private in
`.local/backups`; they are not uploaded. Installation initially encountered
root-only readable resources and root-owned App rename restrictions. The
script now uses scoped macOS administrator authorization for those operations;
it never changes permissions on the old installed source. No swap occurred
until a complete verified backup existed. Unused staging files were moved into
the private backup directory.

The installed App's own preferences now select Fn, Fn hold enabled, remote
input enabled and Mac input disabled for verified remote-only operation. Existing
other preferences and application data are retained. No driver, Bluetooth,
privacy or default-device configuration was changed during installation.

At 03:33:24 the installed process bound the official output and confirmed 9451;
capability negotiation completed at 03:33:25. At 03:34:21–03:34:25, two physical
taps (0.117/0.211 s) started and ended recognition. At 03:34:28–03:34:33, a
4.816-second hold produced 160 frames / 76,800 decoded samples and released Fn
on the remote stop edge. CoreAudio reported Doubao capturing **vRemoteDr 2ch**
for both cases and inactive afterward. The TextEdit target saved the actual
short/hold test sentences, and the user confirmed both passed. A separate
post-test snapshot also found Doubao inactive.

The final protected-file check found only the three expected changes: the App
binary, its Info.plist and vRemoter's own preference plist. Driver and Bluetooth
preference hashes remain unchanged. The installed App is left running for use;
rollback remains available after quitting it normally.
