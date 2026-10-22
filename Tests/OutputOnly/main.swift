import Foundation
import CoreAudio

func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                               mElement: kAudioObjectPropertyElementMain)
}
func list(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
    var a = address(selector)
    var bytes: UInt32 = 0
    precondition(AudioObjectGetPropertyDataSize(object, &a, 0, nil, &bytes) == noErr)
    var values = [AudioObjectID](repeating: 0, count: Int(bytes) / 4)
    precondition(AudioObjectGetPropertyData(object, &a, 0, nil, &bytes, &values) == noErr)
    return values
}
func scalar(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
    var a = address(selector)
    var value: UInt32 = 0
    var bytes: UInt32 = 4
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(object, &a, 0, nil, &bytes, $0)
    }
    precondition(status == noErr)
    return value
}
func name(_ object: AudioObjectID) -> String {
    var a = address(kAudioObjectPropertyName)
    var value: CFString = "" as CFString
    var bytes = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(object, &a, 0, nil, &bytes, $0)
    }
    precondition(status == noErr)
    return value as String
}
let system = AudioObjectID(kAudioObjectSystemObject)
guard let device = list(system, kAudioHardwarePropertyDevices).first(where: { name($0) == "vRemoteDr 2ch" }) else {
    fatalError("Official driver unavailable; no settings or driver will be changed")
}
var proc: AudioDeviceIOProcID?
// Silence only: no physical microphone, BLE, Fn events, or input buffers read.
precondition(AudioDeviceCreateIOProcIDWithBlock(&proc, device, nil) { _, _, _, output, _ in
    for buffer in UnsafeMutableAudioBufferListPointer(output) {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
    }
} == noErr)
let ioProc = proc!
defer { AudioDeviceDestroyIOProcID(device, ioProc) }
let configured = OutputOnlyIOProc.disableInput(device: device, ioProc: ioProc)
print("input stream configuration OSStatus=\(configured)")
precondition(configured == noErr)
precondition(AudioDeviceStart(device, ioProc) == noErr)
defer { AudioDeviceStop(device, ioProc) }
Thread.sleep(forTimeInterval: 0.8)
guard let process = list(system, kAudioHardwarePropertyProcessObjectList).first(where: {
    scalar($0, kAudioProcessPropertyPID) == UInt32(ProcessInfo.processInfo.processIdentifier)
}) else { fatalError("CoreAudio process not found") }
let input = scalar(process, kAudioProcessPropertyIsRunningInput)
let output = scalar(process, kAudioProcessPropertyIsRunningOutput)
print("own process: input=\(input), output=\(output)")
precondition(input == 0 && output == 1, "Driver still reports capture; do not claim privacy indicator fixed")
print("PASS: official driver output remains running with no input for this IOProc")
