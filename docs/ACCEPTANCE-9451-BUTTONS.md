# 9451 ordinary-button acceptance — 2026-10-23

Baseline: current `wasteful-ladybug` worktree, containing accepted merge
`768035e`; target `feat/google-tv-9451-voice` also pointed to that commit.
Both worktrees were clean before this change. No baseline merge was necessary.

## Observed HID format

The actual `18D1:9451` device exposes a keyboard array (report 1, six slots)
and a consumer array (report 2, two slots). IOHID delivered the report ID prefix:

- Report 2 down: `02 ss 00`; release: `02 00 00`.
- Report 1 volume down: `01 ss 00 00 00 00 00`; release: `01 00 00 00 00 00 00`.
- These bytes are array selectors, not 9450 mapping IDs or literal HID usages.

The first capture was superseded at the user's request. The new capture plus
one short supplementary capture established all twelve selectors below. Left
was absent from the replacement capture and was confirmed in the supplement.

| Physical key | Report / selector | Existing mapping ID |
|---|---|---|
| Up | 2 / 01 | 03 |
| Down | 2 / 02 | 04 |
| Left | 2 / 03 | 05 |
| Right | 2 / 04 | 06 |
| Select | 2 / 05 | 07 |
| Back | 2 / 06 | 0B |
| Home | 2 / 07 | 0A |
| Mute | 2 / 09 | 08 |
| YouTube | 2 / 0A | 0E |
| Netflix | 2 / 0B | 0F |
| Volume Up | 1 / 01 | 0C |
| Volume Down | 1 / 02 | 0D |

Voice remains on ATVV. Power and Input were not sampled or enabled in the
9451 parser; no IR, firmware or pairing changes were attempted. The saved
9450 Power/Input settings remain intact.

## Implementation and boundary

The existing Chromecast mapping UI, identifiers, storage and event sender are
reused without migration/reset. Independent model managers keep 9450's old
open mode and parser; 9451 uses its observed arrays and per-report key state.
Stop, mapping-disable and removal release outstanding keys.

A candidate that simply extended the existing exclusive manager reproduced
`0xE00002C1` (`kIOReturnNotPrivileged`). The actual complete App already had
accessibility access. Apple's [IOHID implementation](https://github.com/apple-oss-distributions/IOHIDFamily/blob/main/IOHIDFamily/IOHIDLibUserClient.cpp)
requires privilege to seize keyboard devices. No permission or privilege change
was made. 9451 now opens normally; its observed native Mute/Volume events are
filtered through the App's existing event tap. Generated media events carry the
same synthetic marker as generated keyboard events.

Filtering is limited to the matching media key for 150 ms after a HID edge and
native repeats while that key remains held. CGEventTap does not identify the
source device: another device's identical media key at the same instant can
also be filtered. No claim is made for that simultaneous-input case. If the
existing event tap is unavailable, native media behavior is retained without
posting a duplicate mapped action. Ordinary keys and unrelated media events
are outside this gate. No new helper, driver, entitlement or system setting
is introduced.

## Scoped results

- `scripts/run-button-tests.sh`: **23 PASS**, covering the twelve observed
  down/up pairs, duplicate suppression, independent report state, array slots,
  exact-length framing, malformed/unknown reports, cleanup, 9450 compatibility
  and native media gate matching/expiry.
- Existing trigger checks: **7 PASS**.
- Complete candidate's voice-session self-test: **40 PASS**, zero failures.
- Complete independent Debug and Release Apps: builds and signature verification pass.
  Hardware-tested executable SHA-256:
  `a8875e8c045d382005fc582fb35359409371b294d0627f6983bfeabb3bbdf32f`.
- With remote voice input **off** and Mac input **off**, all twelve physical
  keys produced matching mapped DOWN/UP events. The validation text window
  received their keyboard events. Directions moved the text caret through
  offsets `17 → 5 → 17 → 16 → 17` for Up/Down/Left/Right. No mouse movement
  was implemented. A separate held Right produced one DOWN and one UP at
  approximately 00:08:42–00:08:44 (+0800), with no later mapped event before
  the next test.
- Escape/Home/End/Page keys and whitespace were not visually obvious in the
  short text target. After the user reported this, only those seven keys were
  retested with visible custom numeric shortcuts. Back/Home/YouTube/Mute/
  Netflix/Volume Up/Volume Down committed `1243567`, each with a matching UP.
  The user confirmed all seven displayed correctly, with 4/3 physically pressed
  in reversed order. Mute and Volume Down native edges were logged as filtered;
  Volume Up produced the mapped key but no native event in this sample.

- Voice short tap, **00:12:28–00:12:33 (+0800)**: two taps measured
  0.086/0.146 s. Fn stayed down between taps, then released; the validation
  window received actual committed text. Doubao captured `vRemoteDr 2ch`
  and became inactive after stopping.
- Voice hold, **00:12:36–00:12:40**: physical hold 3.629 s, 120 frames /
  57,600 decoded samples. The release edge posted Fn UP, stopped the route
  and returned Doubao to inactive; actual text was committed. The user
  confirmed both voice cases produced text and stopped, with no recording
  after release.

The Release package is a separate build, not the Debug binary used for hardware
testing. Its source commit and hashes are recorded in the local DMG manifest.

## Preservation

Installed App binary/Info.plist and official preference-file hashes still
match the pre-test snapshot. Existing saved mappings were copied read-only
into private evidence, then only the independent test profile was customized.
The installed App was stopped normally before testing. Raw reports, event logs,
transcripts, settings and binaries remain in ignored local directories.

No Bluetooth, pairing, privacy, default audio, driver, firmware or third-party
configuration was changed. ATVV, ADPCM, Fn control and idle-audio implementation
were retained. No new 9450/X6 physical hardware test, pairing cycle, battery
removal or stress test was performed.
