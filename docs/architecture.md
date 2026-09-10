# Vision architecture and contract

## Boundary

```text
iPhone Camera / future Swift export
            |
        MOV or MP4
            |
    eye-prepare (local)
            |
    manifest + JPEGs + contact sheet
            |
    eye-astra (optional remote request)
            |
    prediction JSON ---- independent labels JSONL
            |                       |
            +------ eye-eval --------+
```

No Swift source, iOS build settings, or mobile dependencies are needed. There is no HTTP server or Core ML adapter yet. A future transport should preserve this file contract or introduce a separately versioned API.

## Modules

| Module | Responsibility |
|---|---|
| `cli.py`, `pipeline.py` | Original webcam/video preview and full-face Haar eye-region baseline, schema 0.1 |
| `prepare.py` | Close-up video sampling, optional rotation/ROI, quality ranking, bounded frame export, schema 0.2 |
| `astra.py` | Multi-image capture review through the Responses API; optional dependencies and explicit remote execution |
| `evaluate.py` | Label validation, subject/source split checks, case-level capture-quality metrics |

The original `eye-vision` command remains a separate exploratory detector. Use `eye-prepare` for phone close-ups. Astra sees prepared frames together in one request, rather than making a request for every video frame.

## Preparation manifest, schema 0.2

`source_sha256` identifies original video bytes. `source_name` is local metadata and is not included in the model prompt. `fps`, decoder backend/auto-rotation, OpenCV version, sampling settings, decoded/sample counts, and timestamp sources record the preparation environment. The default duration limit means the export need not represent the entire movie.

Each `frames[]` entry contains:

- `frame_index`: zero-based index in the decoded source sequence.
- `timestamp_ms`: decoder position when usable, with an FPS-derived monotonic fallback. Fallback is approximate for variable-frame-rate recordings.
- `oriented_size_wh`: image size after decoder orientation and additional manual rotation.
- `roi_xywh`: the rectangle in that oriented image, origin at top left.
- `image_size_wh`: exported dimensions after resizing; no upscaling.
- `quality`: raw brightness, Laplacian variance, and fractions at grayscale <=10 or >=245.
- `selection_score`: sharpness × (1 − dark fraction − bright fraction), for ranking only.
- `image_file`, `image_sha256`: local JPEG and its integrity hash.

Map an exported pixel back to the oriented frame using x = ROI.x + exported_x × ROI.width / exported_width, and similarly for y. Undo any rotation separately if the app needs raw sensor coordinates. No anatomical left/right eye identity is inferred.

Memory stores at most 32 resized candidates, plus the current decoded frame and contact sheet. Sampling is temporally spaced, but final ranking does not guarantee coverage of every event. No blink rate, pupil response, or other temporal physiological measure is computed.

## Astra prediction

Top-level fields include `case_id`, `task=capture_usability_v1`, `source_sha256`, `prediction`, `status`, and `review`. Prediction is `usable`, `unusable`, or `abstain`. Review includes eye visibility, cited frame indices, observations, and limitations. Requested/resolved model, response ID, prompt version/hash, preparation-manifest hash, latency, and token usage support comparison across runs.

The model is given frame indices/timestamps and JPEGs. It is not given reference labels, subject IDs, or filename-based disease hints. The adapter checks image hashes, restricts paths to the manifest directory, validates cited indices, and requires eye visibility for a usable result. These checks enforce output consistency, not diagnostic correctness.

OpenAI references: [image inputs](https://developers.openai.com/api/docs/guides/images-vision), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs). The adapter uses the documented Python `responses.parse(..., text_format=...)` interface. Offline SDK tests do not establish live API/model availability.

## Segmentation and diagnosis

Both remain `not_configured`. `EyeModel` remains an extension point in the original crop pipeline; the close-up workflow preserves candidate images for a future segmenter. Do not fabricate anatomical masks using a dark-pixel threshold or call ROI rectangles segmentation. Choose anatomy, reference masks, and a target condition first, then evaluate a dedicated segmenter or prompted model against those references.
