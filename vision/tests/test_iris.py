import unittest
import cv2
import numpy as np
from eye_vision.geometry import analyze_frame
from eye_vision.endpoints import attach_geometry


class IrisTests(unittest.TestCase):
    def scene(self, scale=1, angle=0):
        image=np.full((400*scale,500*scale,3),210,dtype=np.uint8)
        center=(250*scale,200*scale)
        cv2.ellipse(image,center,(100*scale,85*scale),angle,0,360,(80,80,80),-1)
        cv2.ellipse(image,center,(30*scale,26*scale),angle,0,360,(10,10,10),-1)
        return image

    def test_known_ratio_rotation_and_scale(self):
        expected=np.sqrt(30*26/(100*85))
        for scale,angle in [(1,0),(1,35),(2,35)]:
            with self.subTest(scale=scale,angle=angle):
                r=analyze_frame(self.scene(scale,angle))
                self.assertIsNotNone(r['iris'],r['ratio_assessment'])
                self.assertAlmostEqual(r['pupil_to_iris_ratio'],expected,delta=.025)

    def test_missing_outer_boundary_rejected(self):
        image=np.full((400,500,3),180,dtype=np.uint8)
        cv2.circle(image,(250,200),30,(10,10,10),-1)
        r=analyze_frame(image)
        self.assertIsNone(r['iris'])
        self.assertIsNone(r['pupil_to_iris_ratio'])

    def test_heavy_occlusion_rejected(self):
        image=self.scene()
        image[:185]=210
        self.assertIsNone(analyze_frame(image)['pupil_to_iris_ratio'])

    def test_local_measurement_attached_without_model_numbers(self):
        geometry=analyze_frame(self.scene())
        result={'endpoint_assessment':{'targets':[{'target_id':'pupil_iris_ratio',
            'measurements':[{'name':'pupil_to_iris_ratio','value':None}]}]}}
        m=attach_geometry(result,geometry)['endpoint_assessment']['targets'][0]['measurements'][0]
        self.assertEqual(m['value'],geometry['pupil_to_iris_ratio'])
        self.assertEqual(m['source'],'local_geometry_on_saved_jpeg')
        self.assertFalse(m['validated'])
