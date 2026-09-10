import Foundation

@main
struct CaptureLibraryCheck {
    @MainActor static func main() throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let fixture=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))) as! [String:Any]
        let review=try JSONDecoder().decode(Review.self,from:JSONSerialization.data(withJSONObject:fixture["review"]!))
        let snapshot=try JSONDecoder().decode(Snapshot.self,from:JSONSerialization.data(withJSONObject:fixture["snapshot"]!))
        let bytes=Data([1,2,3,4])
        var savedID=""
        do {
            let library=CaptureLibrary(migrate:false,directory:directory)
            precondition(library.error == nil)
            let row=try library.save(jpeg:bytes,sourceMode:"imported_image",target:"redness")
            savedID=row.id
            try library.update(row,target:"geometry",roi:[0.1,0.2,0.3,0.4],snapshot:snapshot,review:review)
        }
        let reopened=CaptureLibrary(migrate:false,directory:directory)
        precondition(reopened.error == nil && reopened.captures.count == 1)
        let row=reopened.captures[0]
        precondition(row.id == savedID && row.jpeg == bytes && row.sourceMode == "imported_image" && row.target == "geometry")
        let roi=try JSONDecoder().decode([Double].self,from:row.roiData!)
        let restoredReview=try JSONDecoder().decode(Review.self,from:row.reviewData!)
        let restoredSnapshot=try JSONDecoder().decode(Snapshot.self,from:row.snapshotData!)
        precondition(roi == [0.1,0.2,0.3,0.4])
        precondition(restoredReview.endpoint_assessment.targets.count == 6)
        precondition(restoredSnapshot.case_id == snapshot.case_id)
        try reopened.update(row,target:"redness",roi:nil,snapshot:nil,review:nil)
        precondition(row.reviewData == nil && row.snapshotData == nil && row.jpeg == bytes)
        let legacy=directory.appendingPathComponent("old-files",isDirectory:true)
        try FileManager.default.createDirectory(at:legacy,withIntermediateDirectories:true)
        try bytes.write(to:legacy.appendingPathComponent("capture-old.jpg"))
        let migrated=CaptureLibrary(directory:directory,legacyDirectory:legacy)
        precondition(migrated.error == nil && migrated.captures.count == 2)
        let migratedAgain=CaptureLibrary(directory:directory,legacyDirectory:legacy)
        precondition(migratedAgain.captures.count == 2)
        precondition(FileManager.default.fileExists(atPath:legacy.appendingPathComponent("capture-old.jpg").path))
        print("Legacy file import is idempotent and retains originals")
        print("Disk library: reopen preserves image, source, target, ROI and six-target review; invalidation retains image")
    }
}
