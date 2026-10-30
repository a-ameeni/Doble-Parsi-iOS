import Foundation
import AVFoundation

@MainActor
final class DubSession: ObservableObject {
    @Published var status = "آماده"
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var running = false
    private var socket: URLSessionWebSocketTask?
    private var task: Task<Void, Never>?
    private let engine = AVAudioEngine()
    private let speaker = AVAudioPlayerNode()
    private var reader: AVAssetReader?

    func start(url: URL, key: String, language: String, player: AVPlayer) {
        guard !running, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "کلید Gemini را وارد کنید."
            return
        }
        running = true
        status = "در حال اتصال…"
        sourceText = ""
        translatedText = ""
        task = Task {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                engine.attach(speaker)
                let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)!
                engine.connect(speaker, to: engine.mainMixerNode, format: format)
                try engine.start()
                speaker.play()
                var components = URLComponents(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent")!
                components.queryItems = [URLQueryItem(name: "key", value: key)]
                let webSocket = URLSession.shared.webSocketTask(with: components.url!)
                socket = webSocket
                webSocket.resume()
                try await send(["setup": ["model": "models/gemini-3.5-live-translate-preview", "generationConfig": ["responseModalities": ["AUDIO"], "translationConfig": ["targetLanguageCode": language, "echoTargetLanguage": true]], "inputAudioTranscription": [:], "outputAudioTranscription": [:], "sessionResumption": [:]]], on: webSocket)
                while !Task.isCancelled {
                    let message = try await webSocket.receive()
                    let object = try decode(message)
                    if let error = object["error"] as? [String: Any] { throw SessionError.server(error["message"] as? String ?? "خطای سرور") }
                    if object["setupComplete"] != nil || object["setup_complete"] != nil { break }
                }
                guard !Task.isCancelled else { return }
                status = "در حال دوبله"
                let receiveTask = Task { try await receive(on: webSocket) }
                do {
                    await player.seek(to: .zero)
                    player.play()
                    try await stream(url: url, on: webSocket)
                    status = "ارسال فایل تمام شد؛ در انتظار پاسخ…"
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    receiveTask.cancel()
                } catch {
                    receiveTask.cancel()
                    throw error
                }
                stop(player: player)
            } catch is CancellationError {
                stop(player: player)
            } catch {
                let message = error.localizedDescription
                stop(player: player)
                status = "خطا: \(message)"
            }
        }
    }

    func stop(player: AVPlayer) {
        task?.cancel()
        task = nil
        reader?.cancelReading()
        reader = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        player.pause()
        speaker.stop()
        engine.stop()
        if speaker.engine != nil { engine.detach(speaker) }
        running = false
        status = "متوقف شد"
    }

    private func send(_ object: [String: Any], on socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let text = String(data: data, encoding: .utf8) else { throw SessionError.invalidData }
        try await socket.send(.string(text))
    }

    private func decode(_ message: URLSessionWebSocketTask.Message) throws -> [String: Any] {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let bytes): data = bytes
        @unknown default: throw SessionError.invalidData
        }
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw SessionError.invalidData }
        return result
    }

    private func receive(on socket: URLSessionWebSocketTask) async throws {
        while !Task.isCancelled {
            let object = try decode(await socket.receive())
            if let error = object["error"] as? [String: Any] { throw SessionError.server(error["message"] as? String ?? "خطای سرور") }
            guard let content = (object["serverContent"] ?? object["server_content"]) as? [String: Any] else { continue }
            if let source = (content["inputTranscription"] ?? content["input_transcription"]) as? [String: Any], let text = source["text"] as? String { sourceText += text }
            if let translation = (content["outputTranscription"] ?? content["output_transcription"]) as? [String: Any], let text = translation["text"] as? String { translatedText += text }
            if content["interrupted"] as? Bool == true { speaker.stop(); speaker.play(); continue }
            guard let turn = (content["modelTurn"] ?? content["model_turn"]) as? [String: Any], let parts = turn["parts"] as? [[String: Any]] else { continue }
            for part in parts {
                guard let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any], let encoded = inline["data"] as? String, let data = Data(base64Encoded: encoded), !data.isEmpty else { continue }
                let frames = data.count / 2
                guard frames > 0, let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)), let destination = buffer.int16ChannelData?[0] else { continue }
                buffer.frameLength = AVAudioFrameCount(frames)
                data.withUnsafeBytes { bytes in if let base = bytes.baseAddress { memcpy(destination, base, frames * 2) } }
                speaker.scheduleBuffer(buffer, completionHandler: nil)
            }
        }
    }

    private func stream(url: URL, on socket: URLSessionWebSocketTask) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw SessionError.noAudio }
        let assetReader = try AVAssetReader(asset: asset)
        reader = assetReader
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard assetReader.canAdd(output) else { throw SessionError.noAudio }
        assetReader.add(output)
        guard assetReader.startReading() else { throw assetReader.error ?? SessionError.noAudio }
        while !Task.isCancelled, let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var data = Data(count: length)
            let result = data.withUnsafeMutableBytes { bytes in CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!) }
            guard result == kCMBlockBufferNoErr else { throw SessionError.invalidData }
            try await send(["realtimeInput": ["audio": ["data": data.base64EncodedString(), "mimeType": "audio/pcm;rate=16000"]]], on: socket)
            try await Task.sleep(nanoseconds: UInt64(Double(length) / 32000.0 * 1_000_000_000))
        }
        if assetReader.status == .failed { throw assetReader.error ?? SessionError.noAudio }
        try await send(["realtimeInput": ["audioStreamEnd": true]], on: socket)
    }
}

private enum SessionError: LocalizedError {
    case noAudio, invalidData, server(String)
    var errorDescription: String? {
        switch self {
        case .noAudio: return "صدای قابل پخش در فایل پیدا نشد."
        case .invalidData: return "دادهٔ نامعتبر دریافت شد."
        case .server(let message): return message
        }
    }
}
