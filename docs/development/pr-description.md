# OptoLab: iPhone macro capture and testable Astra image reports

Adds a working native iPhone app and shared Python backend for capturing eye images with an external 15× macro attachment, importing existing photos, and generating structured Astra assessments. Users can retake immediately, inspect experimental anatomical overlays, and reopen images and their latest reports from an on-device SwiftData library.

The report keeps the captured image and capture status pinned while findings scroll underneath. Detailed analysis leads with an image-specific insight and testable claims: source frames, location, provisional interpretation, alternatives, supporting/missing evidence and verification steps. Six specification-backed research endpoints remain separate from those hypotheses. Local pupil/iris and selected-region vessel measurements remain unavailable when their gates fail.

The Python backend owns measurement algorithms and Astra requests. The native and browser clients share its API. Authenticated background review jobs let the phone poll and recover completed results without automatically resubmitting paid model requests. Keys stay on the Mac; app-library records and backend captures are local, Git-ignored artifacts. The native app requires a reachable Mac backend for analysis.

## Submission and branch consolidation

The root README presents the working demo, architecture, reproducible setup, verification evidence, limitations and next milestones. Main's uploaded example images are retained. The partner UI/UX prototype contributed visual design but is a separate unmerged app; preserve its complete commit under `archive/optlab-uiux-2026-09-10` before deleting its obsolete development branch. The primary implementation is `ios/backup`, displayed as OptoLab on the phone.

## Validation and scope

- 43 offline Python tests cover API contracts, input/measurement validation, source-frame references, background jobs and cached recovery.
- Signed native builds, physical iPhone 15 Pro installation/launch, authenticated phone-to-Mac connectivity, and simulator report-layout checks passed during development.
- One recent paid detailed-review smoke test returned three structured claims in approximately 42 seconds. This establishes operation, not diagnostic accuracy.
- Automatic capture remains experimental and has reported reliability issues; use manual capture for the demonstration.
- Fully automatic tissue segmentation, burst selection, symptom intake and a web-search harness are future work.
- Clinical accuracy and biomarker calibration remain unvalidated. The UI distinguishes provisional hypotheses from confirmed diagnoses and does not fabricate numerical endpoints.
