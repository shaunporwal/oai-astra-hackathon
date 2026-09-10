# Activity log

## 2026-09-10 — Initial independent vision branch

Created `feat/eye-vision-pipeline` in an empty repository and committed the initial scaffold as `d625bb2` (`Add independent eye vision capture pipeline`). Added webcam/video preview, OpenCV Haar face/eye ROI detection, sample/crop export, a Python model extension point, and JSON output. Three unit tests and a synthetic-video replay/export check passed. No live webcam was exercised.

## 2026-09-10 — iPhone input, Astra adapter, and evaluation tooling

### Requested scope

Use iPhone 15 Pro footage immediately, keep the Swift app owned by the partner, implement the Python analysis/evaluation side, and maintain Markdown documentation under `docs/`. A PR documentation skill was requested if available. Searched the installed skills/catalog and found no matching PR documentation skill; wrote `docs/pr-description.md` using the repository work and developer PR-writing guidance instead.

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
