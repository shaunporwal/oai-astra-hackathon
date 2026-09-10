"""Research observations tied to the checked-in target specification."""
import hashlib
import json
from pathlib import Path
from typing import Literal
from pydantic import BaseModel, ConfigDict


class EndpointObservation(BaseModel):
    model_config = ConfigDict(extra='forbid')
    target_id: str
    status: Literal['observed', 'ungradable', 'not_captured']
    observation: str
    evidence_frame_indices: list[int]
    limitations: list[str]


def specification():
    path = Path(__file__).resolve().parents[2] / 'specs' / 'details.json'
    data = path.read_bytes()
    spec = json.loads(data)
    return spec, hashlib.sha256(data).hexdigest()


def instructions(spec):
    targets = [{k: t[k] for k in ('id', 'name', 'capture_requirements',
               'claims_not_supported_for_this_project')} for t in spec['targets']]
    return '''\nAlso assess EACH research target below exactly once, using its exact target_id.
Report descriptive visual observations only, with supplied frame indices as evidence.
'observed' means visible appearance can be described, NOT a disease or a measured endpoint.
Use ungradable for insufficient visual evidence, and not_captured for required anatomy/protocol absent.
Do not infer normality or absence of disease from incomplete coverage. Do not infer calibrated color,
numeric ratios, vessel metrics, bilirubin, hemoglobin, cholesterol or timed light reflex from these stills.
Do not claim expert-referenced arcus presence: describe visible peripheral opacity or uncertainty only.
No treatment advice. A still-frame request cannot measure pupillary light reflex.
The server separately reports numeric measurements as null because calibrated measurement methods are not implemented.
Target specification:\n''' + json.dumps(targets)


def assemble(observations, spec, indices):
    expected = {t['id'] for t in spec['targets']}
    if len(observations) != len(expected) or {o.target_id for o in observations} != expected:
        raise ValueError('Expected exactly one observation per specified target')
    by_id = {o.target_id: o for o in observations}
    results = []
    for target in spec['targets']:
        o = by_id[target['id']]
        if not set(o.evidence_frame_indices) <= indices:
            raise ValueError('Endpoint cited an unsupplied frame')
        if o.status == 'observed' and not o.evidence_frame_indices:
            raise ValueError('Observed endpoint must cite evidence')
        if target['id'] == 'pupillary_light_reflex' and o.status == 'observed':
            raise ValueError('Selected stills cannot establish a light reflex')
        results.append({**o.model_dump(), 'name': target['name'],
            'measurements': [{'name': m['name'], 'unit': m['unit'], 'value': None,
                'status': 'not_calibrated' if target['id'] == 'scleral_chromaticity' else 'not_measured',
                'reason': 'No calibrated quantitative measurement method is connected for this target.'}
                for m in target['measurements']],
            'literature_ids': target['literature_ids'], 'validated_on_this_setup': False})
    return results
