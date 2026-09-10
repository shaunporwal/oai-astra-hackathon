"""Candidate vessel segmentation within a user-designated conjunctival rectangle.

ROI anatomy is not verified. This is a color/morphology baseline, not a clinical grader.
"""
import base64
import cv2
import numpy as np
from . import Measurement
from ..prepare import quality

METHOD = 'user_roi_red_linear_features_v1'


def analyze(frame, roi=None):
    result={'method':METHOD,'roi_source':'user_designated_not_anatomically_verified',
            'roi_xywh':None,'vessel_contours_xy':[],'quality':None}
    def finish(value, status, reason):
        result['measurement']=Measurement('conjunctival_hyperemia','vessel_area_fraction',
            'fraction',value,status,reason,METHOD).to_dict()
        return result
    if roi is None:
        return finish(None,'not_captured','Drag a rectangle entirely inside exposed white-eye tissue, avoiding iris and lids.')
    height,width=frame.shape[:2]
    x,y,w,h=roi
    x0,y0=int(x*width),int(y*height)
    x1,y1=min(width,int((x+w)*width)),min(height,int((y+h)*height))
    result['roi_xywh']=[x0,y0,x1-x0,y1-y0]
    if min(x1-x0,y1-y0)<24:
        return finish(None,'ungradable','Selected region is too small to resolve vessel candidates.')
    crop=frame[y0:y1,x0:x1]
    q=quality(crop);result['quality']=q
    b,g,r=cv2.split(crop)
    gray=cv2.cvtColor(crop,cv2.COLOR_BGR2GRAY)
    # Clipping/darkness exclusions are optical proxies, not a tissue segmentation mask.
    valid=(gray>45)&(np.max(crop,axis=2)<248)
    valid=cv2.erode(valid.astype(np.uint8),np.ones((3,3),np.uint8))>0
    result['valid_pixel_count']=int(valid.sum())
    result['excluded_fraction']=float(1-valid.mean())
    if valid.mean()<.75 or np.median(gray)<90:
        return finish(None,'ungradable','Region is too dark or contains excessive clipping; reposition the tissue view.')
    if q['laplacian_variance']<15:
        return finish(None,'ungradable','Insufficient local detail; improve focus before measuring.')
    # Green-channel dark ridges AND relative red excess; plain red areas do not count as vessels.
    kernel=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(9,9))
    ridges=cv2.morphologyEx(g,cv2.MORPH_BLACKHAT,kernel)
    excess=(r.astype(np.float32)-g)/(r.astype(np.float32)+g+1)
    candidates=((ridges>=8)&(excess>.06)&valid).astype(np.uint8)
    count,labels,stats,_=cv2.connectedComponentsWithStats(candidates,8)
    if count>1000:
        return finish(None,'ungradable','Excessive fragmented texture; select a clearer, smaller tissue region.')
    mask=np.zeros_like(candidates)
    for label in range(1,count):
        xx,yy,ww,hh,area=stats[label]
        if area<6:continue
        ys,xs=np.nonzero(labels==label)
        covariance=np.cov(np.stack([xs,ys]))
        eig=np.linalg.eigvalsh(covariance)
        elongation=np.sqrt((eig[-1]+1)/(eig[0]+1))
        if elongation>=2 and max(ww,hh)>=8:
            mask[labels==label]=255
    contours,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    if len(contours)>200:
        return finish(None,'ungradable','Too many fragmented candidates; improve focus and region selection.')
    result['vessel_contours_xy']=[(c[:,0,:]+[x0,y0]).tolist() for c in contours]
    result['candidate_pixel_count']=int((mask>0).sum())
    for name,im in [('vessel_mask',mask),('valid_mask',valid.astype(np.uint8)*255)]:
        ok,png=cv2.imencode('.png',im)
        if not ok:raise ValueError('Mask encoding failed')
        result[name+'_png_base64']=base64.b64encode(png).decode()
    reason='Candidate vessel pixels / valid pixels in your selected region; anatomy and clinical grading are unvalidated.'
    if not mask.any():reason+=' No candidates detected does not establish vessel absence or a normal eye.'
    return finish(float((mask>0).sum()/valid.sum()),'estimated',reason)
