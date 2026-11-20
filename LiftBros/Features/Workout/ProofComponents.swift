import AVKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Imports a video from the photo library as a file.
struct ProofMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

enum ProofImporter {
    enum ImportError: LocalizedError {
        case unsupported

        var errorDescription: String? { "That file couldn't be used as proof. Pick a video or photo of your set." }
    }

    static func load(_ item: PhotosPickerItem) async throws -> PickedProof {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try await item.loadTransferable(type: ProofMovie.self) else { throw ImportError.unsupported }
            return .video(movie.url)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else { throw ImportError.unsupported }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        return .photo(data, fileExtension: ext)
    }
}

/// Plays or shows stored proof media.
struct ProofPreview: View {
    let media: ProofMedia
    let url: URL

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            switch media.kind {
            case .video:
                VideoPlayer(player: player)
                    .onAppear { if player == nil { player = AVPlayer(url: url) } }
                    .onDisappear { player?.pause() }
            case .photo:
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    ContentUnavailableView("Proof unavailable", systemImage: "photo")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Explains what each verification status means for the leaderboard.
struct VerificationExplainer: View {
    let status: VerificationStatus

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var message: String {
        switch status {
        case .unverified:
            return "This lift still counts on leaderboards, marked as unverified. Upload a video showing the weight, full range of motion and every rep to get it verified."
        case .pending:
            return "Your proof is being reviewed. It stays on the leaderboard as unverified until then."
        case .verified:
            return "Verified. This lift shows a green tick and counts on verified-only leaderboards."
        case .rejected:
            return "This proof wasn't accepted, so the lift is shown as unverified. Try a clearer video showing the plates and full reps."
        }
    }
}
