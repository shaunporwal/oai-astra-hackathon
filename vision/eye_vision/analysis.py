"""Shared analysis orchestration for live frames, snapshots and cached reviews."""
import base64
import json
import math
from pathlib import Path
import cv2
from .geometry import analyze_frame as analyze_geometry
from .measurements import Measurement
from .measurements.redness import analyze as analyze_redness


def validate_options(options=None):
    options={} if options is None else options
    if not isinstance(options,dict) or set(options)-{'target','roi'}:
        raise ValueError('Unknown analysis options')
    target=options.get('target','geometry')
    if target not in ('geometry','redness'):raise ValueError('Unknown capture target')
    roi=options.get('roi')
    if roi is not None:
        if not isinstance(roi,list) or len(roi)!=4 or any(type(v) not in (int,float) or not math.isfinite(v) for v in roi):
            raise ValueError('ROI must contain four finite normalized coordinates')
        x,y,w,h=roi
        if min(x,y)<0 or min(w,h)<=0 or x+w>1.000001 or y+h>1.000001:
            raise ValueError('ROI must be contained within the frame')
    return {'target':target,'roi':roi}


def analyze_frame(frame, options=None):
    options=validate_options(options)
    result=analyze_geometry(frame)
    redness=analyze_redness(frame,options['roi'] if options['target']=='redness' else None)
    assessment=result['ratio_assessment'];value=result['pupil_to_iris_ratio']
    ratio=Measurement('pupil_iris_ratio','pupil_to_iris_ratio','dimensionless',value,
        'estimated' if value is not None else 'ungradable',assessment['reason'],
        assessment.get('method','radial_limbus_ellipse_v1')).to_dict()
    result.update(analysis_options=options,redness=redness,measurements=[ratio,redness['measurement']])
    result['schema_version']='0.4'
    if options['target']=='redness':
        m=redness['measurement'];q=redness['quality'] or result['quality']
        eligible=m['value'] is not None
        crop=frame
        if redness['roi_xywh']:
            x,y,w,h=redness['roi_xywh'];crop=frame[y:y+h,x:x+w]
        signature=cv2.resize(cv2.cvtColor(crop,cv2.COLOR_BGR2GRAY),(16,16)).flatten().astype(float)/255 if crop.size else []
        result['selection']={'eligible':eligible,'reason':m['reason'],
            'score':q['laplacian_variance']*(1-q['bright_fraction']),
            'motion_signature':list(signature),'target':'redness'}
    return result


def save_analysis(folder, result):
    folder=Path(folder)
    (folder/'geometry.json').write_text(json.dumps(result,indent=2)+'\n')
    for name in ('vessel_mask','valid_mask'):
        encoded=result.get('redness',{}).get(name+'_png_base64')
        path=folder/(name+'.png')
        if encoded:path.write_bytes(base64.b64decode(encoded))
        else:path.unlink(missing_ok=True)
