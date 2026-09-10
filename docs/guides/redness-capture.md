# Conjunctival vessel capture prototype

## Use

Refresh the dashboard. **Conjunctival vessels** is the default capture target; **Pupil / iris** remains available separately. Connect the rear iPhone camera and macro attachment as before. Drag a rectangle entirely inside the exposed white-eye surface, excluding iris, eyelids and skin. The app does not verify that your rectangle is conjunctiva. A cyan rectangle shows the selected region and pink polygons show candidate vessels.

The live **Vessel candidates** value is candidate vessel pixels divided by valid selected-region pixels, displayed as a percentage. Save a frame to retain the exact JPEG, region coordinates, geometry, candidate-vessel mask and valid-pixel mask. The saved thumbnail uses the same overlay renderer as the live view. These local operations require no API request.

Auto-selection uses detail and appearance stability inside this region and does not require a pupil or iris fit. Clearing/changing the region or target resets the selection window. Move the eye out of the rectangle and the region becomes invalid in meaning even if the heuristic still computes a number; reselect it. There is no anatomical tracking yet. Capture options are frozen with a selected frame so delayed saves do not apply a newer rectangle to an older image.

Astra assessment still requires the explicit send action. The local measurement is joined to `conjunctival_hyperemia.vessel_area_fraction`; it is not a model-inferred number. The description remains a whole-image Astra observation, while the numeric value applies only to the specified region. Tortuosity and clinical redness grades remain unimplemented. This is not a diagnosis or a treatment recommendation.

## Method

The detector combines dark linear features in the green channel with relative red excess, then retains elongated connected components. It excludes very dark and clipped pixels from the denominator. It rejects absent/tiny regions, poor exposure, low local detail and excessive fragmentation. All thresholds are unvalidated engineering defaults. Pixel-scale morphology can change with camera distance, resolution and compression. Exclusion masks are optical proxies, not anatomical masks.

The result is explicitly candidate vessel coverage. Shadows, reflections, pigmentation, skin, blur and white balance can cause false positives or missed vessels. Zero candidates does not imply a normal eye or absence of vessels. Do not compare numbers across sessions as clinical change until capture regions, illumination, scale and repeatability are established.

## Artifacts and software verification

Each saved case includes `manifest.json` with normalized `analysis_options.roi`, `geometry.json` containing shared analysis schema 0.4, and (when a result is available) ROI-sized `vessel_mask.png` / `valid_mask.png`. The region's pixel origin and dimensions are in `redness.roi_xywh`. Stale masks are removed if reanalysis becomes ungradable. Original JPEGs remain unannotated for model input; annotations are a display layer.

Synthetic tests check known red-line mask overlap (Dice >0.9), exact numerator/denominator accounting, grayscale-line rejection, invalid regions, blurred/dark/tiny regions and API persistence. These are engineering checks, not clinical validation. Browser checks use a simulated camera and synthetic images.

An assistant-selected region `[0.83, 0.30, 0.13, 0.24]` on prepared frame 120 produced zero candidates with local sharpness about 15.1. Visual inspection found soft detail. Results are ignored under `vision/runs/redness-check/`; this is neither a reference label nor a successful real-vessel validation.

Next data needed: sharply resolved conjunctival views and independently annotated tissue/vessel masks and redness grades. Compare guided versus unguided capture adequacy first, then segmentation error and repeat-capture variability. The current pupil-centered recording is insufficient to validate this workflow.
