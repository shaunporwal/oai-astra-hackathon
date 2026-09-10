# Experimental pupil-to-iris ratio

## Use

Refresh the local dashboard, select the iPhone camera and start capture. The **current live frame** card shows a ratio only when both heuristic fits pass their checks. Green/cyan marks the pupil; magenta marks the fitted outer iris boundary. **Save current frame** stores the exact JPEG and its geometry. The saved image displays both ellipses and a separate saved-frame ratio. This requires no Astra request.

The Astra action assesses the saved image and attaches its local ratio to the pupil/iris endpoint. The number is computed by Python, not inferred by Astra. Cached endpoint reviews gain recomputed saved-image geometry without a new API request. Other quantitative endpoints remain unimplemented. A rejected measurement is null with a reason, not zero or a normal result.

## Capture to try next

Keep the macro attachment over the selected camera. Center the pupil, hold the camera as directly facing the eye as practical, and keep as much of the outer iris boundary visible as possible. Make small distance/angle adjustments to improve focus and move reflections away from the boundaries. Hold a successful view steady for roughly two seconds. No torch or light stimulus is enabled by this software.

Auto-selection now requires accepted iris geometry as well as the stable-window checks. It can therefore decline to save indefinitely; cancel and use manual capture to inspect a candidate. The current recording did not produce a stable automatic selection in the offline scan. A steadier view is the next useful user contribution, but segmentation improvement also remains necessary.

## Method and limitations

The pupil estimator fits a dark-region contour. Iris fitting searches outward from the pupil for positive intensity transitions, robustly initializes an ellipse, and rejects insufficient angular support, inconsistent geometry, implausible scale and clipped fits. The ratio is `sqrt(pupil_major * pupil_minor) / sqrt(iris_major * iris_minor)`. It is dimensionless, not millimeters. The support score is not a probability of anatomical correctness. No learned eye verification, clinical calibration or disease classification is implemented.

Synthetic tests cover known ratios at multiple scales and rotations, missing iris edges, heavy occlusion, JPEG snapshots and exact saved-image integration. The absolute synthetic-ratio tolerance is 0.025; that is a software-test criterion, not a real-image accuracy claim.

Final offline scan of the existing recording sampled 76 frames (every sixth decoded frame, longest side 960 px). Five passed geometry checks: 84, 102, 126, 132 and 258, with ratios approximately 0.344, 0.333, 0.318, 0.312 and 0.331. Mean local analysis time was about 11.6 ms on this Mac, excluding video transport. None satisfied the stable auto-selection window. These values are not a light-reflex trajectory or clinical findings.

An unblinded assistant visual check of frame 102 estimated roughly 0.295 versus the automatic 0.333; the pupil fit appears to include superior shadow. These rough annotations are not independent ground truth. A prepared JPEG previously accepted by an intermediate version was rejected after the pupil-threshold fix. This demonstrates remaining sensitivity to fitting and image encoding. Do not report measurement accuracy from this recording.

## Reproduce and evaluate

From the repository root:

```sh
vision/.venv/bin/python vision/scripts/check_geometry.py data/img_2377.mov --output vision/runs/new-geometry-check
vision/.venv/bin/python -m unittest discover -s vision/tests -q
node vision/tests/test_selector.cjs
```

The output directory must be new. The script saves accepted overlays and all sampled geometry/rejection diagnostics. Existing results and approximate manual checks are ignored under `vision/runs/geometry-final/`.

Next evaluation requires independent pupil and outer-iris annotations on multiple frames and participants, including reflections, occlusion, off-axis views and non-eye negatives. Measure boundary error, ratio error, false acceptance, abstention and repeatability separately. The current heuristic produces numbers but is not yet reliable enough to call a validated endpoint.
