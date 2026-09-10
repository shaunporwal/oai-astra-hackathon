# iPhone macro capture and shared research endpoint assessment

Adds a browser dashboard and independent native iPhone client for saving eye-video frames and assessing them through one Python backend. The native client pins the rear wide camera at 1× for an external macro attachment, supports focus/exposure adjustment and region selection, and offers a single **Analyze + Ask Astra** action. Local-only processing remains available without API use. Saved-frame previews, session recovery, and compact expandable results support the browser flow.

Python owns candidate vessel coverage, pupil/iris geometry and structured review of six literature-grounded research targets. Missing or unsupported numerical values remain unavailable. Astra supplies observations rather than invented measurements; the application does not establish diagnoses. Credentials stay on the Mac, mobile access uses a rotating pairing token, and successful saved-case reviews are cached. API requests are explicit, with no automatic retry loop. LAN HTTP is development transport.

The backup and prepared partner-UI bridge share one Swift API client. The installed native client now adapts the partner’s visual theme and capture/review hierarchy into a three-step flow with persistent primary action, settings sheet and expandable cards. The full partner session application is not merged. Specifications, literature, evaluation plans and setup guides are organized under lowercase paths.

## Validation and remaining limits

- Full unsigned native iPhone build and Swift contract checks passed, including decoding an actual six-target Astra response.
- Existing Python suite: 35 tests passed at the preceding backend milestone. Browser fake-camera checks covered manual/automatic save, stale sessions, annotation/server failures and compact layout.
- Latest running-backend smoke check used one frame from the user's macro recording and one paid Astra request: snapshot/review succeeded, but all numerical endpoints were unavailable for that frame.
- Connected iPhone and Developer Mode confirmed. Signed build and native installation succeeded. Developer trust and launch succeeded, including after the visual update. Simulator capture-screen layout was inspected; the redesigned review/results interactions and physical capture-to-analysis flow still need a user smoke check. A one-use USB pairing import avoids initial clipboard setup.
- Segmentation and endpoint measurements remain experimental. Clinical evaluation needs suitable targeted captures and independent reference labels.

The native live screen now fits without scrolling at the checked default simulator size, with Retake pinned in the header after capture. Optional automatic capture uses local, unvalidated sharpness/exposure/stability gates and retains the exact best JPEG from a stable window; it cancels after 20 seconds and never calls Astra. Selector checks and signed/simulator builds passed. Physical macro-lens behavior requires a device smoke check.

The latest native UX removes numbered steps: Manual/Auto capture stays on one page, Retake is pinned at the top, and Send to Astra opens a dismissible modal containing the captured image and internally scrollable assessment. Requests continue when the modal is dismissed, and reopening a pending/completed assessment does not submit again.

Users can also choose an existing image with the system Photos picker. Imported images retain their whole framing, are orientation-normalized and resized to metadata-free JPEG, and use the same saved-image assessment path with explicit imported_image provenance. Swift image-preparation checks and 37 Python tests passed.

Review results now prioritize observed-feature cards and compact, unit-formatted local measurements. Unassessable targets and lengthy limitations are collapsed; no new diagnoses, values or API requests are introduced by the presentation change.

An on-device SwiftData/SQLite library now retains captured/imported images and their latest analysis for offline reopening. Older app JPEGs migrate once without deletion. Disk-reopen, review roundtrip and idempotent migration checks passed; the signed update was installed/launched and database files confirmed on the iPhone. CloudKit is disabled; new Astra requests still use the Mac backend.

Mobile Astra review now uses deduplicated Mac background jobs with short status polling and cached-result recovery, fixing the case where the phone times out while the server finishes successfully. New native captures use combined pupil/iris and region-based vessel analysis with shared overlays. 39 Python tests and a native recovery check passed without a paid request.

The review modal pins its image and capture-status row while the report scrolls underneath. A plain-language takeaway precedes Observed features and explicitly distinguishes visible features from an established disease diagnosis. Verified with signed/device and simulator builds and a cached-result layout inspection.

Detailed reviews now lead with a model-written image insight and testable claims: location, source frames, provisional interpretation, alternative, supporting/missing evidence and a verification step. The original measured endpoints remain separate. Cached older reviews have an explicit paid upgrade action. Validation: 43 offline tests, signed/device and simulator builds, and one successful real three-claim Astra response; clinical accuracy is unevaluated.
