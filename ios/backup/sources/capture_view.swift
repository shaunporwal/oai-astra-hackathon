import SwiftUI

struct CaptureView: View {
    @StateObject private var camera=CameraController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var pairingText=""
    @State private var pairing: Pairing?
    @State private var target="redness"
    @State private var roi: [Double]?
    @State private var frozen: Data?
    @State private var localFile: URL?
    @State private var snapshot: Snapshot?
    @State private var review: Review?
    @State private var busy=false
    @State private var message="Capture uses the rear wide camera. Place the macro attachment over that lens."
    @State private var exposure=0.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    if let frozen,let image=UIImage(data:frozen) {
                        FrameCanvas(image:image,roi:$roi,analysis:snapshot?.geometry,target:target) { snapshot=nil;review=nil }
                            .frame(height:330).allowsHitTesting(!busy)
                    } else {
                        CameraPreview(session:camera.session).frame(height:330).background(.black).clipShape(RoundedRectangle(cornerRadius:12))
                    }
                    Text(frozen == nil ? camera.status : "Saved frame · drag within exposed white-eye tissue to select a region.").font(.caption)
                    HStack {
                        if frozen == nil {
                            Button("Capture frame") { capture() }.buttonStyle(.borderedProminent).disabled(camera.latestJPEG == nil)
                            Button(camera.focusLocked ? "Autofocus" : "Lock focus") { camera.setFocusLocked(!camera.focusLocked) }.buttonStyle(.bordered)
                        } else {
                            Button("Retake") { frozen=nil;roi=nil;snapshot=nil;review=nil;camera.start() }.buttonStyle(.bordered)
                            if let localFile { ShareLink("Export JPEG",item:localFile).buttonStyle(.bordered) }
                        }
                    }
                    if frozen == nil {
                        HStack { Text("Exposure").font(.caption);Slider(value:$exposure,in: -2...2,step:0.1).onChange(of:exposure) { _,value in camera.setExposure(Float(value)) };Text(String(format:"%+.1f EV",exposure)).font(.caption.monospacedDigit()) }
                    }
                    Picker("Measurement",selection:$target) { Text("Conjunctival vessels").tag("redness");Text("Pupil / iris").tag("geometry") }.pickerStyle(.segmented)
                        .onChange(of:target) { _,_ in roi=nil;snapshot=nil;review=nil }
                    if target == "redness" {
                        Text("Mark only exposed conjunctiva, excluding iris, skin and eyelids. The app does not verify the selected anatomy.").font(.caption).foregroundStyle(.secondary)
                        if roi != nil { Button("Clear region") { roi=nil;snapshot=nil;review=nil } }
                    }
                    DisclosureGroup("Pair with analysis server") {
                        Text("Paste mobile-pairing.json from the Mac. Keep both devices on the same trusted network. The OpenAI key stays on the Mac.").font(.caption)
                        TextEditor(text:$pairingText).frame(height:90).font(.caption.monospaced()).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Use pairing configuration") {
                            do {
                                let value=try JSONDecoder().decode(Pairing.self,from:Data(pairingText.utf8))
                                pairing=value;snapshot=nil;review=nil;pairingText="";message="Pairing loaded. Analyze a frame to test the connection."
                            } catch { message="Invalid pairing JSON. Paste the full configuration from the Mac." }
                        }
                        if let pairing { Text(pairing.server_url).font(.caption) }
                    }
                    HStack {
                        Button("Analyze on Mac") { Task { await analyze() } }.buttonStyle(.borderedProminent)
                            .disabled(frozen == nil || pairing == nil || (target == "redness" && roi == nil))
                        Button("Ask Astra") { Task { await askAstra() } }.buttonStyle(.bordered).disabled(snapshot == nil)
                    }
                    if busy { ProgressView("Working…") }
                    Text(message).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("status")
                    if let snapshot {
                        DisclosureGroup("Local measurements",isExpanded:.constant(true)) {
                            ForEach(snapshot.geometry.measurements.filter { $0.target_id == (target == "redness" ? "conjunctival_hyperemia" : "pupil_iris_ratio") }) { measurement in
                                VStack(alignment:.leading) {
                                    Text(measurement.name.replacingOccurrences(of:"_",with:" ")).font(.headline)
                                    Text(measurement.value.map { measurement.unit == "fraction" ? String(format:"%.1f%% candidate coverage",$0*100) : String(format:"%.3f",$0) } ?? measurement.status)
                                    Text(measurement.reason).font(.caption)
                                }
                            }
                        }
                    }
                    if let review {
                        Text("Astra capture: \(review.prediction)").font(.headline)
                        ForEach(review.endpoint_assessment.targets) { endpoint in
                            DisclosureGroup(endpoint.name) {
                                Text("\(endpoint.status): \(endpoint.observation)")
                                Text(endpoint.limitations.joined(separator:"\n")).font(.caption).foregroundStyle(.secondary)
                                ForEach(endpoint.measurements, id:\.name) { m in Text("\(m.name): \(m.value.map { String(format:"%.3f",$0) } ?? m.status)").font(.caption) }
                            }
                        }
                    }
                    Text("Research prototype. Candidate measurements are unvalidated and do not establish a diagnosis. Analyze on Mac sends the saved frame to your Mac; Ask Astra uploads it to OpenAI and uses API credits.").font(.caption).foregroundStyle(.secondary)
                }.padding().disabled(busy)
            }.navigationTitle("Eye Lab · Backup")
        }
        .task { camera.start() }
        .onChange(of:scenePhase) { _,phase in if phase != .active { camera.stop() } else if frozen == nil { camera.start() } }
    }
    private func capture() {
        guard let data=camera.latestJPEG else { return }
        frozen=data;roi=nil;snapshot=nil;review=nil;camera.stop()
        do {
            let directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            let url=directory.appendingPathComponent("capture-\(UUID().uuidString.lowercased()).jpg")
            try data.write(to:url,options:[.atomic,.completeFileProtection]);localFile=url
            message="Frame retained on this phone. Select a region and analyze when paired."
        } catch { localFile=nil;message="Frame is in memory, but local file saving failed." }
    }
    @MainActor private func analyze() async {
        guard let pairing,let frozen else { return }
        busy=true;defer { busy=false }
        do {
            snapshot=try await AnalysisClient(pairing:pairing).snapshot(jpeg:frozen,options:AnalysisOptions(target:target,roi:roi))
            review=nil;message="Local analysis complete. No Astra call was made."
        } catch { message="Analysis failed: \(error.localizedDescription)" }
    }
    @MainActor private func askAstra() async {
        guard let pairing,let snapshot else { return }
        busy=true;defer { busy=false }
        do { review=try await AnalysisClient(pairing:pairing).review(caseID:snapshot.case_id);message="Astra assessment applies to this saved frame." }
        catch { message="Astra assessment failed: \(error.localizedDescription)" }
    }
}
