# Capture usability evaluation v1

## Scope and labels

First task: `capture_usability_v1`. This is an engineering benchmark for visible image quality. It is not a disease classifier or proof that footage is diagnostically adequate.

Have a human reviewer inspect the exact prepared JPEG set, before seeing Astra's answer. Assign:

- `usable`: at least one frame clearly shows the anterior eye with the corneal region in focus, adequate exposure, and no major glare/eyelid obstruction preventing visual review.
- `unusable`: the set clearly fails that rubric, including no visible eye.

Record uncertainty and disagreements separately for adjudication. Do not force uncertain cases into a binary reference label; keep them in a separate pending-label queue, report how many were excluded, and resolve the rubric with expert input. A later clinical task needs an independently established clinical reference standard.

The same source video must not create several apparently independent test cases through different crops/frame selections. For preparation comparisons, use separate reports for the same case IDs and have reviewers assess each selected set. The evaluator binds predictions to both source-video and preparation-manifest hashes, so a label for one frame selection cannot silently score another selection.

## Manifest

Copy `vision/examples/labels.template.jsonl` to `vision/data/labels.jsonl`. The template intentionally contains nulls and fails validation until actually annotated. One JSON object per line:

| Field | Meaning |
|---|---|
| `case_id` | Unique recording/case identifier, matching prediction |
| `subject_id` | Pseudonymous person ID; both eyes and every session use the same ID |
| `source_sha256` | Copy from the preparation manifest |
| `manifest_sha256` | SHA256 of the exact `manifest.json` reviewed; compute with `shasum -a 256 runs/phone-001/manifest.json` |
| `split` | `train`, `dev`, or `test` |
| `task` | `capture_usability_v1` |
| `label` | Human-assigned `usable` or `unusable` |
| `label_source` | `human_review` or `expert_adjudicated` |
| `reviewer_id` | Pseudonymous reviewer identifier |
| `device` | E.g. `iPhone 15 Pro`; record lens/settings separately when known |
| `capture_type` | E.g. `phone_unassisted`, `phone_assisted`, or `slit_lamp` |

Validation checks declared label provenance; it cannot independently prove a human made the label. Astra-generated pseudo-labels can be stored separately for development, but are rejected as the stated ground-truth source here. Synthetic fixtures test software only and must never be presented as a medical evaluation dataset.

From `vision/`:

```sh
eye-eval --labels data/labels.jsonl

eye-eval --labels data/labels.jsonl --split test \
  --predictions runs/phone-001/prediction.json runs/phone-002/prediction.json \
  --output runs/test-report.json
```

Without `--predictions`, only validate labels. With `--predictions` and no paths, score zero supplied predictions to expose full missingness. Outputs refuse to overwrite existing reports.

## Split policy

Split by person before prompt tuning. All frames, both eyes, sessions, and recording derivatives for one person stay together. The validator rejects subject or identical-source hashes appearing across splits. It does not detect unknown aliases or re-encoded near-duplicates; data curation must address those.

Use dev cases to refine prompts and preparation. Freeze the test set, prompt, model choice, and preparation settings before the final comparison. Include real phone failures (blur, glare, distance, occlusion) as well as usable footage. Keep device/capture categories in metadata for future subgroup analysis. Assisted clinical photographs do not replace self-captured phone test footage.

## Metrics implemented

The confusion table has true-label rows and `usable`, `unusable`, `abstain`, `missing` columns. The evaluator rejects duplicate, unknown-case, wrong-task, and source-hash-mismatched predictions.

- Prediction coverage: supplied cases / reference cases.
- Answer coverage: usable or unusable answers / all reference cases.
- Accuracy and class recall among answered cases.
- Class recall over all cases of that reference class, counting abstentions and missing predictions as not recovered.
- Explicit abstention/missing counts and unique-subject count.

Undefined ratios are null, never zero or a fabricated perfect score. Refusals/incomplete API responses are abstentions. API exceptions produce no valid prediction file and appear as missing if included in the reference set. Never present answered-only accuracy without coverage.

These are descriptive point estimates. Subject-clustered confidence intervals, subgroup reports, inter-reviewer agreement, diagnostic sensitivity/specificity, calibration, and mask Dice/IoU are future work. Choose sample size and acceptance thresholds with the eventual clinical target; no clinical pass threshold is invented here.

## Next experiment

Collect a small engineering pilot across multiple people and capture conditions, with appropriate permission for local use and any API upload. Review the quality rubric, inspect selected frames, run Astra, and examine every disagreement. A pilot establishes failure modes, not clinical validity. Do not train a custom model until the baseline's failures justify it.
