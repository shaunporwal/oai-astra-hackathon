# Clinical value and product direction

Reviewed 2026-09-10. This is a focused evidence assessment and project recommendation, not proof of this prototype's clinical performance. The iPhone 15 Pro / 15× attachment / Astra combination has not been validated by the studies below.

## What is worth pursuing

The strongest near-term project hypothesis is guided acquisition of reviewable anterior-eye images for a remote clinician, with repeatable documentation and explicit capture failures. This is a recommendation inferred from the imaging literature. Convenience becomes clinical value only if the workflow helps clinicians make appropriate decisions, avoids missed findings and reduces unusable captures or repeat visits. Neither a visually impressive overlay nor a six-field report establishes that benefit.

Patient-operated imaging is a relevant acquisition problem. A retrospective study examined 344 patient-captured images and evaluated an attachment plus imaging protocol; in a masked comparison, 63 of 120 observer responses rated protocol-assisted images suitable for clinical decision-making. The denominator is ratings, not patients or diagnostic accuracy. [Anterior segment imaging using a simple universal smartphone attachment for patients](https://pubmed.ncbi.nlm.nih.gov/34334091/).

A field study of 54 patients compared iPhone photography with an inexpensive macro attachment and used ophthalmologist image grading. Overall clinical utility did not significantly differ; the authors proposed complementary views and stated that clinically measurable outcomes remained future work. This supports investigating capture workflows, not assuming every macro attachment improves every target. [Bhatter et al., 2020; DOI 10.1089/tmj.2019.0152](https://pubmed.ncbi.nlm.nih.gov/32031913/).

A diagnostic-accuracy study used a smartphone attachment supplying magnification and illumination, with trained human image graders and slit-lamp examination as reference. For corneal opacity, default smartphone settings yielded 68% sensitivity and 97% specificity. This demonstrates a real clinical task and a material missed-case limitation; it does not validate a generic 15× lens, arcus identification, or autonomous Astra diagnosis. [Smartphone-based anterior segment imaging: comparative diagnostic accuracy study](https://pubmed.ncbi.nlm.nih.gov/34607500/), [full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC8977419/).

## How the six targets relate to clinical value

| Target | Potential relevance | Project decision / current limit |
|---|---|---|
| Pupil/iris ratio | Normalized geometry can support a standardized pupillometry workflow. | Engineering milestone; an isolated uncontrolled ratio has no disease interpretation in this project. Improve boundary accuracy and repeatability before extending to response measurements. |
| Timed pupil response | Controlled smartphone pupillometry has been compared with infrared measurement. | Requires a new acquisition protocol and reference system; the cited 15-person healthy study does not establish neurological diagnosis. |
| Conjunctival redness / vessel coverage | Quantitative redness could support standardized documentation and monitoring research. | Worth investigating next with expert grades and consistent views. Slit-lamp vessel-density association does not establish dry-eye/allergy diagnosis or macro-image transfer. |
| Scleral chromaticity | Calibrated color has been studied against bilirubin in cirrhosis. | Separate lab-linked research program. The cited model was fitted and evaluated on the same samples, so its reported correlation is not independent predictive validation. |
| Palpebral conjunctival color | Studied as an anemia-screening signal. | Separate anatomy and capture task, with substantial individual hemoglobin errors; not a substitute for a lab test. |
| Peripheral opacity / arcus | A visible corneal appearance can be documented for clinical review. | Arcus is not equivalent to general corneal opacity or a cholesterol measurement. Prioritize clinician-defined visible findings over systemic-risk claims. |

Primary target evidence and limits: [pupillometry](https://doi.org/10.1097/OPX.0000000000001289), [vessel metrics](https://pmc.ncbi.nlm.nih.gov/articles/PMC13359948/), [bilirubin](https://journals.plos.org/digitalhealth/article?id=10.1371/journal.pdig.0000357), [anemia](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0302883), [arcus/CVD cohort](https://pubmed.ncbi.nlm.nih.gov/19101231/). See the [literature review](literature-review.md) for citations and methods.

## Proposed next evidence milestone

Choose one clinical workflow with an ophthalmologist, such as remote review of anterior-eye photographs. Compare unguided and guided capture using independently graded image usability for that specific task. Track time to adequate capture, recapture rate, failure by tissue/view and whether the clinician can answer the intended question. A later diagnostic study must compare with the appropriate in-person reference and report missed cases, false positives and ungradable images on participant-held-out data.

For this repository, continue building capture reliability and use the pupil ratio as a segmentation test. For a clinically meaningful demonstration, show how guided capture yields evidence a clinician can inspect, and clearly separate model observations from measured values and clinical decisions. This recommendation does not change the app into a validated triage or diagnostic service.
