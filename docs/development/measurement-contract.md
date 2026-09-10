# Shared measurement contract

The image-processing modules are independent of Swift, FastAPI, browser state and Astra. `eye_vision.analysis.analyze_frame(frame, options)` is the single orchestrator used by live frame analysis, snapshots and cached-review reanalysis. It takes a decoded BGR uint8 image and validated options, and returns JSON-serializable results.

```python
from eye_vision.analysis import analyze_frame
result = analyze_frame(frame, {
    "target": "redness",
    "roi": [0.1, 0.2, 0.3, 0.4],  # normalized x, y, width, height
})
```

Options permit only `geometry` or `redness` targets and an optional in-bounds finite rectangle. HTTP transports these options in `x-analysis-options` on the existing JPEG frame/snapshot endpoints. The snapshot manifest persists the exact options. Default options retain the previous geometry behavior for existing API callers.

`measurements.Measurement` is the common value contract: target ID, measurement name, unit, nullable value, status, reason, method, source and validation flag. `measurements.redness` implements only candidate-vessel segmentation. Existing geometry/iris modules implement the separate pupil ratio. Each module has its own evidence/rejection rules; absence of pupil geometry cannot block redness analysis.

`endpoints.attach_measurements` joins values to specification targets by `(target_id, name)`. It contains no segmentation code. `attach_geometry` is retained as a compatibility alias. The `saved_geometry` response field and `geometry.json` filename remain for compatibility but now contain the shared schema 0.4 result. `save_analysis` is the sole writer for analysis JSON and mask artifacts.

The browser uses one annotation renderer for live and saved images, one request-options serializer, and one stable-window retention algorithm. Redness supplies local eligibility, score and a 16×16 appearance signature; pupil geometry retains its geometry-specific gate. Candidate buffers retain the exact JPEG together with its region, target and live/replay provenance. Region revisions reject stale live-analysis responses.

No native camera adapter or Swift source changed. No automatic paid request was introduced. A future Swift client can send the same JPEG/options contract; LAN transport, authentication and native camera controls are separate integration work.
