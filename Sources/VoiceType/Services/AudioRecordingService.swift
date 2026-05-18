import AVFoundation
import Foundation

enum AudioRecordingError: LocalizedError {
    case microphoneDenied
    case alreadyRecording
    case couldNotStart
    case missingDocumentsDirectory

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone permission is denied. Enable it in System Settings."
        case .alreadyRecording:
            "Audio recording is already in progress."
        case .couldNotStart:
            "Could not start audio recording."
        case .missingDocumentsDirectory:
            "Could not find your Documents folder."
        }
    }
}

final class AudioRecordingService {
    private var recorder: AVAudioRecorder?
    private var activeURL: URL?

    func recordingDirectory() throws -> URL {
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw AudioRecordingError.missingDocumentsDirectory
        }

        return documentsURL.appendingPathComponent("VoiceType Recordings", isDirectory: true)
    }

    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start() async throws -> URL {
        guard recorder == nil else {
            throw AudioRecordingError.alreadyRecording
        }

        guard await requestPermission() else {
            throw AudioRecordingError.microphoneDenied
        }

        let directoryURL = try recordingDirectory()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let outputURL = directoryURL.appendingPathComponent(fileName())
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioRecordingError.couldNotStart
        }

        self.recorder = recorder
        activeURL = outputURL
        return outputURL
    }

    func stop() -> URL? {
        guard let recorder else {
            return activeURL
        }

        recorder.stop()
        self.recorder = nil

        let outputURL = activeURL
        activeURL = nil
        return outputURL
    }

    private func fileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "VoiceType Recording \(formatter.string(from: Date())).m4a"
    }
}
