import CoreAudio

/// Changes only this client's IOProc, never the device's global configuration.
enum OutputOnlyIOProc {
    static func disableInput(device: AudioDeviceID, ioProc: AudioDeviceIOProcID) -> OSStatus {
        var streams = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamBytes: UInt32 = 0
        let query = AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamBytes)
        guard query == noErr else { return query }
        let count = Int(streamBytes) / MemoryLayout<AudioStreamID>.size
        guard count > 0 else { return noErr }

        let bytes = MemoryLayout<AudioHardwareIOProcStreamUsage>.size
            + (count - 1) * MemoryLayout<UInt32>.size
        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: bytes, alignment: MemoryLayout<AudioHardwareIOProcStreamUsage>.alignment
        )
        defer { storage.deallocate() }
        storage.initializeMemory(as: UInt8.self, repeating: 0, count: bytes)
        let usage = storage.assumingMemoryBound(to: AudioHardwareIOProcStreamUsage.self)
        usage.pointee.mIOProc = unsafeBitCast(ioProc, to: UnsafeMutableRawPointer.self)
        usage.pointee.mNumberStreams = UInt32(count)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyIOProcStreamUsage,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(bytes), storage)
    }
}
