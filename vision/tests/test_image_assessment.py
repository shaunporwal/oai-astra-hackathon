import unittest
from pydantic import ValidationError
from eye_vision.image_assessment import ImageAssessment, validate_assessment


class ImageAssessmentTests(unittest.TestCase):
    def assessment(self):
        return ImageAssessment(headline='Localized visible redness', summary='A visible pattern with an unresolved cause.', claims=[dict(
            claim='A red vessel branches in the upper image.', location='Upper right of frame', evidence_frame_indices=[0],
            visual_confidence='high', interpretation='Visible superficial vessel; cause uncertain.',
            alternative='Normal vessel visibility under this lighting.', supporting_evidence='A continuous branching red line.',
            contradicting_or_missing_evidence='No symptom history or standardized comparison.',
            verification='Compare the same region in a second evenly lit view.')])

    def test_roundtrip_keeps_testable_claims(self):
        result=validate_assessment(self.assessment(),{0},'yes')
        self.assertEqual(result['claims'][0]['evidence_frame_indices'],[0])
        self.assertIn('second', result['claims'][0]['verification'])

    def test_rejects_missing_or_unknown_evidence(self):
        for indices in ([],[1]):
            assessment=self.assessment();assessment.claims[0].evidence_frame_indices=indices
            with self.assertRaisesRegex(ValueError,'supplied frame'):
                validate_assessment(assessment,{0},'yes')

    def test_rejects_eye_claims_when_no_eye_and_incomplete_interpretation(self):
        with self.assertRaisesRegex(ValueError,'No-eye'):
            validate_assessment(self.assessment(),{0},'no')
        assessment=self.assessment();assessment.claims[0].verification=' '
        with self.assertRaisesRegex(ValueError,'complete testable'):
            validate_assessment(assessment,{0},'yes')

    def test_rejects_invented_numeric_confidence_field(self):
        data=self.assessment().model_dump();data['claims'][0]['disease_probability']=.9
        with self.assertRaises(ValidationError):
            ImageAssessment.model_validate(data)
