import Foundation

/// Everything stored on the device. Logging is offline-first: sets are saved locally
/// immediately and synced to the backend afterwards, so a bad connection never loses a set.
public struct AppData: Codable, Sendable {
    public var profile: UserProfile?
    public var sessions: [WorkoutSession]
    public var activeSession: WorkoutSession?
    public var bodyMetrics: [BodyMetricEntry]

    public init(profile: UserProfile? = nil, sessions: [WorkoutSession] = [], activeSession: WorkoutSession? = nil,
                bodyMetrics: [BodyMetricEntry] = []) {
        self.profile = profile
        self.sessions = sessions
        self.activeSession = activeSession
        self.bodyMetrics = bodyMetrics
    }
}

public final class LocalStore: @unchecked Sendable {
    private let directory: URL
    private let fileURL: URL
    private let queue = DispatchQueue(label: "LiftBros.LocalStore")

    public init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = base
        self.fileURL = base.appendingPathComponent("liftbros-data.json")
    }

    public var proofsDirectory: URL {
        let url = directory.appendingPathComponent("Proofs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public func load() -> AppData {
        guard let data = try? Data(contentsOf: fileURL) else { return AppData() }
        do {
            return try Self.decoder.decode(AppData.self, from: data)
        } catch {
            // Keep the unreadable file so data can be recovered rather than silently overwritten.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            return AppData()
        }
    }

    public func save(_ appData: AppData) {
        queue.sync {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try Self.encoder.encode(appData)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("LiftBros: failed to save data: \(error)")
            }
        }
    }

    /// Copies a picked file into the app's Proofs directory and returns the new file name.
    public func importProof(from source: URL, kind: ProofKind) throws -> String {
        let ext = source.pathExtension.isEmpty ? (kind == .video ? "mov" : "jpg") : source.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = proofsDirectory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: source, to: destination)
        return filename
    }

    public func saveProof(data: Data, fileExtension: String) throws -> String {
        let filename = "\(UUID().uuidString).\(fileExtension)"
        try data.write(to: proofsDirectory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    public func proofURL(for media: ProofMedia) -> URL {
        proofsDirectory.appendingPathComponent(media.filename)
    }

    public func deleteProof(_ media: ProofMedia) {
        try? FileManager.default.removeItem(at: proofURL(for: media))
    }

    public func reset() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: proofsDirectory)
    }

    // Default (numeric) date encoding keeps sub-second precision, unlike ISO 8601.
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
