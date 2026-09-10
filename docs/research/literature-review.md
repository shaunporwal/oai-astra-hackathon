# Literature for the macro-eye presentation

Reviewed 2026-09-10. Primary studies below ground the revised [details.json](../../specs/details.json); IDs L01–L05 match its references. This is a focused evidence review, not a systematic review. “Supported in a study” does not mean proven across devices, populations, or use cases. None of these papers validates our exact iPhone 15 Pro + 15× attachment + Astra pipeline.

## L01 — Pupil geometry and light response

**McAnany JJ, Smith BM, Garland A, Kagen SL.** iPhone-based Pupillometry: A Novel Approach for Assessing the Pupillary Light Reflex. *Optometry and Vision Science*. 2018;95(10):953–958. [DOI / publisher](https://doi.org/10.1097/OPX.0000000000001289) · [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC6166694/)

- **Study:** 15 visually normal participants; controlled iPhone 6S flash/120-fps recording versus infrared pupillometry.
- **Finding:** Maximal-constriction correlation r=0.91; bias-corrected limits of agreement of approximately 9%.
- **Limit:** Small laboratory study; latency agreement and neurological disease detection were not established.
- **Presentation wording:** “Controlled smartphone pupillometry has demonstrated agreement with a laboratory comparator.”

For our project: begin with a dimensionless pupil/iris ratio. Timed reflex testing requires a separate acquisition protocol; our ordinary recording is not that experiment. Use Results/Figure 3 for the method comparison, and retain the healthy-cohort limitation on the slide.

## L02 — Calibrated scleral color and bilirubin

**Nixon-Hill M, Mookerjee RP, Leung TS.** Assessment of bilirubin levels in patients with cirrhosis via forehead, sclera and lower eyelid smartphone images. *PLOS Digital Health*. 2023;2(10):e0000357. [DOI](https://doi.org/10.1371/journal.pdig.0000357) · [Full text](https://journals.plos.org/digitalhealth/article?id=10.1371/journal.pdig.0000357)

- **Study:** Cirrhosis cohort; device/lighting correction and serum bilirubin reference.
- **Finding:** Scleral comparison r=0.89, n=66, for the reported S8 analysis (Figure 6).
- **Limit:** Correlation is not individual diagnostic accuracy; this was calibrated imaging. The Methods describe fitting and evaluating the regression on the same samples, rather than independent held-out validation.
- **Presentation wording:** “Calibrated scleral smartphone imaging has shown association with serum bilirubin.”

For our project: raw b* can be explored as an image feature, but a serum estimator needs paired lab data and capture calibration. The paper reports [anonymized research data](https://doi.org/10.5522/04/24083487.v1); contents and reuse terms have not been checked here.

## L03 — Inner-eyelid imaging and anemia

**Zhao L, Vidwans A, Bearnot CJ, et al.** Prediction of anemia in real-time using a smartphone camera processing conjunctival images. *PLOS ONE*. 2024;19(5):e0302883. [DOI](https://doi.org/10.1371/journal.pone.0302883) · [Full text](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0302883)

- **Study:** Prospective ED sample; RAW palpebral-conjunctival images; 435 recruited, 426 analyzed.
- **Finding:** Reported anemia accuracy 75.4% (95% CI 71.3–79.4%); Hb agreement limits −4.73 to +4.93 g/dL.
- **Limit:** Wide individual errors; tissue was inner eyelid, not white sclera.
- **Presentation wording:** “Conjunctival imaging is a researched anemia-screening approach with substantial measurement uncertainty.”

For our project: correct the anatomy and design a separate capture task. Figure 4 is useful for explaining why a promising classification result does not imply precise hemoglobin measurement.

## L04 — Vessel density and hyperemia grading

**Wong D, Ng Y, Eppenberger LS, et al.** Conjunctival Vascular Metrics Using Automated Vessel Detection from Slit Lamp Images for Hyperemia Severity Assessment. *Diagnostics*. 2026;16(13):2066. [DOI / publisher](https://doi.org/10.3390/diagnostics16132066) · [PubMed](https://pubmed.ncbi.nlm.nih.gov/42449848/) · [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC13359948/)

- **Study:** Slit-lamp photographs from 139 glaucoma patients; 103 development participants, remainder validation.
- **Finding:** Vessel-density Spearman rho with mean Efron grades: 0.78 and 0.80; tortuosity below 0.23.
- **Limit:** Different imaging/cohort; no qualification of our metric as a trial endpoint.
- **Presentation wording:** “Conjunctival vessel coverage has correlated with expert redness grading in slit-lamp studies.”

For our project: prioritize vessel coverage over tortuosity, then test macro-image transfer. Tables 1–2 distinguish these metrics. This is not evidence that redness alone identifies dry eye or allergy.

## L05 — Arcus and cardiovascular interpretation

**Fernandez AB, Keyes MJ, Pencina M, D'Agostino R, O'Donnell CJ, Thompson PD.** Relation of corneal arcus to cardiovascular disease (from the Framingham Heart Study data set). *American Journal of Cardiology*. 2009;103(1):64–66. [DOI](https://doi.org/10.1016/j.amjcard.2008.08.030) · [PubMed](https://pubmed.ncbi.nlm.nih.gov/19101231/) · [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC2636700/)

- **Study:** Longitudinal cohort analysis, 23,376 person-exams; repeated exams are not independent people.
- **Finding:** The cardiovascular association was not significant after age/sex adjustment.
- **Limit:** One cohort; no automated-image validation or universal conclusion about every population.
- **Presentation wording:** “Arcus appearance must be distinguished from a validated cardiovascular-risk prediction.”

For our project: any image target is peripheral corneal appearance with expert labels. Do not equate a bright ring with cholesterol concentration.

## What changed in the target specification

These are project decisions based on the evidence above, not claims that the studies implemented our software:

| Original proposal | Revised specification |
|---|---|
| Yellow-blue color → liver diagnosis | Calibrated color research; lab-linked validation required |
| Tortuosity / red fraction → established trial endpoint | Separate vessel coverage and tortuosity; expert grading and repeatability studies |
| Scleral whiteness → anemia | Correct tissue to palpebral conjunctiva; separate capture and hemoglobin reference |
| Pupil ratio × assumed 11.8 mm → clinical inference | Dimensionless geometry; no person-specific mm scale assumed |
| Generic video → concussion/brainstem screening | Protocol-dependent pupil response; no neurological diagnosis asserted |
| Bright peripheral ring → cholesterol/CVD risk | Exploratory appearance detection; systemic claims removed |

Correct percent constriction: `100 × (D_baseline − D_min) / D_baseline`, with a prespecified baseline tied to a known stimulus. Derivative units are ratio/second unless a physical scale is validated. These definitions are explicit in the JSON.

## Suggested presentation narrative

1. **Demonstrated precedent:** Published work supports selected ocular image measurements under controlled conditions (L01–L04).
2. **Our prototype today:** We decoded and manually reviewed one macro-eye video. No biomarker accuracy or clinical diagnostic performance has been measured.
3. **First milestone:** Pupil/iris boundary fitting, dimensionless ratio, independent annotations, and repeat-capture reliability.
4. **Validation gap:** Compare subjects and capture sessions against suitable references before making clinical claims. Trial use requires endpoint-specific validation beyond this prototype.

All suggested slide sentences above are paraphrases, not direct quotations. Use the DOI links in your bibliography and the full-text pages' PDF buttons to obtain papers. Figures are pointers for review, not a statement that reuse permissions have been checked. No paper PDFs were downloaded in this pass. Publisher pages supplied full text for L01–L03; L04 was checked through indexed primary article/PubMed content; L05 through PubMed and primary article content.

## Clinical product direction

See [clinical value](clinical-value.md) for additional patient-operated capture, iPhone macro field-imaging and corneal-opacity diagnostic-accuracy studies, plus recommendations for choosing a clinical workflow.
