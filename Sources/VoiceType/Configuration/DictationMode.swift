import Foundation

enum DictationMode: String, CaseIterable, Identifiable {
    case fast
    case accurate
    case polished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fast:
            "Fast"
        case .accurate:
            "Accurate"
        case .polished:
            "Polished"
        }
    }

    var detail: String {
        switch self {
        case .fast:
            "Lowest-latency live transcription."
        case .accurate:
            "More speech context before finalizing."
        case .polished:
            "Transcribe, then clean punctuation and formatting."
        }
    }

    var realtimeModel: String {
        transcriptionModel
    }

    var transcriptionModel: String {
        "gpt-realtime-whisper"
    }

    var silenceDurationMilliseconds: Int {
        switch self {
        case .fast:
            500
        case .accurate, .polished:
            900
        }
    }

    var polishAfterTranscription: Bool {
        self == .polished
    }
}
