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
