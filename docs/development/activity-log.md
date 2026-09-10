# Activity log

## 2026-09-10 — Initial independent vision branch

Created `feat/eye-vision-pipeline` in an empty repository and committed the initial scaffold as `d625bb2` (`Add independent eye vision capture pipeline`). Added webcam/video preview, OpenCV Haar face/eye ROI detection, sample/crop export, a Python model extension point, and JSON output. Three unit tests and a synthetic-video replay/export check passed. No live webcam was exercised.

## 2026-09-10 — iPhone input, Astra adapter, and evaluation tooling

### Requested scope

Use iPhone 15 Pro footage immediately, keep the Swift app owned by the partner, implement the Python analysis/evaluation side, and maintain Markdown documentation under `docs/`. A PR documentation skill was requested if available. Searched the installed skills/catalog and found no matching PR documentation skill; wrote `docs/development/pr-description.md` using the repository work and developer PR-writing guidance instead.

### Implemented

- `eye-prepare`: headless close-up MOV/MP4 ingestion without the old full-face dependency; configurable sampling/duration/frame count; optional rotation/manual ROI; bounded resized frame selection; contact sheet and preparation manifest with hashes/geometry/quality metadata.
- `eye-astra`: optional OpenAI SDK/Pydantic integration targeting `gpt-6-astra`; selected frames reviewed together for capture usability; structured evidence and limitations; local request validation by default; explicit `--send` for remote execution; usage/model/prompt/manifest metadata in results.
- `eye-eval`: independent capture-usability label validation, subject/source split-leakage checks, exact preparation-manifest matching, and metrics exposing abstentions/missingness.
- An intentionally unannotated label template, ignored local data/output/secret paths, and this documentation set.
- Updated package version to 0.2.0 and installed the optional Astra dependencies in `vision/.venv/`.

### Decisions

The first benchmark is capture usability because no clinical condition/reference dataset has been chosen. This is a scoped engineering milestone, not completion of the diagnostic product. Retina/OCT/slit-lamp datasets are not interchangeable with self-captured phone videos. ROI boxes and image-quality heuristics are not anatomical segmentation. Segmentation and diagnosis stay explicitly `not_configured`.

Source checks used official OpenAI documentation for image inputs and structured outputs and primary research searches for data leads. Some publisher/PMC full-text fetches were blocked; dataset access/license details remain unverified as documented in `data-sources.md`.

### Validation

- 13 automated tests passed, including the original three, synthetic video preparation/rotation/crop/export, invalid-input handling, split/provenance checks, missing/abstaining metrics, source/manifest mismatch rejection, and SDK roundtrips using an in-memory HTTP transport.
- A separate CLI smoke run passed: generated a temporary synthetic video; prepared three frames; validated an Astra request locally; confirmed a live command fails without a key and saves no prediction; validated fixture labels; scored missing and answered fixture predictions. All fixture files were temporary and removed.
- Python compilation and Git whitespace checks passed.
- Tested environment: Python 3.14.5, OpenCV 4.14.0, NumPy 2.5.3, OpenAI SDK 2.54.0, Pydantic 2.13.5. Dependency ranges are declared in `vision/pyproject.toml`; this is not a cross-platform compatibility claim.

### Outstanding inputs and limitations

`OPENAI_API_KEY` was not set in the executing shell (presence only was checked; no secret was printed). No live Astra request was made. No phone recording was supplied, so iPhone HEVC/HDR decoding, real frame selection, and camera optics remain untested. The code does not connect to or control the phone, and wireless Continuity Camera discovery remains untested. No clinical dataset, real reference labels, trained segmenter, disease model, or clinical evaluation results exist yet.

Next user input: AirDrop a short iPhone eye recording and provide its local path. For live review, configure the API key locally. Next research decision: target finding/condition and expert/reference-label source. No Swift changes were made and no remote PR was opened or branch pushed in this implementation pass.

## 2026-09-10 — Manual Astra review enabled

The user clarified that the assistant should inspect frames directly while API configuration is pending. Added `manual-review.md` documenting interactive image inspection and an evaluator-compatible prediction format with explicit interactive provenance. API credentials are no longer a prerequisite for the first frame review. Manual model predictions remain separate from human/expert ground truth and from API runs.

Checked the repository for supplied MOV/MP4/JPEG/PNG input; none was found. No image inspection or prediction is claimed yet. The remaining input for this route is a recording or its local path. This was a documentation-only update; no additional software tests were needed. Git whitespace checks passed.

## 2026-09-10 — Healthcare boundaries clarified

Checked current OpenAI usage policies and FDA software guidance after the user asked whether healthcare restricts the work. Added `healthcare-boundaries.md`. Clarified that capture-quality-first was a development choice: research segmentation and diagnostic-model implementation/evaluation can proceed. Patient-facing medical advice and high-stakes automated decisions have additional boundaries. No policy rejection or development stop occurred.

## 2026-09-10 — First real iPhone video ingested and reviewed

Located the newly AirDropped MOV in Downloads and moved it, as requested, to root `data/img_2377.mov`. Added the root `/data/` rule and verified Git ignores the original. Derived images and review files remain under ignored `vision/runs/phone-001/`.

Successfully decoded the recording, sampled 31 candidate frames, exported eight JPEGs and a contact sheet, and inspected all eight images directly. Saved `manual-prediction.json` and `review.md` in that run directory. Validated the review structure and source/manifest-image integrity; no separate API request was made and no human ground-truth label or accuracy metric was fabricated.

The real clip exposed a selection limitation: global sharpness alone can favor incomplete eye framing. The next quality-selection experiment should consider eye-region coverage and reflection, with additional footage for validation. Personal visual observations remain in the ignored review artifact. Successful decoding applies to this file; HDR color fidelity, other recording modes, and clinical adequacy are not established.

## 2026-09-10 — Macro attachment provenance confirmed

The user confirmed the first recording used a 15× macro lens attachment with the iPhone 15 Pro. Recorded this user-reported setup in ignored `data/img_2377.capture.json` and the local manual-review artifacts. Original video bytes and the preparation manifest remain unchanged, preserving their hashes. Capture-quality observations and the abstention decision are unchanged.

This sample belongs to `phone_with_macro_attachment`; it does not establish unaided-phone capture performance. The lens rating is not a calibrated physical scale. Future data collection should record attachment use explicitly and evaluate materially different capture setups separately.

## 2026-09-10 — Imported proposed targets from origin/main

Fetched `origin/main` and found `specs/details.csv`, containing six proposed biomarker/vision/clinical target rows. Remote main was an independent root history, so merged it using `--allow-unrelated-histories`; existing vision work, local documentation edits, and ignored recordings were preserved. Converted CSV to root `specs/details.json` using Python's CSV parser, preserving all headers, Unicode, field text, and row order. Verified a JSON roundtrip equals the CSV rows.

Added `target-feasibility.md` with literature-backed distinctions between image measurements and clinical interpretations, capture requirements for the 15× macro setup, formula/anatomy corrections, and a recommended implementation order. Static pupil-to-iris ratio is the first recommended prototype; no numeric biomarker or disease prediction was fabricated. Clinical source claims remain verbatim in the imported files and are explicitly identified as unvalidated proposals.

## 2026-09-10 — Reformed targets around published evidence

Replaced the prior verbatim `specs/details.json` conversion with schema 1.0, containing six revised research targets and five linked primary-study references. Preserved the original `specs/details.csv`. Added anatomy/formula corrections, literature-supported statements, unsupported clinical claims, capture requirements, validation references, and explicit project-versus-literature distinctions. All targets state that our exact setup and clinical-trial use remain unvalidated.

Created `docs/research/literature-review.md` for presentation preparation: DOI/full-text links, sample and study context, numerical findings, limitations, and suggested paraphrases. Verified the anemia study's 435 recruited versus 426 analyzed distinction and the arcus article's 2009 issue date (2008 online). Cross-checked publisher/primary-source content; did not download PDFs or claim figure reuse permissions. Updated the earlier feasibility document to reflect the revised JSON rather than its superseded lossless format.

Validated JSON parsing, six unique target IDs, all source-reference links, original CSV preservation, and Git whitespace. No runtime code or clinical predictions changed.

## 2026-09-10 — Lowercase filenames

Renamed the root CSV/JSON, documentation readme files, original recording, and capture sidecar to fully lowercase names. Updated references throughout project documentation and local run metadata. Recomputed the manual prediction's preparation-manifest hash after its source filename changed; original video bytes remain unchanged. Git internals, installed dependencies, and generated package/cache directories were excluded from project filename changes.

## 2026-09-10 — Repository organization

Grouped documentation into `docs/guides/`, `docs/research/`, and `docs/development/`, retaining `docs/readme.md` as the index. Moved the target definition and original proposal to `specs/details.json` and `specs/details.csv`. Added root `readme.md` with the directory map and entry points. Historical mentions of files originally created at the root describe their location at that time.

Updated relative documentation links, repo-relative references, and the specification's source/literature paths. Standardized current original-recording guidance on root `data/`. Python source, package layout, original recordings, and existing run artifacts were not moved. Lowercase filenames remain the convention.

Validation: all 31 local Markdown links resolved; specification paths and all six targets remained valid; the CSV matched its original remote contents; video and manual-review manifest hashes were unchanged. Git whitespace checks passed. No runtime code changed, so software tests were not rerun for this organization pass.

## 2026-09-10 — Live camera dashboard implemented

Added `eye-live`, a loopback FastAPI/browser dashboard that selects a camera through browser media capture. macOS device discovery listed the iPhone as `Shaun Camera` / `iPhone16,1`; the actual browser-to-iPhone stream still requires a hands-on permission/positioning check. No Swift app changes were made.

Implemented transient JPEG frame analysis, a prototype dark-region pupil contour/ellipse, pixel diameter and raw quality display, explicitly labeled recorded-video replay, snapshot persistence with live/replay provenance, and optional Astra review of a saved frame. Continuous video is not recorded. The API key remains absent; diagnosis and iris ratio remain explicitly unavailable. This does not fulfill a disease-diagnosis demonstration yet.

Real-image spot checks revealed thresholding failures with shadows/occlusion. A synthetic-circle test also exposed threshold/edge-selection error, which was fixed before all checks passed. The resulting estimator remains a non-clinical heuristic, not a validated anatomical model. Added `docs/guides/live-demo.md` with capture and demonstration instructions and limitations.

Validation: 19 automated tests passed, covering geometry, frame input/auth/limits, snapshot hashes/provenance, unavailable API behavior, and earlier pipeline/SDK/evaluation tests. A Playwright Chromium smoke test used a simulated camera and a temporary server: camera discovery/start, processing, save, disabled Astra action, and stop all passed without JavaScript errors. The test's snapshot artifacts were temporary; its screenshot is ignored at `vision/runs/live-dashboard-smoke.png`. A simulated camera test is not confirmation of iPhone capture. JavaScript syntax checks passed. Playwright was installed only as local verification tooling.

Started the real demo server at `http://127.0.0.1:8765` and opened it in the Mac browser. The user must allow camera access, select the iPhone, and position the macro attachment. No separate Astra API call or clinical prediction was made.

## 2026-09-10 — Local API credential connected and first API review verified

Added CLI startup loading of the root `.env`, accepting the user-provided `oai_api_key` alias and standard `OPENAI_API_KEY`. Existing shell settings take precedence, including an explicitly empty standard key to disable access. Only the credential is imported, variable interpolation is disabled, and library calls do not automatically load real credentials during tests. Used [python-dotenv](https://bbc2.github.io/python-dotenv/) for parsing. The key was neither printed nor added to source control; `.env` is ignored. Updated the live guide, iPhone runbook, and Python readme.

Validation: all 22 automated tests passed, including credential alias, precedence, interpolation and missing-file behavior. Restarted the dashboard at http://127.0.0.1:8765 and confirmed API availability. Performed one real API request through its snapshot/review endpoints using frame 120 of the existing 15× macro recording, labeled recorded_video. Saved artifacts are ignored at `vision/runs/live-af064f7117e44049/`; its single-frame index 0 corresponds to original prepared frame 120. The original JPEG bytes were preserved.

The API returned HTTP 200, completed status, and resolved model `gpt-6-astra`. Its capture-quality prediction was usable, with limitations concerning bright reflections and single-frame coverage. Usage: 1,867 input tokens and 182 output tokens (2,049 total). This differs from the earlier manual multi-frame abstention and is not an accuracy result or clinical ground truth. Diagnosis remains unconfigured. No automatic stream uploads were enabled. Account credit balance and dollar cost were not queried. Refresh the browser after restart to obtain the new session token.

## 2026-09-10 — Guided capture and spending design

Documented the proposed camera-control boundary, local candidate selection, slower Astra feedback, persistent attempt budgets, and research findings in `guided-capture-plan.md`. Verified browser/Apple control documentation and measured the prior saved API response latency (7.73 seconds). No additional paid request or runtime change was made. Hardware controls remain unverified on the actual selected browser track; automatic selection and budget enforcement remain implementation work.

## 2026-09-10 — Automatic candidate capture and capability reporting

Implemented an opt-in, single-shot stable-window selector in `static/selector.js`. It retains exact scored JPEGs, resets on movement/missing candidates/low detail/poor exposure, expires old candidates, and saves the best candidate in the qualifying window. Added local guidance and camera capability reporting; no hardware settings are changed and no automatic API calls are made. Source stop/restart resets selection. Kept all Swift code untouched.

Validation: 22 Python tests passed; Node selection tests cover missing candidates, exact best-frame identity, motion reset, low-detail rejection and stale buffers. Spot-checked all eight prepared recording frames at the dashboard resolution: frame 0 lacked a candidate; the other seven produced candidates, including previously noted imperfect views. This confirms the selector still needs independent eye-quality evaluation and must not claim anatomical correctness. Browser smoke results are recorded below. No paid API calls were made.

Browser validation: Playwright simulated-camera discovery/start, capability reporting, selection arm/cancel, guidance, and stop passed without JavaScript errors. This was not a physical iPhone test. Node selector tests passed after adding the low-detail gate. Git whitespace checks passed.

## 2026-09-10 — Connect research endpoint specification to Astra

Addressed the implementation gap between the target JSON and the quality-only dashboard request. Added a structured six-target appearance assessment, target-specification hash and full prompt hash, server validation of coverage/evidence, and explicit null quantitative measurements. Replaced the static diagnosis-unconfigured UI card with per-target research results while retaining the fact that clinical diagnosis is unimplemented. Old quality-only cache files are preserved separately. No paid API request was used for this change; SDK mock roundtrip exercises the expanded schema and validation. CLI quality-review behavior is preserved.

Validation: 23 Python tests, selector tests, JavaScript syntax and Git whitespace checks passed. A browser rendering check displayed all six targets using offline fixtures without JavaScript errors. Restarted the local server with the expanded assessment route. No new clinical validation is claimed.

## 2026-09-10 — Experimental pupil/iris measurement implemented

Added robust radial-edge outer-iris fitting, explicit rejection diagnostics and a dimensionless equivalent-ellipse diameter ratio. The live overlay now includes both boundaries; saved snapshots show their own annotated image and geometry separately from the current live frame. Astra endpoint results attach the locally computed saved-image ratio, including on cache hits without a new paid request. Auto-selection requires accepted iris geometry. Updated the target specification and added `docs/guides/pupil-ratio.md` plus an offline video-check script.

A JPEG synthetic test exposed pupil-core shrinkage; adding intermediate threshold candidates fixed that test. Final validation: 28 Python tests, Node selector tests, JavaScript syntax, and a browser saved-image/overlay smoke check passed. The synthetic browser snapshot produced ratio 0.296 for a known 0.300 target. No API calls were made. Final real-video scan accepted 5/76 sampled frames with ratios 0.312–0.344, but no stable auto-selection window. A rough unblinded visual comparison on frame 102 gave ~0.295 versus the automatic 0.333; shadow contamination remains a real failure mode. Earlier intermediate acceptance counts/ratios are superseded by the final results in the pupil-ratio guide. Independent annotation and clinical validation remain outstanding.

Restarted the dashboard server. Runtime artifacts remain ignored under `vision/runs/geometry-final/`; no private images or API keys are included in the commit. Next capture should expose the outer iris more consistently and hold the view steady, while algorithm evaluation continues.

## 2026-09-10 — Compact dashboard and clinical-value review

Replaced the long dashboard with a viewport-sized desktop layout. Camera and capture controls remain beside compact current-frame metrics, a saved-image summary and six expandable endpoint rows. Capture observations and camera help are collapsed by default. Expanded content uses panel scrolling; narrow/short screens remain readable through a stacked layout. Preserved element IDs, input actions, overlays and measurement provenance. Added asset version query strings for the changed CSS/JS.

Browser checks with long offline observation fixtures passed at 1440×900, 1280×720 and 1024×768 without document scrolling or horizontal overflow. Mobile 390×844 had no horizontal overflow and intentionally used vertical scrolling. Endpoint expansion worked without JavaScript errors. No API calls or backend changes were made.

Added `docs/research/clinical-value.md` with primary studies on patient-operated capture, iPhone macro imaging and corneal-opacity diagnostic accuracy, plus a target-by-target assessment. Corrected the bilirubin literature summary to state that the reported regression was fit/evaluated on the same sample. Recommended guided imaging for a clinician-defined workflow as the first clinical-value hypothesis; current app outputs remain unvalidated.

## 2026-09-10 — Select the first clinical workflow

Selected clinician-supervised ocular redness follow-up as the first clinical workflow hypothesis, with guided acquisition and independently graded capture adequacy as the initial evaluation. Documented why vessel coverage is a candidate metric and why current pupil geometry is only supporting engineering work. Clarified rear camera versus straight-on viewing angle. No runtime behavior changed and no API requests were made.

## 2026-09-10 — Orthogonal redness measurement module

Added pure `measurements.redness` candidate-vessel segmentation and a shared dataclass value contract. `analysis.py` orchestrates existing geometry and the new region-based measurement for all live/snapshot/review paths, validates options, and writes analysis/mask artifacts. Endpoint attachment now joins measurements generically by target/name; old adapter names and response fields remain compatible. Browser annotation rendering and stable-window retention are shared rather than duplicated.

Added an independent conjunctival-vessel capture mode with manual normalized ROI selection, region-local detail and appearance-stability checks, live candidate coverage, mask overlays, and saved options/masks. The ROI is user-designated and anatomy is not verified. No automatic tissue segmentation, clinical grade, longitudinal change interpretation, Swift changes or paid API requests were introduced.

Validation: 34 Python tests and Node selector checks passed. Synthetic vessel masks exceeded 0.9 Dice against known red-line shapes; denominator accounting, grayscale negatives, blur/darkness/tiny-region rejection, invalid options, saved-region persistence and endpoint integration passed. Browser simulated-camera selection, region drag/clear, mode switch, annotated save and 1280×720 layout passed without JavaScript errors. Synthetic browser snapshot coverage was 5.1%; this is fixture output, not a patient result. A real prepared-image ROI produced zero candidates at low local detail; no real-image accuracy claim is made. Documentation identifies the need for sharper conjunctival captures and independent references.

## 2026-09-10 — Independent backup iPhone app

Added `ios/backup/eye-backup.xcodeproj` with native SwiftUI capture/review screens, an AVFoundation rear-wide camera controller, autofocus lock and exposure compensation, local JPEG retention/export, normalized region selection, shared-backend transport and endpoint presentation. Pinned physical wide camera at 1×; no torch or automatic camera switching. Captures are resized video frames, not full-resolution stills. Capture is manual; browser auto-selection is not ported. No partner source or Swift measurement algorithm was duplicated.

Added opt-in `eye-live --lan-url` mode with explicit host allowance, a rotating pairing token saved to a mode-0600 ignored JSON file, and remote-root token non-disclosure. Native requests reject redirects and use a pairing token rather than the OpenAI key. Default desktop service remains loopback-only. Started the separate mobile service on `http://air.local:8766`; connectivity and pairing file permissions passed local checks. No API credits were used.

Validation: Swift SDK typecheck passed, and the complete unsigned iOS device build succeeded using direct `xcodebuild -target`. The scheme build was unavailable because Xcode reports a missing iOS platform component; a direct target build resolved compilation without downloading a simulator. Native response-contract decoding/ROI encoding passed against a Python-generated synthetic response. All 35 Python tests passed, including LAN authorization and hostname restrictions. Property lists passed linting. Physical installation remains pending: no connected phone, simulator runtime or valid signing identity was available. Documented Xcode signing, device support and pairing steps in `ios/backup/readme.md`.

### Connected iPhone follow-up

After the user connected the phone, CoreDevice detected the iPhone 15 Pro as available and paired over USB. Device inspection reported Developer Mode disabled, and the Mac still had zero valid code-signing identities. Opened the backup project in Xcode and requested user completion of Developer Mode and account/team setup. Checked for newer Xcode device-support components; none were available. The platform-download command requested an 8.52 GB simulator runtime; stopped that download because a simulator is not needed for direct-target compilation and physical-device installation. The phone subsequently became temporarily unavailable, consistent with disconnection or restart; no installation has been claimed. No serial numbers or device identifiers are committed.

## 2026-09-10 — Capture display and session recovery fix

Addressed the report that manual/automatic capture showed no image. Identified two failure-prone paths: restarted servers invalidate an already-open page's token, and the old save flow did not display the JPEG until annotation completed. The user's browser blocked AppleScript JavaScript inspection, so the exact original browser error was not retrieved; the fixes were verified with reproduced failures instead.

Display the raw captured JPEG immediately below the capture controls. Report capture/save progress and errors there, disable duplicate manual clicks during encoding, keep the raw preview if annotation fails, and enable Astra only after a confirmed saved case. Added a once-only session refresh/retry after HTTP 403; rejected authorization requests have not executed the operation. Use browser Image decoding for optional overlays instead of depending on createImageBitmap. Capture failures remain distinct from a successful save.

Added an isolated Playwright regression script using a simulated camera and temporary server: actual manual button, stale-token recovery, injected overlay failure, injected server error, automatic capture and thumbnail placement all passed. Desktop document stayed within 1280×720. No API requests were made.

The connected iPhone now reports Developer Mode enabled and device services available. Signing identity/team setup remains outstanding; no native app installation has been claimed.

## 2026-09-10 — Inspect partner OptLab branch and prepare shared integration

Fetched `origin/feat/optlab-guided-eye-imaging` at f98f3b7 and inspected its native UI, capture, session storage, simulation and endpoint paths in an isolated detached worktree. Found useful voice/motion guidance, high-resolution still capture and session/review UX. Identified conflicts in assumed iris millimeter scale, color/ring endpoint semantics and default ultra-wide/2× optics versus the external attachment. Recommended adopting the partner UI while retaining one authoritative backend endpoint layer.

Moved the backup's API client to `ios/shared`, updated the backup project reference, and added an OptLab bridge against its existing EyeCapture/ImageStore model. The bridge requires explicit physical-versus-simulated provenance and retains capture ID/eye association. It is prepared integration code; no partner screen is yet wired to it. Combined partner/shared/bridge Swift typecheck passed after resolving an EndpointMeasurement DTO name collision; partner Sendable warnings remain. The original partner full build failed at asset compilation due to the missing simulator runtime. No paid requests or partner-branch changes were made. Further screen hooks and camera/measurement corrections are documented in the integration review.

Backup verification after shared-client extraction: unsigned iPhone target build succeeded and the native response-contract/ROI roundtrip check passed. The isolated partner inspection worktree was then removed; build logs/artifacts remain ignored.

## 2026-09-10 — Prioritize minimal native capture-to-Astra flow

Deferred partner-screen integration in favor of the existing backup client and running Mac backend. Simplified the native primary action to **Analyze + Ask Astra**; kept local-only processing in a disclosure and made local measurements collapsible. Saved cases are reused after review failures, completed assessments disable the main action, and target/ROI/capture changes invalidate prior results. No continuous inference or automatic retries were added. Added `docs/guides/minimal-iphone-demo.md` and corrected installation status in the native README.

The connected iPhone 15 Pro is available with Developer Mode enabled; Xcode still has zero valid signing identities and no development team in this project. Opened the project and requested the required Apple account/team setup. Installation and physical camera/network checks remain pending.

Validation: the full unsigned native target build passed. Sent frame 102 from the existing macro recording, resized to a longest side of 960 pixels, through the running mobile snapshot and review routes. Exactly one paid Astra request returned HTTP 200 with all six endpoint assessments and a usable capture-quality rating. All numerical fields remained unavailable: this was successful transport/schema validation, not successful clinical measurement. Local-only comparisons at 1280 and 1536 pixels also failed the outer-iris support gate; no threshold was relaxed to force a number. Artifacts remain ignored under `vision/runs/mobile/live-0cb73dc649ac5a83/` and `vision/runs/mobile/smoke-result.json`. Native response-contract checks passed for both the synthetic numerical fixture and the actual six-target Astra response. No patient images or results are committed.

## 2026-09-10 — Sign and install on the connected iPhone

After Apple account sign-in, discovered the available Personal Team and passed its identifier only as a local build setting. The direct-target provisioning attempt lacked a destination device; the explicit iPhone scheme build successfully registered/provisioned the connected phone after Xcode component installation. Signed build and `devicectl` app installation succeeded. Code signature verification passed and the provisioning profile includes the connected device; this profile expires September 17, 2026. Personal identifiers and signing assets are not committed.

Added a one-use USB pairing import from the app temporary directory, deleting the file after loading. Rebuilt, installed, and copied the existing backend pairing configuration into the app container without printing its token. Launch was denied by iOS security pending developer trust; asked the user to trust their developer account in phone Settings. Physical camera/network testing remains pending. Mac backend remains running on port 8766. No Astra requests were made.

### Developer trust and launch confirmed

After the user trusted the developer account, `devicectl device process launch` succeeded on the connected iPhone. The app temporary directory is empty, consistent with the one-use pairing file being consumed; this alone does not prove successful pairing or network connectivity. The Mac backend is still listening on port 8766. Camera permission, physical preview and a phone-originated capture/analysis request remain to be checked. No API requests were made.

## 2026-09-10 — Adapt partner visual design into the installed app

Fetched the partner branch and reused its Theme/AmbientBackground/glassCard plus button/chip components under lowercase native source files. Reorganized the working app into Capture, Review and Results, with persistent primary action, rounded viewfinder/cards, clearer instruction hierarchy, a settings sheet for pairing/exposure, and expandable endpoint details. Retake, export, manual region selection, local-only analysis, paid review, result invalidation and one-use USB pairing remain wired to the existing camera/client/backend. No partner clinical endpoint algorithms or seeded sessions were imported.

Validation: signed iPhone scheme build and simulator build passed. Inspected a simulator capture-screen screenshot at `vision/runs/native-ui-capture.png`; camera unavailable is expected in the simulator, and the capture button is disabled. Review/results were compiled but have not been interactively exercised in this visual update. Installed the signed app update on the physical iPhone, refreshed pairing over USB and successfully launched it. No paid requests were made. Existing saved captures were not intentionally deleted.

## 2026-09-10 — Make iPhone Astra access explicit

Confirmed the mobile backend already loads the root `.env` lowercase `oai_api_key` through the CLI configuration layer and reports Astra configured. Found that the native primary action was unnecessarily blocked in redness mode until a user ROI existed. Removed the ROI prerequisite for Astra frame review; local-only vessel measurement still requires a region, and missing quantitative values remain unavailable. Added authenticated `POST /api/connection` and a shared Swift client method with a 10-second timeout. The app checks on startup/after pairing and offers a no-credit manual recheck in Settings, displaying connection failure versus Mac connected/Astra configured. This checks credentials are configured, not upstream API balance or key validity.

Validation: all 36 Python tests passed, including authentication, key non-disclosure and no paid call for the connection route. Signed native build, installation, fresh USB pairing and launch succeeded. Restarted mobile backend to load the new route and local credential configuration. Authenticated connection returned HTTP 200 and Astra available; the review route returned the existing real six-target cached result without another paid request. Phone-displayed connection status and an actual phone-originated Astra request still need user confirmation. No secret or patient artifact was committed.

## 2026-09-10 — Match square viewfinder and saved capture

Resolved portrait video letterboxing: the previous preview used aspect-fit inside a fixed-height wide rectangle. The viewfinder is now 1:1 and uses aspect-fill. Video encoding applies the corresponding center-square crop before resizing to 960×960, so exported JPEGs, review ROI coordinates and backend/Astra input share the square framing. No image stretching, optical zoom change or backend measurement change. Earlier captures are retained unchanged.

Validation: standalone Swift crop checks passed for portrait, landscape and nonzero-origin square bounds; signed iPhone build succeeded. Physical framing still requires checking through the user's attachment. No API requests were made.

Installed the square-capture build, refreshed USB pairing and successfully launched it on the connected iPhone.

## 2026-09-10 — Compact capture screen and local automatic selection

Moved Retake into the persistent top header for Review and Results. Replaced the live capture scroll view with a height-aware square viewfinder and compact focus guidance; manual and automatic capture actions stay in the bottom action area. Inspected the simulator screenshot at `vision/runs/native-compact-capture.png`: controls and guidance fit on screen without scrolling at the default text size.

Added an explicit **Auto capture when sharp** action using native grayscale sharpness, exposure, focus/exposure settling and motion checks, with four eligible frames across at least 0.8 seconds. Saves the exact sharpest JPEG in that stable window through the existing capture method, then stops. Manual capture remains available. Cancellation resets state; opening Settings/backgrounding cancels; a 20-second timer also cancels even if camera frames stop arriving. This is an unvalidated image-quality heuristic, not an eye detector or diagnostic adequacy model. It makes no network or Astra request. Numerical thresholds and limitations are documented in the native README.

Validation: Swift checks passed for sharpness/blur, dark/clipped exposure, focus settling, motion rejection, timing gaps, reset and exact best-frame retention. Signed device and simulator builds passed. Installed on the connected iPhone and refreshed pairing, but iOS blocked launch because the phone was locked; requested unlock. On-device automatic-capture behavior with the macro attachment remains to be checked. No API credits were used.

After the user unlocked the phone, launching the installed auto-capture update succeeded.

## 2026-09-10 — Single capture page and dismissible Astra popup

Removed numbered Capture/Review/Results navigation. One fixed capture page now offers Manual and Auto quality modes; Auto is selected and armed initially, and Retake re-arms it when selected. A captured frame remains on that page with Retake at the top, optional target/region selection and **Send to Astra** at the bottom. Sending opens a bounded modal immediately with the exact captured image, loading/error state and expandable results in its own scroll view. The image thumbnail is height-limited so results are reachable without scrolling through a full portrait image. Tapping the backdrop or Close dismisses the popup. Reopening during/completed review does not submit again; an explicit retry is offered after failure. Frame/options mutation is disabled during an active request. Local-only analysis moved to Settings.

Signed phone and simulator builds passed. Added a Debug simulator-only layout loader for existing ignored image/response artifacts; it is excluded from device builds and does not call APIs. Inspected the modal with a prior real assessment, showing bounded height, retained frame and the close control. Layout artifacts remain in `vision/runs/`. No additional Astra requests were made.

Installed the final single-page/modal build, refreshed USB pairing and successfully launched it on the physical iPhone. Modal screenshot inspection used a cached prior assessment and made no API request.

## 2026-09-10 — Import phone photos into the shared assessment flow

Added an Import from Photos action using the scoped system Photos picker. Picker/import pauses automatic camera capture, shows loading/error states, and retains the previous capture if decoding fails. Successful import uses the shared capture persistence/result-reset path, then the same optional ROI and explicit Send to Astra/modal flow. A pure ImageIO preparation helper downsamples before full pixel decode, applies orientation, preserves the full field of view and exports a JPEG without original EXIF/GPS metadata. The original Photos asset is unchanged.

Extended the shared Swift snapshot client with a source-mode argument (live camera remains the default for existing clients). The backend accepts and persists imported_image provenance. No unverified macro-lens metadata is inferred. Restarted the mobile service and refreshed USB pairing, installed the signed update and launched it successfully.

Validation: native import checks passed for EXIF orientation, whole-image aspect ratio, 960-pixel maximum dimension, GPS removal and invalid-data rejection. All 37 Python tests passed, including imported-image provenance, hash and exact-JPEG retention. Signed iPhone build passed. Physical Photos picker selection and a phone-import-to-Astra request still need an on-device smoke check. No paid API calls were made.

Simulator build also passed; inspected `vision/runs/native-import-control.png` and confirmed the new import action fits on the capture page without scrolling at the checked default size.

## 2026-09-10 — Findings-first structured review

Replaced the flat six-target accordion with a capture-quality badge, observed-target count, visible-feature cards and a compact measurement block. Only observed targets appear in the primary feature list; all ungradable/not-captured targets are grouped under one collapsed section. Displayed numbers require a finite value and estimated/measured status, retain fraction versus dimensionless formatting, and are labeled as local experimental analysis. Missing values are not rendered as rows of dashes. Original observations and limitations remain available without rewriting clinical meaning; visual observations with no numeric result are explicitly labeled.

Reduced the image thumbnail and hid routine completion prose after a successful review. Detailed methods/rejection reasons and endpoint limitations are expandable. Signed device and simulator builds passed. Inspected the modal using an existing cached six-target result: one observed feature is prominent while unavailable targets are collapsed. This changes presentation only, not API output, model prompts or measurement algorithms. No API credits were used.

Installed and launched the structured-summary update on the connected iPhone after refreshing USB pairing.

## 2026-09-10 — On-device image and assessment database

Added a SwiftData model backed by SQLite in `Library/Application Support/eye-library/captures.store`, with framework-managed external image storage and CloudKit disabled. Records retain image bytes, date, source, target/ROI, the displayed local snapshot and latest structured review. Shared response DTOs now support encoding as well as decoding. New captures/imports persist automatically; analysis persists after local snapshot and completion/failure. Reopening a completed review works without the Mac/API; incomplete reopened records create a fresh server snapshot before a new review to avoid stale case IDs.

Added a Library sheet with thumbnails, dates, source and review availability. Older Documents capture JPEGs migrate idempotently without deletion and with unknown original provenance. Temporary exports support the existing share action. Fixed target-selection invalidation so restoring a different saved target does not erase its restored review. Added `docs/guides/image-library.md` covering locations, offline behavior, backups and current limits.

Validation: disk-backed Swift checks passed across store recreation for image bytes, identity, source, ROI, target, snapshot and all six review targets; review invalidation retained the original image. Legacy migration repeated without duplicate rows or deleting original files. Updated Swift transport contract checks passed. Signed phone/simulator builds passed and the simulator library list was visually inspected with a migrated image. Installed and launched on the physical iPhone; device file inspection confirmed captures.store, SQLite WAL/SHM and the managed support directory exist. No API calls were made.

## 2026-09-10 — Remove viewfinder labels and footer

Removed the Live/Imported/Saved badge inside the camera square and the white camera-status footer beneath it. The capture card now contains only the preview/saved image and existing region/measurement overlays. Camera errors remain available in the guidance text outside the square. No capture, storage or analysis logic changed.

Signed build passed; installed, refreshed pairing and launched on the connected iPhone. No API requests were made.

## 2026-09-10 — Recover timed-out reviews and combine local analysis

Investigated recent mobile cases and found completed six-target Astra results despite phone timeouts; one measured latency was 62.26 seconds. Implemented authenticated Mac review-job start/status routes, per-case deduplication, persistent job state and cached-result-first retrieval. Phone requests now poll with short timeouts and explicit URLSession request/resource settings. Reopened library records check their saved backend case before uploading another snapshot. Polling failures do not automatically resubmit a model request.

Removed the native conjunctival/pupil mode selector for new captures, added combined local analysis and displayed existing pupil/iris candidate boundaries plus available vessel masks together on saved-image/review canvases. Vessel analysis still needs a selected conjunctival region; no automatic tissue segmentation or Astra pixel-mask generation is claimed. Detailed design/limits and the official documentation consulted are in `docs/development/review-jobs.md`.

Validation: 39 Python tests passed, including delayed-job deduplication, cache recovery, failure/interrupted status and combined analysis. Signed phone build passed and the updated app was installed/launched after restarting the Mac service and refreshing pairing. A native Swift client recovered a recent completed real six-target result without an OpenAI submission. No API credits were used for this fix.

## 2026-09-10 — Pinned review image and plain-language takeaway

Moved the saved image, experimental overlay legend and capture/observed-count row outside the modal ScrollView. The report below that row scrolls independently; close and outside-tap dismissal remain available. Image height adapts to the available screen height. Added a Main takeaway card before Observed features, derived from the existing observed target titles, with explicit disease-status wording. Current endpoint observations do not encode a supported disease diagnosis, so the UI says “Disease status: not established”; it does not infer disease or normality from the observed count. No new model request or response schema change is involved, and saved reviews work unchanged.

Validation: signed device and simulator builds passed; inspected the populated simulator review layout using a cached result. Installed and launched on the connected iPhone. No API calls were made.

## 2026-09-10 — Specific, falsifiable image analysis

Identified restrictive capture-only system wording, descriptive-only endpoint instructions and the deterministic takeaway as causes of generic reports. Added a structured image assessment with a model-written headline and up to five located/evidenced claims, provisional interpretations, alternatives, supporting and missing evidence, and verification steps. Native review displays this above existing endpoint details. Old cached reviews remain readable with an explicit paid detailed-analysis action; no automatic regeneration. See `docs/development/testable-image-reports.md`.

43 offline tests and signed/device and simulator builds passed. One paid live smoke test completed in 41.96 seconds with three structured claims (3,835 tokens); no retries. Installed/launched on the iPhone and checked the real response in the simulator. Clinical accuracy has not been validated.

## 2026-09-10 — OptoLab app name

Renamed the native app header and iPhone display name to OptoLab, and updated the native readme title. Bundle identity is preserved so existing saved captures remain associated with the same app. Signed build, device installation and launch passed.
