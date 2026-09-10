# Proposed macro-video targets: feasibility assessment

Assessed 2026-09-10. Imported `specs/details.csv` from `origin/main` commit `050076daef3a0d86ef81852d8a307b4b5fbea09c`. `specs/details.csv` preserves the six original proposals. `specs/details.json` is now a revised, versioned research target specification, with corrected definitions, evidence IDs, capture requirements, and explicit unsupported claims. It supersedes the earlier verbatim JSON conversion. See [literature-review.md](literature-review.md) for presentation citations and study results.

## Decision

Use these as candidate research measurements. They are not yet validated biomarkers or qualified clinical-trial endpoints. Our inference from the literature and the first clip is that pupil geometry is the best first implementation target, followed by exploratory conjunctival redness once framing and illumination are standardized. A 15× macro attachment can help resolve detail but does not establish pixel-to-mm scale, calibrated color, or disease specificity.

| Source target | Engineering endpoint to use | Phone + 15× macro feasibility | Current recording |
|---|---|---|---|
| Scleral yellowness | Color-calibrated scleral chromaticity, with vessels/reflections excluded | Plausible with device/attachment and illumination calibration; raw Lab b* alone is only an image descriptor | Limited scleral coverage, substantial reflections, and no color reference; cannot estimate serum bilirubin |
| Conjunctival redness | Redness index and vessel area / valid conjunctival ROI area, reported separately from tortuosity | Plausible if fine vessels and a standardized region are resolved; validate masks and repeatability | Exploratory only; iris-centered framing is not a dedicated conjunctival capture |
| “Sclera pallor” | Correct the target to palpebral conjunctival color for anemia research | Different tissue view and a supervised capture protocol are needed, plus lab hemoglobin labels | The inner lower eyelid is not adequately exposed; unsuitable for this proposed anemia target |
| Static pupil size | Pupil-to-visible-iris diameter ratio, in pixels/pixels | Best first target; requires fitted boundaries, sufficient visible limbus, gaze/occlusion checks | Several frames are candidates for a geometric prototype; no validated value computed yet |
| Dynamic pupil light reflex | Time-aligned normalized diameter curve, percent constriction, latency; absolute velocity only with spatial calibration | Conditional on a known stimulus and accurate timestamps; use the full video rather than selected stills | About 30 fps, no documented stimulus onset/protocol; spontaneous size change is not a validated PLR measurement |
| Corneal arcus | Expert-labeled peripheral corneal opacity presence/extent | Possible research target if the relevant corneal region is visible and reflections distinguished from opacity | No arcus determination made; reflections/occlusion prevent treating a bright rim as a confirmed finding |

The current-clip column records capture constraints from the earlier review, not a medical assessment of the person.

## Corrections and evidence

### Pupil geometry and light response

Keep `PIR = pupil_diameter_px / visible_iris_diameter_px` dimensionless. Do not substitute a population-average 11.8 mm iris diameter as a person's measured calibration. Likewise, the lens's advertised 15× magnification does not give a mm/pixel scale. Record fitting convention, gaze, boundary visibility, and uncertainty.

Correct percent constriction to `100 * (D_baseline - D_min) / D_baseline`, with a defined pre-stimulus baseline. The CSV's expression is mangled. Constriction velocity is a time derivative; normalized units per second are possible without mm calibration, but mm/s is not. Latency requires stimulus timing. A published iPhone study used 120-fps video, a defined light stimulus, and pupil/limbus ellipse fits; this supports feasibility under its protocol, not equivalence of our 30-fps macro recording. [iPhone pupillometry study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6166694/)

Pupil size alone does not establish intoxication, autonomic dysfunction, concussion, or brainstem injury. Do not build those diagnoses as direct mappings from a single ratio or curve. Their evaluation would require independent clinical references and relevant confounder controls.

### Color and redness

A smartphone bilirubin study explicitly corrected ambient/device variation using a color chart or calibrated flash/no-flash imaging. Our engineering interpretation is that uncalibrated video b* values cannot be carried directly to bilirubin estimates across captures. [Bilirubin imaging study](https://pmc.ncbi.nlm.nih.gov/articles/PMC10558070/)

Vessel density and tortuosity are distinct endpoints. Density is the fraction of valid conjunctival pixels occupied by vessels; tortuosity describes vessel-path curvature. A slit-lamp study found much stronger association of density than tortuosity with manual redness grades. This is evidence for a candidate metric, not proof of performance with our attachment. [Vascular metrics study](https://pmc.ncbi.nlm.nih.gov/articles/PMC13359948/)

Redness does not uniquely identify dry eye or allergy. Remove the blanket claim that our derived metric is a core primary endpoint for drug trials: endpoint acceptability depends on the specific indication, protocol, validated measurement, and intended interpretation.

### Pallor and arcus

The anemia proposal should refer to the palpebral conjunctiva, not scleral whiteness. Smartphone research used this tissue and paired images with laboratory hemoglobin. Neither a lower a* value nor reduced apparent vessels alone measures perfusion or establishes anemia. [Prospective smartphone anemia study](https://pmc.ncbi.nlm.nih.gov/articles/PMC11090304/)

Arcus is a peripheral corneal finding, not the iris boundary itself. An intensity ring needs expert adjudication to distinguish it from normal boundary appearance, reflections, and other opacities. Its presence is not a lipid concentration or cardiovascular-risk score: in the Framingham study, the cardiovascular association was no longer predictive after age/sex adjustment. [Framingham arcus study](https://pmc.ncbi.nlm.nih.gov/articles/PMC2636700/)

## Implementation and evaluation order

1. Prototype pupil and visible-iris boundary fitting on the supplied clip. Save overlays and dimensionless ratios, abstaining when boundaries are clipped/obscured. Independently annotate selected frames to measure boundary error and ratio error. Do not call frames independent patients.
2. Establish repeat-capture reliability with the same attachment and fixed documented capture conditions. Then evaluate on different people and sessions.
3. Add a dedicated conjunctival framing/quality mode and exploratory redness metric. Validate against annotated regions/vessels and expert grades.
4. Pursue calibrated color, timed reflex, or arcus only after the corresponding protocol and reference labels are available. These require different capture requirements; one generic clip need not serve all six.

A trial endpoint additionally needs a defined region, units, aggregation/timepoint, missingness rule, repeatability, and evidence of clinical meaning/responsiveness. No dataset or trial-endpoint qualification has been established by importing this list.
