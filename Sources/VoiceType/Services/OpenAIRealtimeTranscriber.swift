import Foundation

enum RealtimeTranscriberError: LocalizedError {
    case missingAPIKey
    case missingWebSocket

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing."
        case .missingWebSocket:
            "Realtime WebSocket is not connected."
        }
    }
}

final class OpenAIRealtimeTranscriber {
    private let apiKey: String
    private let mode: DictationMode
    private let language: String
    private let onTranscript: @MainActor (String) -> Void
    private let onStatus: @MainActor (String) -> Void
    private let onError: @MainActor (String) -> Void

    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let sendGroup = DispatchGroup()
    private let audioByteLock = NSLock()
    private var sentAudioByteCount = 0
    private var itemOrder: [String] = []
    private var completedItems: [String: String] = [:]
    private var deltaItems: [String: String] = [:]

    init(
        apiKey: String,
        mode: DictationMode,
        language: String,
        onTranscript: @escaping @MainActor (String) -> Void,
        onStatus: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        self.apiKey = apiKey
        self.mode = mode
        self.language = language
        self.onTranscript = onTranscript
        self.onStatus = onStatus
        self.onError = onError
    }

    func connect() async throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RealtimeTranscriberError.missingAPIKey
        }

        let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("voice-type-local-mvp", forHTTPHeaderField: "OpenAI-Safety-Identifier")

        let webSocket = URLSession.shared.webSocketTask(with: request)
        self.webSocket = webSocket
        webSocket.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        try await sendJSON(sessionUpdateEvent())
        await MainActor.run {
            onStatus("Listening")
        }
    }

    func sendAudio(_ data: Data) {
        guard webSocket != nil, !data.isEmpty else {
            return
        }

        let event: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": data.base64EncodedString()
        ]

        audioByteLock.lock()
        sentAudioByteCount += data.count
        audioByteLock.unlock()

        sendGroup.enter()
        Task {
            defer { sendGroup.leave() }
            try? await sendJSON(event)
        }
    }

    func finishAndClose() async -> String {
        await waitForPendingAudioSends()

        guard capturedAudioDurationMilliseconds >= 100 else {
            close()
            return currentTranscript()
        }

        try? await sendJSON(["type": "input_audio_buffer.commit"])
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        close()
        return currentTranscript()
    }

    func close() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func sessionUpdateEvent() -> [String: Any] {
        var transcription: [String: Any] = [
            "model": mode.transcriptionModel
        ]

        let trimmedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLanguage.isEmpty {
            transcription["language"] = trimmedLanguage
        }

        return [
            "type": "session.update",
            "session": [
                "type": "transcription",
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24_000
                        ],
                        "noise_reduction": [
                            "type": "near_field"
                        ],
                        "transcription": transcription,
                        "turn_detection": NSNull()
                    ]
                ]
            ]
        ]
    }

    private var capturedAudioDurationMilliseconds: Double {
        audioByteLock.lock()
        let byteCount = sentAudioByteCount
        audioByteLock.unlock()

        // 24 kHz mono PCM16 = 48,000 bytes per second.
        return Double(byteCount) / 48_000.0 * 1_000.0
    }

    private func waitForPendingAudioSends() async {
        await withCheckedContinuation { continuation in
            sendGroup.notify(queue: .global(qos: .userInitiated)) {
                continuation.resume()
            }
        }
    }

    private func sendJSON(_ object: [String: Any]) async throws {
        guard let webSocket else {
            throw RealtimeTranscriberError.missingWebSocket
        }

        let data = try JSONSerialization.data(withJSONObject: object)
        let string = String(decoding: data, as: UTF8.self)
        try await webSocket.send(.string(string))
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            do {
                guard let webSocket else {
                    return
                }

                let message = try await webSocket.receive()
                switch message {
                case .string(let text):
                    await handle(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handle(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        onError(error.localizedDescription)
                    }
                }
                return
            }
        }
    }

    private func handle(_ text: String) async {
        #if DEBUG
        print("OpenAI event: \(text)")
        #endif

        guard let data = text.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else {
            return
        }

        switch type {
        case "input_audio_buffer.committed":
            if let itemID = event["item_id"] as? String {
                rememberItem(itemID)
            }
        case "conversation.item.input_audio_transcription.delta":
            guard let itemID = event["item_id"] as? String,
                  let delta = event["delta"] as? String else {
                return
            }
            rememberItem(itemID)
            deltaItems[itemID, default: ""] += delta
            await publishTranscript()
        case "conversation.item.input_audio_transcription.completed":
            guard let itemID = event["item_id"] as? String,
                  let transcript = event["transcript"] as? String else {
                return
            }
            rememberItem(itemID)
            completedItems[itemID] = transcript
            deltaItems[itemID] = nil
            await publishTranscript()
        case "error":
            let message = errorMessage(from: event)
            await MainActor.run {
                onError(message)
            }
        default:
            break
        }
    }

    private func rememberItem(_ itemID: String) {
        if !itemOrder.contains(itemID) {
            itemOrder.append(itemID)
        }
    }

    private func publishTranscript() async {
        let transcript = currentTranscript()
        await MainActor.run {
            onTranscript(transcript)
        }
    }

    private func currentTranscript() -> String {
        itemOrder
            .compactMap { itemID in
                completedItems[itemID] ?? deltaItems[itemID]
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func errorMessage(from event: [String: Any]) -> String {
        if let error = event["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }

        return "Realtime API error"
    }
}
