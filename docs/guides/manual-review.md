# Manual Astra review in this conversation

API credentials are not required for the first review. Once the user supplies a local iPhone recording path, the assistant can run `eye-prepare`, open the selected JPEGs with its image-viewing tool, and record its own capture-quality observations. This is model inference performed interactively, not human reference annotation or an API execution.

## Procedure

1. Prepare the recording into a new ignored directory under `vision/runs/`.
2. Read the manifest and inspect each selected JPEG at its exported resolution. Use the contact sheet for navigation; do not base fine-detail judgments on thumbnails alone.
3. Apply the rubric in [evaluation.md](../research/evaluation.md): classify the supplied set as `usable`, `unusable`, or `abstain`, describe visible evidence and limitations, and cite the actual frame indices inspected. Do not infer a disease diagnosis or a healthy eye from a capture-quality decision.
4. Save `manual-prediction.json` next to the manifest, copying the exact source hash and computing the hash of the manifest bytes. Keep personal images and image-specific observations in the ignored run directory.
5. Add an activity-log entry recording completion and artifact location without copying personal findings into tracked documentation.
6. Compare with independently supplied reference labels using `eye-eval`. Do not relabel the assistant's observations as `human_review` or use them as ground truth to grade the same assistant.

## Prediction format

The following is a shape illustration, not a completed prediction. Replace placeholders only after inspecting real frames. The evaluator rejects the placeholder prediction value.

```json
{
  "schema_version": "0.2",
  "task": "capture_usability_v1",
  "case_id": "<case ID>",
  "source_sha256": "<from manifest>",
  "manifest_sha256": "<SHA256 of manifest.json bytes>",
  "prediction": "<usable | unusable | abstain>",
  "status": "completed",
  "inference_mode": "interactive_assistant_review",
  "reviewer": "Astra in the current conversation",
  "response_id": null,
  "resolved_model": null,
  "usage": null,
  "rubric_version": "capture_usability_v1",
  "review": {
    "prediction": "<same as top level>",
    "eye_visible": "<yes | no | uncertain>",
    "evidence_frame_indices": [],
    "observations": [],
    "limitations": []
  },
  "diagnosis": {"status": "not_configured"}
}
```

Record all inspected frame indices separately if needed; evidence indices must refer to actual supplied images. Leave API-specific identifiers and usage null rather than inventing them. Interactive review includes conversation context and does not reproduce an isolated API prompt; score manual and API runs in separate reports. A future API result can use the same case and hashes with a distinct prediction file.

No manual prediction has been created yet: no phone footage or eye images were available in the repository at the time this workflow was added.
