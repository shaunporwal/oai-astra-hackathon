import unittest
import numpy as np
from eye_vision.pipeline import Pipeline


class PipelineTests(unittest.TestCase):
    def test_blank_frame_has_no_predictions(self):
        result = Pipeline().analyze(np.zeros((120, 160, 3), dtype=np.uint8))
        self.assertEqual(result["image_size_wh"], [160, 120])
        self.assertEqual(result["eyes"], [])

    def test_rejects_wrong_image_format(self):
        with self.assertRaises(ValueError):
            Pipeline().analyze(np.zeros((120, 160), dtype=np.uint8))

    def test_model_receives_crop_in_frame_coordinates(self):
        class Detector:
            def __init__(self, boxes):
                self.boxes = boxes
            def detectMultiScale(self, *args, **kwargs):
                return self.boxes
        class Model:
            def analyze(self, crop):
                np.testing.assert_array_equal(crop, frame[23:33, 12:32])
                return {"segmentation": {"status": "test"}}
        frame = np.arange(100 * 100 * 3, dtype=np.uint8).reshape(100, 100, 3)
        pipeline = Pipeline(Model())
        pipeline.face = Detector([(10, 20, 80, 80)])
        pipeline.eye = Detector([(2, 3, 20, 10)])
        eye = pipeline.analyze(frame)["eyes"][0]
        self.assertEqual(eye["bbox_xywh"], [12, 23, 20, 10])
        self.assertEqual(eye["segmentation"]["status"], "test")
