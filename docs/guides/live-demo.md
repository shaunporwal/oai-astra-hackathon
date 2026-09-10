# Live iPhone macro-camera demo

## What runs now

Open the dashboard on the Mac and select the iPhone's Continuity Camera. The browser previews the stream and sends resized JPEG frames to local Python analysis. It displays a dark-region pupil candidate, pixel diameter, raw sharpness, bright-pixel fraction, and processing time. Save a frame to retain its image and geometry; optionally send that saved image to Astra for capture-quality review.

The current dashboard explicitly reports diagnosis as unconfigured. Neither the pupil estimator nor Astra's capture-quality result establishes a disease diagnosis. The current estimator does not fit the iris, so pupil-to-iris ratio remains unavailable.

## Launch

From the repository root:

```sh
vision/.venv/bin/pip install -e 'vision[astra,live]'
vision/.venv/bin/eye-live
```

Open `http://127.0.0.1:8765` **on the Mac**. This address is not an iPhone upload page. The server binds only to loopback and does not expose the camera to the LAN.

1. Enable Continuity Camera on the iPhone and keep it nearby. USB is an option for connection stability; trust this Mac if prompted. Wireless is also supported by Apple with the documented prerequisites.
2. Attach the macro lens over the active rear camera. Verify the actual camera and framing in the preview rather than assume lens selection matches the native iPhone Camera app.
3. Click **Allow camera access** in the dashboard. This briefly opens the browser's default camera to unlock the device list, then closes it; no frames are saved or analyzed during discovery.
4. Choose the iPhone camera, then click **Start camera**. On this Mac, system camera discovery reported `Shaun Camera` with model identifier `iPhone16,1`; this is device discovery, not proof of a working browser stream.
5. Position the eye within the central image area. Turn off decorative video effects such as Portrait/Studio Light for measurement experiments. Inspect the contour; do not assume every candidate is a pupil.
6. Click **Save current frame** to retain a sample. **Stop** releases the camera.

Apple reference: [Continuity Camera setup](https://support.apple.com/en-us/102546). Browser reference: [getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia). Browser permission and phone positioning require user interaction. If the iPhone does not appear, check Apple prerequisites, connect via USB if available, close competing camera apps, and run discovery again.

## Rehearse with the existing recording

Use **Replay a video** and select root `data/img_2377.mov`. The dashboard labels this as recorded-video replay. Browser codec support may differ from OpenCV decoding; use a browser-playable export if needed. This is a development fallback and must not be presented as a live iPhone connection.

## Astra review

Put `oai_api_key=your-key` (or `OPENAI_API_KEY=your-key`) in the repository root `.env`, then restart the server and refresh the page. Both CLI entry points load that file automatically. Existing shell credentials take precedence; an explicitly empty shell `OPENAI_API_KEY` disables API access. The API key stays in Python. The send button uploads only the saved JPEG, not the continuous stream, to the existing `gpt-6-astra` capture-review adapter. The saved thumbnail remains visible so its observations are not mistaken for analysis of newer frames. Only one review runs at a time; an already completed review returns its cached result.

Without the key, local capture and geometry still work, and the UI states that Astra is unavailable. No fake model result or diagnosis is substituted. A failed API attempt can be retried manually; no automatic retries are configured.

## Outputs and measurement limits

New samples go to `vision/runs/live-<id>/` by default: `frame_00000000.jpg`, `manifest.json`, `geometry.json`, and optional `prediction.json`. These files are ignored by Git. The manifest records live-camera versus replay mode and `source_type=single_frame`; its source hash is the saved JPEG's hash, not the original video hash. Do not score it using a reference label tied to the full recording. Server receipt time is not sensor exposure time.

Frames are resized to at most 960 pixels on their longest side before analysis, with at most one browser analysis request in flight and a 200 ms pause between requests. The overlay may lag the preview. This is not a full-rate video recorder, calibrated pupillometer, or light-reflex measurement system.

The threshold/ellipse estimator is an engineering baseline. Reflections, iris shadows, dark objects, incomplete framing, eye movement, or camera changes can cause failures. Diameter is an equivalent ellipse diameter in processed pixels, not millimeters. Bright-pixel fraction misses non-clipped reflections. The 15× lens rating is not a physical calibration.

## Next clinical demonstration milestone

Choose one supported target and obtain independent reference annotations/data. For pupil geometry, implement and evaluate iris fitting and repeatability before showing a normalized ratio. A disease-inference demo needs its own defined target, reference labels, validated performance, and appropriate clinical review; changing the dashboard label does not implement diagnosis.

## Automatic local selection

Refresh the dashboard and start the camera or recorded replay. Click **Auto-select one frame** to arm a single local capture. It collects at least four candidate frames spanning 800 ms, resets on substantial candidate movement, and retains at most 2.5 seconds. It saves the highest sharpness/clipping score within that stable window using the exact analyzed JPEG. It then disarms. The Astra send button remains manual; auto-selection spends no API credits.

The prototype gates on a centered dark-region candidate, clipping, and a raw Laplacian threshold of 40 at the current processing resolution. These thresholds are engineering defaults, not calibrated eye-image quality criteria. A false pupil candidate can still pass, and a valid eye can fail. The UI's guidance describes these heuristics, not an Astra decision. Browser capability reporting lists exposed focus/exposure/zoom controls without changing settings; absence is reported explicitly. It does not establish that a reported control works on the actual phone.

Structured Astra capture actions and persistent spending limits remain the next implementation milestone. Diagnosis remains unconfigured.

## Specification-backed endpoint observations

The dashboard's Astra action now requests capture quality and all six `specs/details.json` targets in one request. Each target returns a descriptive observation, evidence indices, limitations and observed/ungradable/not_captured status. Observed means appearance can be described, not that a clinical endpoint was measured. The server attaches every specified measurement with null value and an explicit not_measured/not_calibrated status; numerical segmentation, calibration and timed-response methods are not yet connected.

Results are saved as `endpoint-prediction.json`, separately from older quality-only `prediction.json` files. Reopening a prior case and requesting the new assessment incurs a new API request; completed endpoint results are cached. The CLI remains quality-only. The target-specification hash and expanded prompt hash are recorded for reproducibility. The server rejects missing/duplicate targets, unknown evidence indices and claims that selected stills establish a light reflex. There are no additional automated API calls.
