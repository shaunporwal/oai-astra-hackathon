import base64
import json
import unittest
import cv2
import numpy as np
from eye_vision.analysis import analyze_frame, validate_options
from eye_vision.endpoints import attach_geometry


class RednessTests(unittest.TestCase):
    def scene(self):
        frame=np.full((200,240,3),210,dtype=np.uint8)
        truth=np.zeros((200,240),dtype=np.uint8)
        for y in (65,95,125):
            cv2.line(frame,(55,y),(180,y+8),(100,100,190),2)
            cv2.line(truth,(55,y),(180,y+8),255,2)
        return frame,truth

    def test_known_lines_mask_and_denominator(self):
        frame,truth=self.scene()
        r=analyze_frame(frame,{'target':'redness','roi':[.1,.1,.8,.8]})['redness']
        self.assertEqual(r['measurement']['status'],'estimated')
        mask=cv2.imdecode(np.frombuffer(base64.b64decode(r['vessel_mask_png_base64']),np.uint8),0)>0
        x,y,w,h=r['roi_xywh'];reference=truth[y:y+h,x:x+w]>0
        dice=2*(mask&reference).sum()/(mask.sum()+reference.sum())
        self.assertGreater(dice,.9)
        self.assertAlmostEqual(r['measurement']['value'],mask.sum()/r['valid_pixel_count'])
        self.assertEqual(r['measurement']['validated'],False)

    def test_region_required_and_invalid_options(self):
        frame,_=self.scene()
        self.assertIsNone(analyze_frame(frame,{'target':'redness'})['redness']['measurement']['value'])
        for roi in ([0,0,2,1],[0,0,float('nan'),.5],[-.1,0,.5,.5],[0,0,True,.5]):
            with self.assertRaises(ValueError):validate_options({'target':'redness','roi':roi})

    def test_dark_blurred_and_tiny_regions_reject(self):
        frame,_=self.scene()
        for image,roi in [(np.zeros_like(frame),[0,0,1,1]),
                          (cv2.GaussianBlur(frame,(41,41),10),[0,0,1,1]),
                          (frame,[0,0,.02,.02])]:
            self.assertIsNone(analyze_frame(image,{'target':'redness','roi':roi})['redness']['measurement']['value'])

    def test_black_lines_do_not_become_red_vessels(self):
        frame,_=self.scene()
        gray=cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY)
        frame=cv2.cvtColor(gray,cv2.COLOR_GRAY2BGR)
        r=analyze_frame(frame,{'target':'redness','roi':[.1,.1,.8,.8]})['redness']
        self.assertEqual(r['measurement']['value'],0)

    def test_endpoint_uses_same_local_result(self):
        frame,_=self.scene();r=analyze_frame(frame,{'target':'redness','roi':[.1,.1,.8,.8]})
        result={'endpoint_assessment':{'targets':[{'target_id':'conjunctival_hyperemia',
            'measurements':[{'name':'vessel_area_fraction','value':None},{'name':'vessel_tortuosity','value':None}]}]}}
        attached=attach_geometry(result,r)['endpoint_assessment']['targets'][0]['measurements']
        self.assertEqual(attached[0]['value'],r['redness']['measurement']['value'])
        self.assertIsNone(attached[1]['value'])
