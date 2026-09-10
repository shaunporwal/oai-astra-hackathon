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
    @State private var measurementsExpanded=false
    @State private var message="Capture uses the rear wide camera. Place the macro attachment over that lens."
    @State private var exposure=0.0

    @State private var settingsPresented=false
    @State private var stage=0
    @State private var connectionMessage="Checking Mac connection…"
    @State private var checkingConnection=false

    private var canAnalyze: Bool {
        frozen != nil && pairing != nil && !busy
    }
    private var stageTitle: String { stage == 0 ? "Bring your eye into focus" : stage == 1 ? "Review your capture" : "Your frame assessment" }
    private var stageDetail: String {
        stage == 0 ? "Rear wide camera · external 15× macro lens" : stage == 1 ? (target == "redness" ? "Drag over exposed conjunctiva to mark the analysis region." : "Check that the pupil and outer iris are clearly visible.") : "Findings apply to this saved frame only."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView {
                    VStack(alignment:.leading,spacing:20) {
                        header
                        Text(connectionMessage).font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                        stagePicker
                        VStack(alignment:.leading,spacing:6) {
                            Text(stageTitle).font(Theme.Typography.title)
                            Text(stageDetail).font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary)
                        }
                        if stage != 2 { captureCard }
                        if stage == 0 { cameraGuidance }
                        if stage == 1 { reviewControls }
                        if stage == 2 { results }
                        if busy { ProgressView().frame(maxWidth:.infinity) }
                        Text(message).font(.footnote).foregroundStyle(Theme.Colors.inkSecondary)
                            .accessibilityIdentifier("status")
                        Text("Research prototype · measurements are unvalidated and do not establish a diagnosis.")
                            .font(.caption2).foregroundStyle(Theme.Colors.inkSecondary)
                    }.padding(20).disabled(busy)
                }
            }
            .foregroundStyle(Theme.Colors.ink)
            .toolbar(.hidden,for:.navigationBar)
            .safeAreaInset(edge:.bottom,spacing:0) { primaryAction }
            .sheet(isPresented:$settingsPresented) { settings }
        }
        .tint(Theme.Colors.info)
        .preferredColorScheme(.light)
        .task { loadUSBPairing();camera.start();await checkConnection() }
        .onChange(of:scenePhase) { _,phase in if phase != .active { camera.stop() } else if frozen == nil { camera.start() } }
    }

    private var header: some View {
        HStack(spacing:12) {
            Image(systemName:"eye").font(.title2).foregroundStyle(Theme.Colors.info)
                .frame(width:44,height:44).background(.white.opacity(0.6),in:Circle())
            VStack(alignment:.leading,spacing:2) {
                Text("Eye Lab").font(.system(.title2,design:.rounded,weight:.bold))
                Text("GUIDED MACRO CAPTURE").font(.system(size:10,weight:.semibold)).tracking(1.5)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            Spacer()
            Button { settingsPresented=true } label: {
                Image(systemName:"slider.horizontal.3").font(.title3).frame(width:44,height:44)
                    .background(.white.opacity(0.65),in:Circle())
            }.accessibilityLabel("Camera and connection settings")
        }
    }

    private var stagePicker: some View {
        HStack(spacing:4) {
            ForEach(0..<3) { index in
                Button { stage=index } label: {
                    HStack(spacing:5) {
                        Text("\(index+1)").font(.caption.bold())
                        Text(["Capture","Review","Results"][index]).font(.subheadline.weight(.semibold))
                    }.frame(maxWidth:.infinity).padding(.vertical,12)
                        .background(stage == index ? Color.white : Color.clear,in:Capsule())
                        .foregroundStyle(stage == index ? Theme.Colors.ink : Theme.Colors.inkSecondary)
                }.buttonStyle(.plain)
                    .disabled(index == 0 ? frozen != nil : index == 1 ? frozen == nil : snapshot == nil)
            }
        }.padding(4).background(.white.opacity(0.35),in:Capsule())
    }

    private var captureCard: some View {
        VStack(spacing:0) {
            ZStack(alignment:.topLeading) {
                if let frozen,let image=UIImage(data:frozen) {
                    FrameCanvas(image:image,roi:$roi,analysis:snapshot?.geometry,target:target) { snapshot=nil;review=nil }
                } else {
                    CameraPreview(session:camera.session).background(.black)
                }
                Text(frozen == nil ? "LIVE · 1× WIDE" : "SAVED FRAME")
                    .font(.system(size:10,weight:.bold)).tracking(1)
                    .padding(10).foregroundStyle(.white).background(.black.opacity(0.6),in:Capsule())
                    .padding(14).allowsHitTesting(false)
            }
            .aspectRatio(1,contentMode:.fit).clipped()
            HStack(spacing:8) {
                Image(systemName:frozen == nil ? "camera" : "checkmark.circle")
                Text(frozen == nil ? camera.status : "Capture retained on this phone")
                    .font(.caption)
                Spacer(minLength:0)
            }.padding(14)
        }
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius:Theme.Radius.card).strokeBorder(.white.opacity(0.85)))
    }

    private var cameraGuidance: some View {
        VStack(alignment:.leading,spacing:12) {
            Label("Set up your view",systemImage:"viewfinder").font(.headline)
            Text("Move slowly until tissue detail is sharp. Adjust your angle to move bright reflections away from the area you want to assess.")
                .font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary)
            HStack {
                Chip(text:"Manual capture",tone:.info,systemImage:"hand.tap")
                Spacer(minLength:0)
                Button(camera.focusLocked ? "Unlock focus" : "Lock focus") { camera.setFocusLocked(!camera.focusLocked) }
                    .font(.subheadline.weight(.semibold)).frame(minHeight:44)
            }
        }.glassCard()
    }

    private var reviewControls: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Choose an assessment").font(.headline)
            Picker("Measurement",selection:$target) {
                Text("Conjunctival vessels").tag("redness")
                Text("Pupil / iris").tag("geometry")
            }.pickerStyle(.segmented)
                .onChange(of:target) { _,_ in roi=nil;snapshot=nil;review=nil }
            if target == "redness" {
                Text("Exclude iris, skin and eyelids. Selected anatomy is not automatically verified.")
                    .font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                if roi != nil { Button("Clear region") { roi=nil;snapshot=nil;review=nil } }
            }
            HStack {
                Button("Retake",systemImage:"arrow.counterclockwise") { retake() }
                Spacer()
                if let localFile { ShareLink(item:localFile) { Label("Export",systemImage:"square.and.arrow.up") } }
            }.font(.subheadline.weight(.semibold)).frame(minHeight:44)
            Divider()
            Button("Measure locally · no API credits") { Task { await analyze(includeAstra:false) } }
                .font(.subheadline).disabled(!canAnalyze || (target == "redness" && roi == nil))
        }.glassCard()
    }

    private var results: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Chip(text:review == nil ? "Local analysis" : "Astra reviewed",tone:.info,systemImage:"sparkles")
                Spacer()
                Button("View frame") { stage=1 }.font(.subheadline.weight(.semibold))
            }
            if let snapshot {
                DisclosureGroup("Candidate measurements",isExpanded:$measurementsExpanded) {
                    VStack(alignment:.leading,spacing:16) {
                        ForEach(snapshot.geometry.measurements.filter { $0.target_id == (target == "redness" ? "conjunctival_hyperemia" : "pupil_iris_ratio") }) { measurement in
                            VStack(alignment:.leading,spacing:6) {
                                Text(measurement.name.replacingOccurrences(of:"_",with:" ").capitalized).font(.headline)
                                Text(measurement.value.map { measurement.unit == "fraction" ? String(format:"%.1f%% candidate coverage",$0*100) : String(format:"%.3f",$0) } ?? measurement.status.replacingOccurrences(of:"_",with:" "))
                                    .font(.title3.weight(.semibold))
                                Text(measurement.reason).font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                            }
                        }
                    }.padding(.top,12)
                }.glassCard()
            }
            if let review {
                Text("Capture quality: \(review.prediction)").font(.headline)
                ForEach(review.endpoint_assessment.targets) { endpoint in
                    DisclosureGroup {
                        VStack(alignment:.leading,spacing:10) {
                            Text(endpoint.observation)
                            Text(endpoint.limitations.joined(separator:"\n")).foregroundStyle(Theme.Colors.inkSecondary)
                            ForEach(endpoint.measurements,id:\.name) { m in
                                Text("\(m.name.replacingOccurrences(of:"_",with:" ")): \(m.value.map { String(format:"%.3f",$0) } ?? m.status.replacingOccurrences(of:"_",with:" "))")
                            }
                        }.font(.subheadline).padding(.top,12)
                    } label: {
                        VStack(alignment:.leading,spacing:6) {
                            Text(endpoint.name).font(.headline).foregroundStyle(Theme.Colors.ink)
                            Text(endpoint.status.replacingOccurrences(of:"_",with:" ").capitalized)
                                .font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                        }
                    }.glassCard()
                }
            }
        }
    }

    private var primaryAction: some View {
        VStack(spacing:8) {
            if busy {
                Text("Processing your saved frame…").font(.caption)
            } else if stage != 0 && review == nil {
                Text(pairing == nil ? "Open settings to pair with your Mac." : target == "redness" && roi == nil ? "Astra can review this frame. Mark a region to also measure vessels. Uses API credits." : "Uploads this frame to OpenAI · uses API credits")
                    .font(.caption).multilineTextAlignment(.center)
            }
            Button {
                if stage == 0 { capture() }
                else if review != nil { retake() }
                else { Task { await analyze(includeAstra:true) } }
            } label: {
                Label(stage == 0 ? "Capture frame" : review != nil ? "New capture" : "Analyze + Ask Astra",systemImage:stage == 0 ? "camera.fill" : review != nil ? "arrow.counterclockwise" : "sparkles")
            }.buttonStyle(PrimaryButtonStyle())
                .disabled(busy || (stage == 0 ? camera.latestJPEG == nil : review == nil && !canAnalyze))
        }.padding(.horizontal,20).padding(.top,12).padding(.bottom,8)
            .background(.ultraThinMaterial)
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Mac connection") {
                    Text(connectionMessage)
                    Button("Check connection · no API credits") { Task { await checkConnection() } }
                        .disabled(checkingConnection || pairing == nil)
                    if let pairing { Text(pairing.server_url).font(.caption) }
                    Text("Keep both devices on the same trusted Wi-Fi. The OpenAI key stays on your Mac.").font(.caption)
                    TextEditor(text:$pairingText).frame(height:90).font(.caption.monospaced())
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("Pairing JSON")
                    Button("Use pairing configuration") {
                        do {
                            pairing=try JSONDecoder().decode(Pairing.self,from:Data(pairingText.utf8))
                            snapshot=nil;review=nil;pairingText="";stage=frozen == nil ? 0 : 1
                            message="Pairing loaded. Analyze a frame to test the connection."
                            settingsPresented=false
                            Task { await checkConnection() }
                        } catch { message="Invalid pairing JSON. Paste the full configuration from the Mac.";settingsPresented=false }
                    }.disabled(pairingText.isEmpty)
                }
                Section("Camera") {
                    Text("Rear physical wide · 1× · external 15× attachment").font(.subheadline)
                    HStack {
                        Text("Exposure")
                        Slider(value:$exposure,in: -2...2,step:0.1).onChange(of:exposure) { _,value in camera.setExposure(Float(value)) }
                        Text(String(format:"%+.1f EV",exposure)).font(.caption.monospacedDigit())
                    }.disabled(frozen != nil)
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { settingsPresented=false } } }
        }.tint(Theme.Colors.info).preferredColorScheme(.light)
    }

    private func retake() {
        frozen=nil;localFile=nil;roi=nil;snapshot=nil;review=nil;stage=0
        message="Position the macro attachment and capture when detail is sharp."
        camera.start()
    }
    @MainActor private func checkConnection() async {
        guard !checkingConnection else { return }
        guard let pairing else { connectionMessage="Mac not paired · open Settings to connect Astra";return }
        checkingConnection=true;defer { checkingConnection=false }
        connectionMessage="Checking Mac connection…"
        do {
            let status=try await AnalysisClient(pairing:pairing).connection()
            connectionMessage=status.astra_available ? "Mac connected · Astra configured" : "Mac connected · Astra key not configured"
        } catch {
            connectionMessage="Mac connection failed · check Wi-Fi and pairing in Settings"
        }
    }
    private func loadUSBPairing() {
        // Development installation can provision a one-use file over the paired USB connection.
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("mobile-pairing.json")
        guard FileManager.default.fileExists(atPath:url.path) else { return }
        defer { try? FileManager.default.removeItem(at:url) }
        do {
            pairing=try JSONDecoder().decode(Pairing.self,from:Data(contentsOf:url))
            message="Mac pairing loaded over USB. Capture a frame to begin."
        } catch {
            message="USB pairing could not be loaded. Paste the pairing configuration below."
        }
    }
    private func capture() {
        guard let data=camera.latestJPEG else { return }
        frozen=data;roi=nil;snapshot=nil;review=nil;stage=1;camera.stop()
        do {
            let directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            let url=directory.appendingPathComponent("capture-\(UUID().uuidString.lowercased()).jpg")
            try data.write(to:url,options:[.atomic,.completeFileProtection]);localFile=url
            message="Frame retained on this phone. Select a region and analyze when paired."
        } catch { localFile=nil;message="Frame is in memory, but local file saving failed." }
    }
    @MainActor private func analyze(includeAstra: Bool) async {
        guard !busy,let pairing,let frozen else { return }
        busy=true;defer { busy=false }
        let client=AnalysisClient(pairing:pairing)
        do {
            if snapshot == nil {
                message="Measuring the saved frame on your Mac…"
                snapshot=try await client.snapshot(jpeg:frozen,options:AnalysisOptions(target:target,roi:roi))
            }
            if includeAstra,let snapshot {
                message="Astra is reviewing the saved frame…"
                review=try await client.review(caseID:snapshot.case_id)
                stage=2
                message="Assessment complete. Expand an endpoint for findings and limitations."
            } else {
                measurementsExpanded=true;stage=2
                message="Local analysis complete. No Astra call was made."
            }
        } catch {
            message=snapshot == nil ? "Analysis failed: \(error.localizedDescription)" : "Local measurements retained. Astra review failed: \(error.localizedDescription). No automatic retry was made."
        }
    }
}
