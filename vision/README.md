# Eye vision pipeline

Independent Python workspace for webcam prototyping and replaying videos captured by the Swift app.

```sh
cd vision
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
eye-vision --camera 0
```

Allow camera access for the launching application in macOS System Settings → Privacy & Security → Camera. Press **s** to save a frame, eye crops, and JSON; **q** quits. Nothing is saved until requested. Captures stay local under ignored `vision/runs/` when launched from this directory. A saved frame includes the surrounding face/background.

Replay a mobile recording or sample frames without a window:

```sh
eye-vision --video /path/to/eyes.mov --headless --save-every 15 --max-frames 300
```

Current baseline uses OpenCV's bundled pretrained Haar face/eye detectors. Rectangles are candidate eye regions, not anatomical masks. Detection can miss close-up eyes without a full face and can produce false positives. Brightness and Laplacian variance are raw quality measurements, not calibrated acceptance thresholds.

## Swift handoff

Initially exchange video files. `Pipeline.analyze(frame)` accepts an upright uint8 BGR image and returns JSON-safe results. Swift RGB buffers need RGB→BGR conversion in a future adapter. Coordinates are pixels relative to the analyzed, unmirrored frame, origin top left; `bbox_xywh` is x, y, width, height. No anatomical left/right identity or tracking is inferred. File timestamps use decoder position; webcam timestamps are elapsed host time, not sensor timestamps.

Each result includes `schema_version`, `image_size_wh`, `detector`, and `eyes`. Saved samples add `frame_index`, `timestamp_ms`, and relative `crop_file` paths. The Python module and CLI have no dependency on Swift project files. An HTTP or Core ML adapter can follow once deployment requirements are known.

## Model implementation next

Implement the `EyeModel` protocol and pass it to `Pipeline(model=...)` to analyze each detected crop. Segmentation and diagnosis currently report `not_configured`; no disease predictions are fabricated. Choose the target anatomy/condition and labeled dataset before selecting/training a model. A segmentation implementation should specify mask classes, dimensions, and crop-relative coordinates; a diagnostic implementation needs independently evaluated performance and an abstention policy.

A webcam is useful for capture, framing, and integration experiments. Clinical usefulness of its images has not been established here. This scaffold does not diagnose conditions.

Detector reference: https://docs.opencv.org/4.12.0/db/d28/tutorial_cascade_classifier.html

Run checks: `python -m unittest discover -s tests`.
