# Data acquisition and research leads

Research checked on 2026-09-10. No patient dataset or diagnostic weights have been downloaded into this repository. No iPhone recording has been supplied yet. The software tests generate synthetic fixtures in temporary directories.

## Immediate data

Use original iPhone 15 Pro recordings for capture-quality development. Store originals under ignored `vision/data/` and exports under ignored `vision/runs/`. Keep subject identifiers pseudonymous and document permission, capture conditions, and whether remote analysis is permitted in the local data record. Keep API-upload permission distinct from permission to record. Raw footage is not a Git artifact.

Start with the [annotation template](../vision/examples/labels.template.jsonl) and [evaluation rubric](evaluation.md). Capture-quality labels are human visual judgments; disease labels must come from appropriate clinical reference evidence. The user's own recording can exercise ingestion but cannot establish disease-classification accuracy.

## Candidate resources

These are research leads, not a claim that assets have been obtained or licensed for this project. Full-text fetches for several articles hit publisher/browser checks; the descriptions below are limited to indexed primary-source text. Recheck the actual repository, access conditions, and label schema before acquisition.

| Resource | Potential use | Gap and next action |
|---|---|---|
| [MCOA dataset paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC12125280/) | Describes anterior-segment photographs, AS-OCT, and cornea/pupil/opacity annotations; the article reports a public Figshare archive | Candidate for anatomical segmentation. Resolve the linked archive and verify its license, patient IDs, and mask format. Its clinical imaging should be evaluated separately from phone footage. |
| [DeepMonitoring](https://pmc.ncbi.nlm.nih.gov/articles/PMC11385315/) | Smartphone corneal image-quality study; directly relevant to quality failure categories | Access and reuse rights not verified. Inspect the protocol and data-availability statement before treating it as obtainable training data. |
| [Keratitis screening study](https://www.nature.com/articles/s41467-021-24116-6) | Uses slit-lamp development data and smartphone evaluation; illustrates the need to test capture-domain changes | Not an iPhone 15 Pro self-capture benchmark. Dataset access is unverified here; do not carry its reported performance over to Astra or our pipeline. |

The MCOA paper describes 205 normal anterior-segment JPEGs as one subset and separately lists OCT imagery. Do not combine OCT and ordinary camera images into one input modality or mistake image counts for independent patients. Source: [MCOA data records](https://pmc.ncbi.nlm.nih.gov/articles/PMC12125280/).

## Acquisition record required per source

Record the source URL/version, license/access terms, image modality/device, patient grouping, available annotations, label provenance, file hashes, and intended train/dev/test usage. Keep model-created annotations clearly separate from reference annotations. Public availability alone does not tell us whether the data matches our target or has independent diagnostic labels.

## Decisions still needed

Select the first clinical finding/condition and identify an expert/reference-label source. Then prioritize one matching dataset and a separate phone test set. Until then, the executable benchmark is capture usability, and segmentation/diagnosis remain explicitly unconfigured.
