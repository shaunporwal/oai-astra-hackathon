"""Testable image claims and explicitly provisional interpretations."""
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class ImageClaim(BaseModel):
    model_config = ConfigDict(extra='forbid')
    claim: str
    location: str
    evidence_frame_indices: list[int]
    visual_confidence: Literal['high', 'medium', 'low']
    interpretation: str
    alternative: str
    supporting_evidence: str
    contradicting_or_missing_evidence: str
    verification: str


class ImageAssessment(BaseModel):
    model_config = ConfigDict(extra='forbid')
    headline: str
    summary: str
    claims: list[ImageClaim] = Field(max_length=5)


def validate_assessment(assessment, indices, eye_visible):
    if eye_visible == 'no' and assessment.claims:
        raise ValueError('No-eye review cannot contain eye findings')
    for claim in assessment.claims:
        if not claim.evidence_frame_indices or not set(claim.evidence_frame_indices) <= indices:
            raise ValueError('Image claim must cite supplied frame evidence')
        for key in ('claim', 'location', 'interpretation', 'alternative', 'supporting_evidence',
                    'contradicting_or_missing_evidence', 'verification'):
            if not getattr(claim, key).strip():
                raise ValueError('Image claim requires a complete testable interpretation')
    if not assessment.headline.strip() or not assessment.summary.strip():
        raise ValueError('Image assessment requires a headline and summary')
    return assessment.model_dump()


INSTRUCTIONS = '''
Produce image_assessment as the main experimental image analysis, alongside the six research endpoints.
Its headline must state the most informative image-specific finding in plain language, not merely list
anatomical structures or repeat "disease status not established". Its summary should synthesize what
this image suggests and the most important unresolved distinction in at most two sentences.
Make up to five concrete, falsifiable claims about visible features. Do not fill a quota. Each claim
must specify image-relative location (left/right refer to the supplied image, not inferred patient laterality),
appearance, and supplied evidence frames. Describe distribution, shape, color, boundary or relative prominence
where visible. State well-supported observations directly; avoid repetitive generic disclaimers.
For each claim give a concise leading interpretation, including a named condition when the visible evidence
actually supports considering it, an alternative (including normal anatomy or acquisition artifact where relevant),
supporting evidence, contradicting or missing evidence, and a practical way to confirm or contradict the hypothesis.
Interpretations are provisional hypotheses, never confirmed diagnoses. Do not force pathology from visible vessels,
normal anatomical variants, glare or color casts. If no disease-specific interpretation is supported, say why.
Visual confidence concerns visibility of the claim, not the probability of disease. No invented probabilities,
calibrated measurements, severity scores, systemic laboratory values, segmentation masks, symptoms or history.
Negative findings apply only to adequately visible regions. Verification may request another view, symptom/history
clarification or a clinician's examination; do not suggest self-administered medication, eyelid manipulation or light tests.
If no eye is visible, return no claims and explain the capture failure. With poor views, restrict claims to visible evidence.
Do not invent citations or imply that literature search or tools ran. No treatment recommendations.
Keep each field short and specific. The six endpoint restrictions still apply to quantitative/validated claims;
they do not prohibit clearly labeled qualitative differential hypotheses in image_assessment.
'''
