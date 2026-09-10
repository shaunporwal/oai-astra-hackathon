import Foundation
import Observation
import UIKit

/// Source of truth for study sessions. Persists to a JSON file in the app's Documents
/// directory; captured images live alongside it via `ImageStore`.
@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [StudySession] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sessions.json")
        load()
        if sessions.isEmpty {
            sessions = SessionStore.seedSessions()
            save()
        }
    }

    // MARK: Queries

    func session(id: UUID) -> StudySession? {
        sessions.first { $0.id == id }
    }

    /// The session the coordinator should surface first: due-soonest incomplete session.
    var nextSession: StudySession? {
        sessions
            .filter { $0.status != .complete }
            .sorted { $0.dueDate < $1.dueDate }
            .first
    }

    var completedSessions: [StudySession] {
        sessions.filter { $0.status == .complete }.sorted { $0.dueDate > $1.dueDate }
    }

    // MARK: Mutations

    func update(_ session: StudySession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        save()
    }

    func append(capture: EyeCapture, to sessionID: UUID) {
        guard var session = session(id: sessionID) else { return }
        session.captures.append(capture)
        session.status = session.remainingEyes.isEmpty ? .complete : .inProgress
        if session.status == .complete {
            session.sessionEndpoints = EndpointAnalyzer.sessionEndpoints(for: session)
        }
        update(session)
    }

    func resetForDemo() {
        for session in sessions {
            for capture in session.captures {
                ImageStore.delete(fileName: capture.imageFileName)
            }
        }
        sessions = SessionStore.seedSessions()
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        sessions = (try? decoder.decode([StudySession].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Seed

    static func seedSessions(now: Date = .now) -> [StudySession] {
        let participant = Participant(id: "0042", studyName: "Ocular surface study")
        let today = Calendar.current.startOfDay(for: now).addingTimeInterval(9 * 3600)
        return [
            StudySession(
                participant: participant,
                visitNumber: 3,
                imagingProtocol: .ocularSurface,
                dueDate: today,
                consentRecorded: true
            ),
            StudySession(
                participant: Participant(id: "0017", studyName: "Ocular surface study"),
                visitNumber: 2,
                imagingProtocol: .ocularSurface,
                dueDate: today.addingTimeInterval(2 * 86_400),
                consentRecorded: true
            ),
        ]
    }
}

/// Stores captured JPEGs in Documents/captures.
enum ImageStore {
    static var directory: URL {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    @discardableResult
    static func save(_ image: UIImage, quality: CGFloat = 0.95) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        do {
            try data.write(to: url(for: fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func load(fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName).path)
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
