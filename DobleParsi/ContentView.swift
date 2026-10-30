import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct ContentView: View {
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
                    Text("دوبلهٔ زنده، ذخیرهٔ خروجی و اتصال Gemini هنوز در دست ساخت هستند.")
                        .foregroundStyle(.secondary)
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
