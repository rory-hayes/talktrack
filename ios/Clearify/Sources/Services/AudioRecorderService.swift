import AVFoundation
import Foundation

@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(to fileURL: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        elapsed = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsed = self.recorder?.currentTime ?? 0
            }
        }
    }

    func stopRecording() throws -> TimeInterval {
        guard let recorder else {
            throw RecordingError.noActiveRecording
        }

        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        return recorder.currentTime
    }
}

enum RecordingError: LocalizedError {
    case noActiveRecording

    var errorDescription: String? {
        switch self {
        case .noActiveRecording:
            return "No active recording to stop."
        }
    }
}
