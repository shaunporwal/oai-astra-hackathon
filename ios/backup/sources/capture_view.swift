import SwiftUI
import PhotosUI

struct CaptureView: View {
    @StateObject private var camera=CameraController()
    @StateObject private var library=CaptureLibrary()
    @State private var libraryPresented=false
    @State private var activeRecord: SavedCapture?
    @State private var backendCaseCurrent=false
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
    @State private var photoPickerPresented=false
    @State private var photoSelection: PhotosPickerItem?
    @State private var importing=false
    @State private var importError=""
    @State private var importErrorPresented=false
    @State private var sourceMode="live_camera"

    @State private var settingsPresented=false
    @State private var reviewPresented=false
    @State private var captureMode="auto"
    @State private var connectionMessage="Checking Mac connection…"
    @State private var checkingConnection=false

    @State private var autoCapture=false
    @State private var autoStarted=Date()
    @State private var captureGate=StableCaptureGate()
    @State private var autoHint=""

    private var canAnalyze: Bool {
        frozen != nil && pairing != nil && !busy && !importing
    }
    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(spacing:10) {
                    header.padding(.horizontal,20)
                    GeometryReader { geometry in
                        VStack(spacing:10) {
                            if frozen == nil {
                                Picker("Capture mode",selection:$captureMode) {
                                    Text("Manual").tag("manual")
                                    Text("Auto · quality").tag("auto")
                                }.pickerStyle(.segmented)
                                    .onChange(of:captureMode) { _,mode in
                                        if mode == "auto" { armAutoCapture() } else { cancelAutoCapture() }
                                    }
                            } else {
                                Text(sourceMode == "imported_image" ? "Imported · ready to send" : "Captured · ready to send").font(.headline)
                            }
                            captureCard
                                .frame(width:min(geometry.size.width,max(160,geometry.size.height-235)))
                            if frozen == nil {
                                Text(autoCapture ? autoHint : camera.sample?.quality.guidance ?? "Preparing camera…")
                                    .font(.subheadline).multilineTextAlignment(.center).frame(minHeight:38)
                                HStack {
                                    Button(camera.focusLocked ? "Unlock focus" : "Lock focus") { camera.setFocusLocked(!camera.focusLocked) }
                                    Spacer()
                                    Text("Local quality check").foregroundStyle(Theme.Colors.inkSecondary)
                                }.font(.caption).frame(minHeight:32)
                                Text("Auto checks sharpness, exposure and stability; it does not verify eye anatomy.")
                                    .font(.caption2).foregroundStyle(Theme.Colors.inkSecondary).multilineTextAlignment(.center)
                            } else {
                                Picker("Measurement",selection:Binding(get:{target},set:{ target=$0;roi=nil;snapshot=nil;review=nil })) {
                                    Text("Conjunctival vessels").tag("redness")
                                    Text("Pupil / iris").tag("geometry")
                                }.pickerStyle(.segmented)
                                Text(target == "redness" ? "Optional: drag over conjunctiva to include vessel measurements." : "Send this saved frame for Astra assessment.")
                                    .font(.caption).foregroundStyle(Theme.Colors.inkSecondary).multilineTextAlignment(.center)
                                if roi != nil { Button("Clear region") { roi=nil;snapshot=nil;review=nil }.font(.caption) }
                            }
                            Spacer(minLength:0)
                        }.frame(maxWidth:.infinity)
                    }.padding(.horizontal,20)
                }.padding(.top,8).disabled(busy || importing || reviewPresented)
            }
            .foregroundStyle(Theme.Colors.ink)
            .toolbar(.hidden,for:.navigationBar)
            .safeAreaInset(edge:.bottom,spacing:0) { primaryAction.disabled(reviewPresented) }
            .overlay { if reviewPresented { reviewModal } }
            .sheet(isPresented:$settingsPresented) { settings }
            .sheet(isPresented:$libraryPresented) { librarySheet }
            .photosPicker(isPresented:$photoPickerPresented,selection:$photoSelection,matching:.images,preferredItemEncoding:.current)
            .alert("Could not import photo",isPresented:$importErrorPresented) {
                Button("OK",role:.cancel) {}
            } message: { Text(importError) }
        }
        .tint(Theme.Colors.info)
        .preferredColorScheme(.light)
        .task {
            #if DEBUG && targetEnvironment(simulator)
            if loadLayoutFixture() { return }
            #endif
            loadUSBPairing();camera.start();if captureMode == "auto" { armAutoCapture() };await checkConnection()
        }
        .onChange(of:scenePhase) { _,phase in if phase != .active { cancelAutoCapture();camera.stop() } else if frozen == nil && !photoPickerPresented && !importing { camera.start() } }
        .onChange(of:libraryPresented) { _,shown in
            if shown { cancelAutoCapture();camera.stop();persistCurrent() }
            else if frozen == nil { camera.start() }
        }
        .onChange(of:photoPickerPresented) { _,shown in
            if shown { cancelAutoCapture();camera.stop() }
            else if frozen == nil && !importing { camera.start() }
        }
        .onChange(of:photoSelection) { _,item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .onChange(of:settingsPresented) { _,shown in if shown { cancelAutoCapture() } }
        .onReceive(camera.$sample) { sample in
            guard autoCapture, frozen == nil, let sample else { return }
            if Date().timeIntervalSince(autoStarted) > 20 {
                cancelAutoCapture();autoHint="No stable capture yet. Adjust the view and try again.";message=autoHint
                return
            }
            autoHint=sample.quality.guidance
            if let jpeg=captureGate.accept(sample) {
                cancelAutoCapture();capture(jpeg:jpeg)
            } else if captureGate.count > 0 { autoHint="Hold still · \(captureGate.count)/4 stable frames" }
        }
        .task(id:autoCapture) {
            guard autoCapture else { return }
            do { try await Task.sleep(for:.seconds(20)) } catch { return }
            guard autoCapture else { return }
            cancelAutoCapture();autoHint="No stable capture yet. Adjust the view and try again."
        }
    }

    private var header: some View {
        HStack(spacing:12) {
            Image(systemName:"eye").font(.title2).foregroundStyle(Theme.Colors.info)
                .frame(width:44,height:44).background(.white.opacity(0.6),in:Circle())
            VStack(alignment:.leading,spacing:2) {
                Text("Eye Lab").font(.system(.title2,design:.rounded,weight:.bold))
                Text(frozen == nil ? "MACRO CAPTURE" : "SAVED FRAME").font(.system(size:10,weight:.semibold)).tracking(1.5)
                    .foregroundStyle(Theme.Colors.inkSecondary)
            }
            Spacer()
            if frozen != nil {
                Button("Retake",systemImage:"arrow.counterclockwise") { retake() }
                    .font(.subheadline.weight(.semibold)).frame(minHeight:44)
            }
            Button { settingsPresented=true } label: {
                Image(systemName:"slider.horizontal.3").font(.title3).frame(width:44,height:44)
                    .background(.white.opacity(0.65),in:Circle())
            }.accessibilityLabel("Camera and connection settings")
        }
    }

    private var captureCard: some View {
        VStack(spacing:0) {
            ZStack(alignment:.topLeading) {
                if let frozen,let image=UIImage(data:frozen) {
                    FrameCanvas(image:image,roi:$roi,analysis:snapshot?.geometry,target:target) { snapshot=nil;review=nil }
                } else {
                    CameraPreview(session:camera.session).background(.black)
                }
                Text(frozen == nil ? "LIVE · 1× WIDE" : sourceMode == "imported_image" ? "IMPORTED PHOTO" : "SAVED FRAME")
                    .font(.system(size:10,weight:.bold)).tracking(1)
                    .padding(10).foregroundStyle(.white).background(.black.opacity(0.6),in:Capsule())
                    .padding(14).allowsHitTesting(false)
            }
            .aspectRatio(1,contentMode:.fit).clipped()
            HStack(spacing:8) {
                Image(systemName:frozen == nil ? "camera" : "checkmark.circle")
                Text(frozen == nil ? (camera.running ? "1× wide · center-square capture" : camera.status) : "Capture retained on this phone")
                    .font(.caption)
                Spacer(minLength:0)
            }.padding(14)
        }
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius:Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius:Theme.Radius.card).strokeBorder(.white.opacity(0.85)))
    }

    private var reviewModal: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { reviewPresented=false }
                    .accessibilityLabel("Dismiss review")
                VStack(spacing:0) {
                    HStack {
                        Text("Astra review").font(.title2.bold())
                        Spacer()
                        Button { reviewPresented=false } label: {
                            Image(systemName:"xmark.circle.fill").font(.title2).frame(width:44,height:44)
                        }.accessibilityLabel("Close review")
                    }.padding(.horizontal,20).padding(.top,10)
                    Divider()
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            if let frozen,let image=UIImage(data:frozen) {
                                Image(uiImage:image).resizable().scaledToFit()
                                    .frame(maxWidth:220,maxHeight:150).clipShape(RoundedRectangle(cornerRadius:18))
                                    .frame(maxWidth:.infinity).accessibilityLabel("Captured frame sent for assessment")
                            }
                            if busy { ProgressView("Reviewing your saved frame…").frame(maxWidth:.infinity) }
                            if review == nil { Text(message).font(.subheadline).accessibilityIdentifier("status") }
                            if snapshot != nil { results }
                            if !busy && review == nil {
                                Button("Send to Astra") { Task { await analyze(includeAstra:true) } }
                                    .buttonStyle(PrimaryButtonStyle()).disabled(!canAnalyze)
                            }
                            if let localFile { ShareLink(item:localFile) { Label("Export captured image",systemImage:"square.and.arrow.up") } }
                            Text("Research prototype. Measurements are unvalidated and do not establish a diagnosis.")
                                .font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                        }.padding(20)
                    }
                }
                .frame(width:max(0,geometry.size.width-32),height:geometry.size.height*0.86)
                .background(Theme.Colors.skyBottom,in:RoundedRectangle(cornerRadius:28))
                .clipShape(RoundedRectangle(cornerRadius:28))
                .shadow(radius:24)
                .accessibilityAddTraits(.isModal)
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
        }
    }

    private var results: some View {
        VStack(alignment:.leading,spacing:16) {
            if let review {
                let observed=review.endpoint_assessment.targets.filter { $0.status == "observed" }
                let unavailable=review.endpoint_assessment.targets.filter { $0.status != "observed" }
                HStack {
                    Chip(text:"Capture: \(review.prediction)",tone:.info,systemImage:"viewfinder")
                    Spacer()
                    Text("\(observed.count) observed").font(.subheadline.weight(.semibold))
                }
                Text("Observed features").font(.headline)
                if observed.isEmpty {
                    Text("No target has a confident visual observation in this image.")
                        .font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary)
                }
                ForEach(observed) { endpoint in
                    VStack(alignment:.leading,spacing:10) {
                        Label(endpointTitle(endpoint),systemImage:"eye").font(.headline)
                        Text(endpoint.observation).font(.subheadline)
                        if !endpoint.measurements.contains(where: { $0.value != nil }) {
                            Text("Visual observation only · no numeric measurement")
                                .font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                        }
                        DisclosureGroup("Evidence & limitations") {
                            Text(endpoint.limitations.isEmpty ? "No additional limitations were reported. This is not a diagnosis." : endpoint.limitations.joined(separator:"\n"))
                                .font(.caption).padding(.top,8)
                        }.font(.caption)
                    }.glassCard(padding:16)
                }
                measurementSummary
                if !unavailable.isEmpty {
                    DisclosureGroup("Not assessable from this image (\(unavailable.count))") {
                        VStack(alignment:.leading,spacing:16) {
                            ForEach(unavailable) { endpoint in
                                VStack(alignment:.leading,spacing:6) {
                                    HStack {
                                        Text(endpointTitle(endpoint)).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(endpoint.status == "not_captured" ? "Not captured" : "Insufficient view").font(.caption)
                                    }
                                    Text(endpoint.observation).font(.caption)
                                    Text(endpoint.limitations.joined(separator:"\n"))
                                        .font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                                }
                            }
                        }.padding(.top,12)
                    }.font(.subheadline.weight(.semibold)).glassCard(padding:16)
                }
            } else {
                measurementSummary
            }
        }
    }

    private func endpointTitle(_ endpoint: Endpoint) -> String {
        ["scleral_chromaticity":"Scleral color",
         "conjunctival_hyperemia":"Conjunctival vessels",
         "palpebral_conjunctival_color":"Inner eyelid color",
         "pupil_iris_ratio":"Pupil & iris",
         "pupillary_light_reflex":"Pupil light response",
         "peripheral_corneal_opacity":"Peripheral corneal appearance"][endpoint.target_id] ?? endpoint.name
    }

    private var measurementSummary: some View {
        VStack(alignment:.leading,spacing:12) {
            let measurements=snapshot?.geometry.measurements ?? []
            let available=measurements.filter { $0.value?.isFinite == true && ["estimated","measured"].contains($0.status) }
            Text("Measurements").font(.headline)
            if available.isEmpty {
                Text("No reliable numeric values from this image.")
                    .font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary)
            }
            ForEach(available) { measurement in
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:4) {
                        Text(measurement.name == "vessel_area_fraction" ? "Candidate vessel coverage" : measurement.name == "pupil_to_iris_ratio" ? "Pupil / iris ratio" : measurement.name.replacingOccurrences(of:"_",with:" "))
                            .font(.subheadline.weight(.semibold))
                        Text("Local image analysis · experimental").font(.caption2).foregroundStyle(Theme.Colors.inkSecondary)
                    }
                    Spacer()
                    Text(measurement.value.map { measurement.unit == "fraction" ? String(format:"%.1f%%",$0*100) : String(format:"%.3f",$0) } ?? "—")
                        .font(.title3.bold()).monospacedDigit()
                }
            }
            DisclosureGroup("Measurement details") {
                VStack(alignment:.leading,spacing:12) {
                    ForEach(measurements) { measurement in
                        VStack(alignment:.leading,spacing:4) {
                            Text(measurement.name.replacingOccurrences(of:"_",with:" ").capitalized).font(.caption.bold())
                            Text(measurement.status.replacingOccurrences(of:"_",with:" ")+": "+measurement.reason).font(.caption)
                        }
                    }
                }.padding(.top,8)
            }.font(.caption)
        }.glassCard(padding:16)
    }

    private var primaryAction: some View {
        VStack(spacing:8) {
            HStack {
                Button { photoPickerPresented=true } label: {
                    Label(importing ? "Loading…" : "Import Photos",systemImage:"photo.on.rectangle")
                        .frame(maxWidth:.infinity,minHeight:44)
                }
                Button { libraryPresented=true } label: {
                    Label("Library",systemImage:"square.stack")
                        .frame(maxWidth:.infinity,minHeight:44)
                }
            }.font(.subheadline).buttonStyle(.bordered).disabled(busy || importing)
            if importing { ProgressView() }
            Text(frozen == nil ? (autoCapture || !autoHint.isEmpty ? autoHint : connectionMessage) : busy ? "Astra request in progress · tap to view" : review != nil ? "Assessment saved · tap to reopen" : "Sends this frame to OpenAI · uses API credits")
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
            Button {
                if frozen != nil {
                    reviewPresented=true
                    if !busy && review == nil { Task { await analyze(includeAstra:true) } }
                } else if captureMode == "manual" { capture(jpeg:camera.latestJPEG) }
                else if autoCapture { cancelAutoCapture();autoHint="Auto capture paused" }
                else { armAutoCapture() }
            } label: {
                Label(frozen != nil ? (review != nil || busy ? "View Astra review" : "Send to Astra") : captureMode == "manual" ? "Capture frame" : autoCapture ? "Pause auto capture" : "Start auto capture",systemImage:frozen != nil ? "sparkles" : captureMode == "manual" ? "camera.fill" : "viewfinder")
            }.buttonStyle(PrimaryButtonStyle())
                .disabled(importing || (frozen == nil ? (captureMode == "manual" && camera.latestJPEG == nil) : pairing == nil && review == nil && !busy))
        }.padding(.horizontal,20).padding(.top,12).padding(.bottom,8)
            .background(.ultraThinMaterial)
    }

    private var librarySheet: some View {
        NavigationStack {
            List {
                if let error=library.error { Text(error).foregroundStyle(.red) }
                if library.captures.isEmpty {
                    ContentUnavailableView("No saved images",systemImage:"photo.on.rectangle",description:Text("Captured and imported images are saved here on your iPhone."))
                }
                ForEach(library.captures,id:\.id) { record in
                    Button { openSaved(record) } label: {
                        HStack(spacing:12) {
                            if let image=UIImage(data:record.jpeg) {
                                Image(uiImage:image).resizable().scaledToFit().frame(width:64,height:64)
                                    .background(.black.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius:10))
                            }
                            VStack(alignment:.leading,spacing:5) {
                                Text(record.createdAt,format:.dateTime.month(.abbreviated).day().hour().minute()).font(.headline)
                                Text(record.sourceMode == "imported_image" ? "Imported photo" : record.sourceMode == "live_camera" ? "Camera capture" : "Earlier saved image").font(.caption)
                                Text(record.reviewData == nil ? "No saved Astra review" : "Astra review saved").font(.caption).foregroundStyle(Theme.Colors.inkSecondary)
                            }
                            Spacer()
                            Image(systemName:"chevron.right").font(.caption)
                        }
                    }.foregroundStyle(Theme.Colors.ink)
                }
            }.navigationTitle("Image library").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { libraryPresented=false } } }
        }.tint(Theme.Colors.info).preferredColorScheme(.light)
    }

    private func persistCurrent() {
        guard let activeRecord else { return }
        do { try library.update(activeRecord,target:target,roi:roi,snapshot:snapshot,review:review) }
        catch { message="Image retained; saving assessment failed: \(error.localizedDescription)" }
    }
    private func openSaved(_ record: SavedCapture) {
        persistCurrent();cancelAutoCapture();camera.stop()
        activeRecord=record;frozen=record.jpeg
        sourceMode=record.sourceMode == "live_camera" ? "live_camera" : "imported_image"
        target=record.target
        roi=record.roiData.flatMap { try? JSONDecoder().decode([Double].self,from:$0) }
        snapshot=record.snapshotData.flatMap { try? JSONDecoder().decode(Snapshot.self,from:$0) }
        review=record.reviewData.flatMap { try? JSONDecoder().decode(Review.self,from:$0) }
        backendCaseCurrent=false
        localFile=try? library.export(record)
        message="Opened from this iPhone. Saved images and reviews work offline."
        libraryPresented=false
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
                            snapshot=nil;review=nil;pairingText=""
                            message="Pairing loaded. Analyze a frame to test the connection."
                            settingsPresented=false
                            Task { await checkConnection() }
                        } catch { message="Invalid pairing JSON. Paste the full configuration from the Mac.";settingsPresented=false }
                    }.disabled(pairingText.isEmpty)
                }
                if frozen != nil {
                    Section("Optional local measurement") {
                        Button("Measure locally · no API credits") {
                            settingsPresented=false;reviewPresented=true
                            Task { await analyze(includeAstra:false) }
                        }.disabled(!canAnalyze || (target == "redness" && roi == nil))
                    }
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
        persistCurrent();activeRecord=nil;backendCaseCurrent=false
        cancelAutoCapture();autoHint=""
        frozen=nil;localFile=nil;roi=nil;snapshot=nil;review=nil;reviewPresented=false
        message="Position the macro attachment and capture when detail is sharp."
        camera.start()
        if captureMode == "auto" { armAutoCapture() }
    }
    #if DEBUG && targetEnvironment(simulator)
    // Optional local artifacts for layout inspection; unavailable in device builds.
    private func loadLayoutFixture() -> Bool {
        if CommandLine.arguments.contains("--layout-library") { libraryPresented=true;return true }
        guard CommandLine.arguments.contains("--layout-review") || CommandLine.arguments.contains("--layout-captured") else { return false }
        let directory=FileManager.default.temporaryDirectory
        struct Fixture: Decodable { let snapshot: Snapshot;let review: Review }
        guard let data=try? Data(contentsOf:directory.appendingPathComponent("layout-review.json")),
              let fixture=try? JSONDecoder().decode(Fixture.self,from:data),
              let jpeg=try? Data(contentsOf:directory.appendingPathComponent("layout-frame.jpg")) else { return false }
        frozen=jpeg;snapshot=fixture.snapshot;review=fixture.review
        message="Layout inspection · previously saved assessment"
        reviewPresented=CommandLine.arguments.contains("--layout-review")
        return true
    }
    #endif
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
    private func armAutoCapture() {
        guard frozen == nil else { return }
        captureGate.reset();autoStarted=Date();autoHint="Waiting for sharp, stable detail…";autoCapture=true
    }
    private func cancelAutoCapture() { autoCapture=false;captureGate.reset() }
    @MainActor private func importPhoto(_ item: PhotosPickerItem) async {
        guard !busy && !importing else { return }
        cancelAutoCapture();camera.stop();importing=true
        defer {
            importing=false;photoSelection=nil
            if frozen == nil && !photoPickerPresented { camera.start() }
        }
        do {
            guard let data=try await item.loadTransferable(type:Data.self) else { throw ImageImport.ImportError.unsupported }
            let jpeg=try await Task.detached(priority:.userInitiated) { try ImageImport.prepare(data) }.value
            capture(jpeg:jpeg,source:"imported_image")
            message="Photo imported. Send to Astra when ready. Capture conditions and lens are not verified."
        } catch { importError=error.localizedDescription;importErrorPresented=true }
    }
    private func capture(jpeg: Data?, source: String = "live_camera") {
        guard let data=jpeg else { return }
        persistCurrent();activeRecord=nil;backendCaseCurrent=false
        cancelAutoCapture()
        sourceMode=source
        frozen=data;roi=nil;snapshot=nil;review=nil;camera.stop()
        do {
            let record=try library.save(jpeg:data,sourceMode:source,target:target)
            activeRecord=record;localFile=try? library.export(record)
            message="Image saved in your iPhone library. Send to Astra when ready."
        } catch { localFile=nil;message="Image is in memory, but library saving failed: \(error.localizedDescription)" }

    }
    @MainActor private func analyze(includeAstra: Bool) async {
        guard !busy,let pairing,let frozen else { return }
        busy=true;defer { busy=false;persistCurrent() }
        let client=AnalysisClient(pairing:pairing)
        do {
            if snapshot == nil || !backendCaseCurrent {
                message="Measuring the saved frame on your Mac…"
                snapshot=try await client.snapshot(jpeg:frozen,options:AnalysisOptions(target:target,roi:roi),sourceMode:sourceMode)
                backendCaseCurrent=true
                persistCurrent()
            }
            if includeAstra,let snapshot {
                message="Astra is reviewing the saved frame…"
                review=try await client.review(caseID:snapshot.case_id)
                message="Assessment complete. Expand an endpoint for findings and limitations."
            } else {
                measurementsExpanded=true
                message="Local analysis complete. No Astra call was made."
            }
        } catch {
            message=snapshot == nil ? "Analysis failed: \(error.localizedDescription)" : "Local measurements retained. Astra review failed: \(error.localizedDescription). No automatic retry was made."
        }
    }
}
