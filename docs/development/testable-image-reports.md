# Testable image reports

## Why the previous report was limited

The original system prompt explicitly prohibited diagnosis, the endpoint prompt requested descriptive visual observations only, and the response schema had no interpretation field. The native Main takeaway was a deterministic list of visible target names with a fixed disease-status statement. This constrained the report independently of model capability. The six targets also include measurements that a single uncalibrated still cannot supply; more assertive prose cannot substitute for those measurements.

## Updated contract

Endpoint reviews use prompt version `capture-endpoints-v2`. A required structured `image_assessment` contains an image-specific headline, short synthesis, and up to five testable claims. Each claim contains:

- A direct visual assertion, image-relative location and supplied source frame indices.
- Qualitative confidence in visibility, not a disease probability.
- A leading provisional interpretation and a competing explanation.
- Supporting evidence, contradictory or missing evidence, and a practical verification step.

Named conditions are permitted as evidence-grounded hypotheses. The prompt does not require pathology or fill a quota of findings. Normal anatomy and acquisition artifacts are legitimate alternatives. Confirmed diagnoses, invented quantitative values, unsupported systemic inference, treatment recommendations and fabricated citations remain excluded. Model hypotheses can be wrong; this structure makes errors inspectable and does not establish clinical validity.

Python validates source frame references, rejects eye findings when no eye is visible, and checks required interpretation fields. These checks validate report structure, not medical accuracy. The original six-target measurement contract and local measurement gates remain unchanged. Capture-only CLI requests retain their original prompt.

The native report renders the model headline and claims above the existing observed-feature and measurement sections, with evidence/checks in disclosure groups. Image and capture status remain pinned. The additional field is optional in the native decoder so older library records still reopen. Old cached reviews are never silently regenerated: a dedicated “Generate detailed analysis · uses API credits” action creates a new server case and explicitly requests a new analysis. Existing server results remain on disk; the phone library record holds the latest report rather than a complete version history.

## Evaluation and next steps

The intended evaluation unit is a claim: can an independent reviewer locate the feature, agree with its description, and determine what evidence supports or contradicts the interpretation? Compare paired views for persistence versus artifacts, track unsupported disease assertions separately from visibility errors, and use clinician reference annotations for clinical accuracy. More specific output is useful for evaluation but is not itself evidence of improved accuracy.

Web-search/tool execution, symptom intake and burst capture are separate planned changes and are not implemented by this report update. This version uses one Responses request without new tools or automatic retries, with the existing token limit and `store=false` behavior. The source consulted for schema integration was the [official OpenAI Structured Outputs documentation](https://developers.openai.com/api/docs/guides/structured-outputs).

## Validation on 2026-09-10

43 offline Python tests passed, including strict SDK response roundtrip, missing/unknown evidence rejection, no-eye claim rejection and complete verification fields. Signed iPhone and simulator builds passed. One explicitly announced paid smoke test on a previously saved image completed in 41.96 seconds with three structured claims and 3,835 total tokens (2,163 input, 1,672 output). No retries or web-search calls were made. The real response is retained under ignored local runs and was loaded into the simulator to check native decoding and layout. This smoke test verifies end-to-end operation, not diagnostic correctness. The phone app was installed and launched with refreshed Mac pairing.
