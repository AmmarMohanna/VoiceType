import Foundation

enum DictationMode: String {
    case fast

    var transcriptionModel: String {
        "gpt-realtime-whisper"
    }
}
