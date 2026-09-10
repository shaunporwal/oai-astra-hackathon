import Foundation

@main
struct ContractCheck {
    static func main() throws {
        let path=CommandLine.arguments[1]
        let data=try Data(contentsOf:URL(fileURLWithPath:path))
        let snapshot=try JSONDecoder().decode(Snapshot.self,from:data)
        precondition(snapshot.case_id == "contract-fixture")
        precondition(snapshot.geometry.image_size_wh == [240,200])
        let vessels=snapshot.geometry.measurements.first { $0.name == "vessel_area_fraction" }!
        precondition(vessels.value != nil && vessels.value! > 0)
        precondition(!snapshot.geometry.redness.vessel_contours_xy.isEmpty)
        let options=AnalysisOptions(target:"redness",roi:[0.1,0.1,0.8,0.8])
        let roundTrip=try JSONDecoder().decode(AnalysisOptions.self,from:JSONEncoder().encode(options))
        precondition(roundTrip.roi == options.roi)
        print("Native response decoding and normalized-region encoding passed")
        if CommandLine.arguments.count > 2 {
            struct SmokeResult: Decodable { let snapshot: Snapshot; let review: Review }
            let actual=try JSONDecoder().decode(SmokeResult.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2])))
            precondition(actual.review.endpoint_assessment.targets.count == 6)
            precondition(Set(actual.review.endpoint_assessment.targets.map(\.target_id)).count == 6)
            print("Live snapshot and six-target Astra response decoding passed")
        }
    }
}
