# OptLab integration bridge

Inspected partner branch `origin/feat/optlab-guided-eye-imaging`, commit `f98f3b7824fcb771736248af3e02f3cae33e00f4`. This folder is an integration seam, not a merged or fully wired OptLab app. The partner branch is unchanged.

## Reuse boundary

Use OptLab's navigation, capture controller, voice/haptic guidance, eye/visit identity and review screens as the prospective main native UI. Keep its immediate local alignment/quality loop for acquisition feedback. Use our Python service for the research endpoint definitions, local measurement outputs, Astra observations and stored evidence. The browser remains an engineering console and the backup app a fallback.

`ios/shared/analysis_client.swift` is now shared transport/model code used by the backup project. Add that file and `optlab_analysis_bridge.swift` to the OptLab target without copying their contents. The bridge references the partner's existing `EyeCapture`, `Eye` and `ImageStore` types. It normalizes/resizes a copy of the original image to a 960-pixel JPEG, preserves the original, and returns the OptLab capture ID and eye alongside the backend case.

Example from a user-initiated review action:

```swift
let bridge = OptLabAnalysisBridge(client: AnalysisClient(pairing: pairing))
let linked = try await bridge.analyze(
    capture: capture,
    source: .physicalCamera, // derive from the actual frame source, never assume for a simulator
    target: "redness",
    roi: selectedNormalizedConjunctivalRectangle
)
// Render linked.backend.geometry.measurements and overlays.
// Only on the separate user action that spends credits:
let assessment = try await bridge.review(linked)
```

The adapter explicitly rejects simulation. The partner's `EyeCapture` currently has no persisted simulation/source flag; add one before connecting this action in production UI. A declaration supplied by the caller is not an automatic provenance check. Add camera target/normalized-region UI, pairing UI and local-network privacy/ATS declarations as in the backup app. Persist the returned case-to-capture mapping if results should survive relaunch. These screen hooks and persistence are NOT implemented by this bridge alone.

## Required behavior changes before a combined demo

- Select the physical rear lens under the attachment and avoid automatic lens switching. The partner currently prefers a close-focusing ultra-wide at 2×, whereas the backup pins rear wide at 1×. Neither preference alone proves where the user mounted the attachment.
- Disable built-in-optics working-distance/mm-per-pixel guidance in external-attachment mode; the existing field-of-view model does not include the 15× attachment.
- Replace endpoint display/export from the native `EndpointAnalyzer` with shared-backend results. Preserve fast native image processing for guidance, but do not equate its red-contrast fraction to our candidate-vessel mask fraction.
- Do not present a population iris mean as individual millimeter calibration, nor its population SD as complete measurement uncertainty.
- Keep raw color/ring heuristics out of bilirubin/arcus/disease claims; follow the target specification and explicit estimated/ungradable/not-calibrated statuses.
- Make seeded participants/consent unmistakably demo fixtures. The partner's seeded sessions set consentRecorded=true; that is not actual consent evidence.
- Adapt capture acceptance for conjunctival views; requiring a centered pupil for every target repeats the coupling we already removed from our redness mode.

## Verification performed

The bridge plus shared client passed a complete Swift SDK typecheck with all partner app Swift files. An initial EndpointMeasurement name collision was resolved by naming our transport DTO BackendEndpointMeasurement. Existing partner concurrency warnings remain. The original partner Xcode build failed during asset-catalog compilation because no simulator runtime is installed; this is not presented as an app build success or a phone test.

The backup app was rebuilt using the shared client, and its native response-contract check was rerun. No API calls, UI merge, partner-branch mutation or native-device installation was performed for this review.
