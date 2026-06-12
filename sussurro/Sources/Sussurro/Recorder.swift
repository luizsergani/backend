import AVFoundation

enum RecorderError: LocalizedError {
    case noInput

    var errorDescription: String? {
        switch self {
        case .noInput:
            return "Nenhum dispositivo de entrada de áudio disponível."
        }
    }
}

/// Grava o microfone e salva um WAV mono 16 kHz / 16 bits,
/// que é exatamente o formato que o whisper.cpp espera.
final class Recorder {
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "sussurro.recorder")
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false
    )!

    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var url: URL?
    private var framesWritten: AVAudioFramePosition = 0

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sussurro-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(
            forWriting: url, settings: settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInput
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecorderError.noInput
        }

        queue.sync {
            self.file = file
            self.converter = converter
            self.url = url
            self.framesWritten = 0
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.queue.async { self?.write(buffer) }
        }
        engine.prepare()
        try engine.start()
    }

    /// Para a gravação e devolve a URL do WAV, ou nil se não há áudio suficiente.
    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        var result: URL?
        queue.sync {
            file = nil  // fecha o arquivo
            converter = nil
            // menos de meio segundo de áudio não vale a pena transcrever
            if framesWritten > 8000 {
                result = url
            } else if let url {
                try? FileManager.default.removeItem(at: url)
            }
            url = nil
        }
        return result
    }

    private func write(_ buffer: AVAudioPCMBuffer) {
        guard let file, let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        converter.convert(to: out, error: nil) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        guard out.frameLength > 0 else { return }
        do {
            try file.write(from: out)
            framesWritten += AVAudioFramePosition(out.frameLength)
        } catch {
            // melhor perder um buffer do que derrubar a gravação inteira
        }
    }
}
