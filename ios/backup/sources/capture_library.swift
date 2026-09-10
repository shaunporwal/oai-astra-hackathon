import Foundation
import Combine
import SwiftData

@Model
final class SavedCapture {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var sourceMode: String
    var target: String
    var roiData: Data?
    @Attribute(.externalStorage) var jpeg: Data
    var snapshotData: Data?
    var reviewData: Data?

    init(id: String = UUID().uuidString.lowercased(), createdAt: Date = Date(), jpeg: Data, sourceMode: String, target: String) {
        self.id=id;self.createdAt=createdAt;self.jpeg=jpeg;self.sourceMode=sourceMode;self.target=target
    }
}

@MainActor
final class CaptureLibrary: ObservableObject {
    @Published private(set) var captures: [SavedCapture]=[]
    @Published private(set) var error: String?
    private var container: ModelContainer?
    private var context: ModelContext?

    init(inMemory: Bool = false, migrate: Bool = true, directory: URL? = nil, legacyDirectory: URL? = nil) {
        do {
            let configuration: ModelConfiguration
            if inMemory {
                configuration=ModelConfiguration(isStoredInMemoryOnly:true,cloudKitDatabase:.none)
            } else {
                let directory=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("eye-library",isDirectory:true)
                try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
                configuration=ModelConfiguration(url:directory.appendingPathComponent("captures.store"),cloudKitDatabase:.none)
            }
            let store=try ModelContainer(for:SavedCapture.self,configurations:configuration)
            container=store;context=store.mainContext
            try refresh()
            if migrate && !inMemory { try importExistingFiles(from:legacyDirectory) }
        } catch { self.error="Capture library could not open: \(error.localizedDescription)" }
    }
    private func refresh() throws {
        guard let context else { return }
        captures=try context.fetch(FetchDescriptor<SavedCapture>(sortBy:[SortDescriptor(\.createdAt,order:.reverse)]))
    }
    func save(jpeg: Data, sourceMode: String, target: String) throws -> SavedCapture {
        guard let context else { throw LibraryError.unavailable }
        let record=SavedCapture(jpeg:jpeg,sourceMode:sourceMode,target:target)
        context.insert(record)
        do { try context.save();try refresh();return record }
        catch { context.rollback();throw error }
    }
    func update(_ record: SavedCapture, target: String, roi: [Double]?, snapshot: Snapshot?, review: Review?) throws {
        guard let context else { throw LibraryError.unavailable }
        record.target=target
        record.roiData=try roi.map { try JSONEncoder().encode($0) }
        record.snapshotData=try snapshot.map { try JSONEncoder().encode($0) }
        record.reviewData=try review.map { try JSONEncoder().encode($0) }
        try context.save()
    }
    func export(_ record: SavedCapture) throws -> URL {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("exports",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let url=directory.appendingPathComponent("capture-\(record.id).jpg")
        try record.jpeg.write(to:url,options:[.atomic,.completeFileProtection])
        return url
    }
    private func importExistingFiles(from directory: URL?) throws {
        guard let context else { return }
        let directory=directory ?? FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let known=Set(captures.map(\.id))
        for url in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.creationDateKey]) where url.lastPathComponent.hasPrefix("capture-") && url.pathExtension.lowercased() == "jpg" {
            let id="legacy-"+url.deletingPathExtension().lastPathComponent
            guard !known.contains(id),let bytes=try? Data(contentsOf:url) else { continue }
            let date=(try? url.resourceValues(forKeys:[.creationDateKey]).creationDate) ?? Date()
            context.insert(SavedCapture(id:id,createdAt:date,jpeg:bytes,sourceMode:"unknown",target:"redness"))
        }
        try context.save();try refresh()
    }
    enum LibraryError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Capture library is unavailable. The image is still in memory." }
    }
}
