# Add independent iPhone eye-video preparation and Astra evaluation workflow

Close-up iPhone eye recordings cannot use the initial face-dependent detector reliably. This change adds a separate `eye-prepare` workflow that accepts recorded video directly, exports a bounded set of ranked frames and a contact sheet, and preserves preparation geometry and hashes. The Swift app can hand off a video file without importing the Python implementation.

An optional `eye-astra` command reviews the selected frames for capture usability through structured model output. It validates locally by default and sends frames only with `--send`. `eye-eval` compares results with independently declared human labels, rejects subject/source split leakage and source/preparation mismatches, and reports abstentions and missing results alongside accuracy and coverage.

## Scope

- Python commands and model adapter under `vision/`; original webcam baseline retained.
- Versioned file contracts, annotation template, runbook, activity log, evaluation plan, and data-source research notes.
- No Swift implementation changes.

## Validation

13 tests passed, including OpenAI SDK parsing against an in-memory HTTP transport. A separate synthetic CLI smoke verified preparation, local request validation, missing-key failure without a saved prediction, and evaluation of missing/answered cases. Python compilation and Git whitespace checks passed.

## Limits

This implements capture-quality experimentation. Segmentation and diagnosis remain unconfigured. Real iPhone footage and a configured API key were unavailable, so live Astra execution, device-specific decoding, and clinical accuracy remain unverified. Dataset candidates are documented, but no clinical dataset has been acquired. No performance numbers from synthetic software fixtures are presented as model results.
