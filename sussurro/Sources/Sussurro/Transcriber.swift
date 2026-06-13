import Foundation

enum TranscriberError: LocalizedError {
    case cliNotFound
    case modelNotFound(String)
    case failed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "O whisper-cli não foi encontrado.\n\nInstale com:\n  brew install whisper-cpp\n\nou rode o setup.sh do projeto."
        case .modelNotFound(let dir):
            return "Nenhum modelo Whisper encontrado em:\n\(dir)\n\nRode o setup.sh do projeto para baixar o modelo."
        case .failed(let code, let stderr):
            return "A transcrição falhou (código \(code)).\n\n\(stderr)"
        }
    }
}

/// Transcreve um WAV chamando o whisper-cli (whisper.cpp, via Homebrew).
struct Transcriber {
    static let modelsDirectory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Sussurro/models")

    func transcribe(wav: URL, language: String) throws -> String {
        let cli = try findCLI()
        let model = try findModel()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = [
            "-m", model,
            "-f", wav.path,
            "-l", language,
            "--no-timestamps",
            "--no-prints",
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8) ?? ""
            throw TranscriberError.failed(process.terminationStatus, message.suffix(500).description)
        }

        let raw = String(data: outData, encoding: .utf8) ?? ""
        return raw
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func findCLI() throws -> String {
        if let env = ProcessInfo.processInfo.environment["SUSSURRO_WHISPER"],
           FileManager.default.isExecutableFile(atPath: env) {
            return env
        }
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        throw TranscriberError.cliNotFound
    }

    private func findModel() throws -> String {
        if let env = ProcessInfo.processInfo.environment["SUSSURRO_MODEL"],
           FileManager.default.fileExists(atPath: env) {
            return env
        }
        let dir = Self.modelsDirectory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let models = files.filter { $0.hasPrefix("ggml-") && $0.hasSuffix(".bin") }
        guard !models.isEmpty else {
            throw TranscriberError.modelNotFound(dir.path)
        }
        // se houver mais de um modelo, prefere o de melhor qualidade
        let preference = ["large-v3-turbo", "large", "medium", "small", "base", "tiny"]
        let best = models.min { a, b in
            let ia = preference.firstIndex { a.contains($0) } ?? preference.count
            let ib = preference.firstIndex { b.contains($0) } ?? preference.count
            return ia < ib
        }!
        return dir.appendingPathComponent(best).path
    }
}
