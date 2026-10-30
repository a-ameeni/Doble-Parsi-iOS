import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var session = DubSession()
    @State private var apiKey = ""
    @State private var language = "fa"
    @State private var selectingFile = false
    @State private var player: AVPlayer?
    @State private var selectedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("دوبله پارسی")
                        .font(.largeTitle.bold())
                    Text("نسخهٔ اولیهٔ آیفون")
                        .foregroundStyle(.secondary)
                    if let player {
                        VideoPlayer(player: player)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Button("انتخاب فایل صوتی یا ویدئویی") { selectingFile = true }
                        .buttonStyle(.borderedProminent)
                    SecureField("کلید API جمنای", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Picker("زبان دوبله", selection: $language) {
                        Text("فارسی").tag("fa")
                        Text("English").tag("en")
                        Text("العربية").tag("ar")
                        Text("Türkçe").tag("tr")
                    }
                    if let url = selectedURL, let player {
                        Button(session.running ? "پایان دوبله" : "شروع دوبله") {
                            if session.running { session.stop(player: player) }
                            else { session.start(url: url, key: apiKey, language: language, player: player) }
                        }.buttonStyle(.borderedProminent)
                    }
                    Text(session.status).foregroundStyle(.secondary)
                    if !session.translatedText.isEmpty { Text(session.translatedText).textSelection(.enabled) }
                    if !session.sourceText.isEmpty { Text(session.sourceText).foregroundStyle(.secondary).textSelection(.enabled) }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .environment(\.layoutDirection, .rightToLeft)
            .fileImporter(isPresented: $selectingFile, allowedContentTypes: [.movie, .audio]) { result in
                switch result {
                case .success(let url):
                    if let player, session.running { session.stop(player: player) }
                    if let selectedURL { selectedURL.stopAccessingSecurityScopedResource() }
                    guard url.startAccessingSecurityScopedResource() else {
                        errorMessage = "دسترسی به فایل ممکن نشد."
                        return
                    }
                    selectedURL = url
                    player = AVPlayer(url: url)
                    errorMessage = nil
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
