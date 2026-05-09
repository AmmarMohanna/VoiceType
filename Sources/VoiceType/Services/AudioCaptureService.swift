import AVFoundation
import Foundation

enum AudioCaptureError: LocalizedError {
    case microphoneDenied
    case missingInputFormat
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone permission is denied. Enable it in System Settings."
        case .missingInputFormat:
            "Could not read the microphone input format."
        case .converterUnavailable:
            "Could not create the 24 kHz PCM converter."
        }
    }
}

final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: true
    )

    private var converter: AVAudioConverter?
    private var onAudio: ((Data) -> Void)?

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

    func start(onAudio: @escaping (Data) -> Void) throws {
        guard let outputFormat else {
            throw AudioCaptureError.missingInputFormat
        }

        self.onAudio = onAudio

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioCaptureError.missingInputFormat
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioCaptureError.converterUnavailable
        }
        self.converter = converter

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.convertAndEmit(buffer, inputFormat: inputFormat, outputFormat: outputFormat)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        onAudio = nil
    }

    private func convertAndEmit(
        _ inputBuffer: AVAudioPCMBuffer,
        inputFormat: AVAudioFormat,
        outputFormat: AVAudioFormat
    ) {
        guard let converter else {
            return
        }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 32
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: max(outputCapacity, 1)
        ) else {
            return
        }

        var didProvideInput = false
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            status.pointee = .haveData
            return inputBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        guard error == nil, outputBuffer.frameLength > 0 else {
            return
        }

        let audioBuffer = outputBuffer.audioBufferList.pointee.mBuffers
        guard let dataPointer = audioBuffer.mData, audioBuffer.mDataByteSize > 0 else {
            return
        }

        onAudio?(Data(bytes: dataPointer, count: Int(audioBuffer.mDataByteSize)))
    }
}
