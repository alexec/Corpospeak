import AVFoundation

/// The shared audio session on iOS: microphone and playback share it, and playback goes to
/// the loudspeaker rather than the earpiece. The Mac has nothing to configure.
enum AudioSession {
    static func activate() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        #endif
    }
}
