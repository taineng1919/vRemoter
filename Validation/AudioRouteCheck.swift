// Explicit device IO only. Never changes default devices, formats or settings.
import CoreAudio
import Foundation

func uintProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
    var address = AudioObjectPropertyAddress(mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
    precondition(status == noErr, "property error \(status)")
    return value
}
func deviceName(_ id: AudioObjectID) -> String {
    var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var value: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return "?" }
    return value as String
}
var listAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var listSize: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &listSize)
var devices = [AudioDeviceID](repeating: 0, count: Int(listSize) / MemoryLayout<AudioDeviceID>.size)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &listAddress, 0, nil, &listSize, &devices)
let defaultsBefore = [kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDefaultOutputDevice]
    .map { uintProperty(AudioObjectID(kAudioObjectSystemObject), $0) }
print("DEFAULTS \(defaultsBefore.map(deviceName))")
for id in devices { print("DEVICE \(id) \(deviceName(id))") }
guard let device = devices.first(where: { deviceName($0) == "vRemoteDr 2ch" }) else {
    fputs("FAIL: official virtual device missing\n", stderr); exit(1)
}
let recordOnly = CommandLine.arguments.contains("--record")
let seconds = recordOnly ? 45.0 : 2.5
let lock = NSLock()
var phase = 0.0
var samples = [Float]()
samples.reserveCapacity(Int(seconds * 48_000 * 2.5))
var callbacks = 0
var ioProc: AudioDeviceIOProcID?
let create = AudioDeviceCreateIOProcIDWithBlock(&ioProc, device, nil) { _, input, _, output, _ in
    lock.lock()
    defer { lock.unlock() }
    callbacks += 1
    for buffer in UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)) {
        if let data = buffer.mData?.assumingMemoryBound(to: Float.self) {
            samples.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(buffer.mDataByteSize) / 4))
        }
    }
    for buffer in UnsafeMutableAudioBufferListPointer(output) {
        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
        let channels = max(1, Int(buffer.mNumberChannels))
        for frame in 0..<(Int(buffer.mDataByteSize) / 4 / channels) {
            let value: Float = recordOnly ? 0 : Float(sin(phase) * 0.05)
            phase += 2 * .pi * 997 / 48_000
            for channel in 0..<channels { data[frame * channels + channel] = value }
        }
    }
}
guard create == noErr, let ioProc else { fputs("FAIL: create=\(create)\n", stderr); exit(1) }
let start = AudioDeviceStart(device, ioProc)
guard start == noErr else {
    AudioDeviceDestroyIOProcID(device, ioProc)
    fputs("FAIL: start=\(start)\n", stderr); exit(1)
}
print("START device=\(deviceName(device)) recordOnly=\(recordOnly) seconds=\(seconds)")
fflush(stdout)
RunLoop.current.run(until: Date().addingTimeInterval(seconds))
let stop = AudioDeviceStop(device, ioProc)
let destroy = AudioDeviceDestroyIOProcID(device, ioProc)
lock.lock()
let peak = samples.map(abs).max() ?? 0
let rms = samples.isEmpty ? 0 : sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
if let index = CommandLine.arguments.firstIndex(of: "--output"), index + 1 < CommandLine.arguments.count {
    try samples.withUnsafeBytes { try Data($0).write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
}
print("RESULT callbacks=\(callbacks) floatSamples=\(samples.count) peak=\(peak) rms=\(rms) stop=\(stop) destroy=\(destroy)")
lock.unlock()
let defaultsAfter = [kAudioHardwarePropertyDefaultInputDevice, kAudioHardwarePropertyDefaultOutputDevice]
    .map { uintProperty(AudioObjectID(kAudioObjectSystemObject), $0) }
guard defaultsAfter == defaultsBefore else { fputs("FAIL: defaults changed externally\n", stderr); exit(1) }
if !recordOnly {
    guard peak > 0.04, peak < 0.06, rms > 0.025, rms < 0.04 else {
        fputs("FAIL: virtual loopback signal missing or unexpected\n", stderr); exit(1)
    }
}
print("PASS: explicit official-device IO, system defaults unchanged")
