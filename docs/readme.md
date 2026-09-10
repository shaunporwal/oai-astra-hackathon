# Documentation

Start with the [iPhone runbook](guides/iphone-runbook.md) for capture and processing, or the [literature review](research/literature-review.md) for presentation preparation. Current implementation status and completed checks are recorded in the activity log.

## Guides

- [On-device image library](guides/image-library.md): local storage, reopening images/reviews and offline behavior.

- [Minimal iPhone demo](guides/minimal-iphone-demo.md): shortest capture-to-Astra setup and current installation step.

- [Backup iPhone app](../ios/backup/readme.md): native capture, signing, pairing and installation.

- [Redness capture](guides/redness-capture.md): region selection, candidate vessel masks and limitations.

- [iPhone runbook](guides/iphone-runbook.md): recording, transfer, preparation, and optional API use.
- [Manual Astra review](guides/manual-review.md): interactive review without an API key.

- [Pupil ratio](guides/pupil-ratio.md): experimental measurement, overlays, recapture guidance and observed limitations.

## Research

- [Clinical value](research/clinical-value.md): evidence, endpoint relevance and proposed clinical workflow.

- [Literature review](research/literature-review.md): paper links, results, limitations, and slide wording.
- [Target feasibility](research/target-feasibility.md): which measurements fit the macro capture setup.
- [Data sources](research/data-sources.md): acquisition notes, dataset candidates, and capture provenance.
- [Evaluation](research/evaluation.md): annotation schema, split policy, and metrics.
- [Healthcare boundaries](research/healthcare-boundaries.md): research versus patient-facing medical use.

The machine-readable target specification is [specs/details.json](../specs/details.json); the unmodified source proposal is [specs/details.csv](../specs/details.csv).

## Development

- [Recoverable reviews](development/review-jobs.md): timeout diagnosis, job polling and combined segmentation overlays.

- [OptLab integration review](development/optlab-integration-review.md): partner branch, reuse plan and shared-client bridge.

- [Measurement contract](development/measurement-contract.md): shared analysis API and module boundaries.

- [Architecture](development/architecture.md): module boundaries and output contracts.
- [Guided capture plan](development/guided-capture-plan.md): camera control, automatic frame selection, Astra feedback, and proposed spending limits.
- [Activity log](development/activity-log.md): implementation history, checks, and outstanding work.
- [PR description](development/pr-description.md): review summary of the capture/evaluation implementation.

## Where new files belong

Put operating instructions in `guides/`, scientific evidence and evaluation design in `research/`, and implementation history or design in `development/`. Keep executable target definitions in root `specs/`. Add links here when adding documentation. Use lowercase filenames throughout.

Store recordings in root `data/` and generated images/predictions in `vision/runs/`; both are Git-ignored. Personal observations belong with the local run, while the activity log records artifact locations and engineering findings.

[Live demo guide](guides/live-demo.md): select the iPhone Continuity Camera on the Mac, view local overlays, and optionally request Astra review.
