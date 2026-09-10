from typing import Protocol

import cv2
import numpy as np


class EyeModel(Protocol):
    def analyze(self, crop: np.ndarray) -> dict:
        """Return JSON-safe segmentation and diagnosis results for a BGR eye crop."""
        ...


class UnconfiguredModel:
    def analyze(self, crop: np.ndarray) -> dict:
        return {
            "segmentation": {"status": "not_configured", "mask": None},
            "diagnosis": {"status": "not_configured", "predictions": []},
        }


class Pipeline:
    def __init__(self, model: EyeModel | None = None):
        self.model = model if model is not None else UnconfiguredModel()
        self.face = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
        self.eye = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_eye_tree_eyeglasses.xml"
        )
        if self.face.empty() or self.eye.empty():
            raise RuntimeError("OpenCV bundled detection models could not be loaded")

    def analyze(self, frame: np.ndarray) -> dict:
        if frame.dtype != np.uint8 or frame.ndim != 3 or frame.shape[2] != 3 or not frame.size:
            raise ValueError("Expected a nonempty uint8 BGR image")
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        detections = []
        for x, y, w, h in self.face.detectMultiScale(gray, 1.1, 5, minSize=(80, 80)):
            # Limit detection to the upper face; this is an ROI detector, not segmentation.
            upper = gray[y:y + int(h * 0.65), x:x + w]
            for ex, ey, ew, eh in self.eye.detectMultiScale(upper, 1.1, 5, minSize=(20, 20)):
                bx, by, bw, bh = map(int, (x + ex, y + ey, ew, eh))
                crop = frame[by:by + bh, bx:bx + bw]
                crop_gray = gray[by:by + bh, bx:bx + bw]
                detections.append({
                    "bbox_xywh": [bx, by, bw, bh],
                    "quality": {
                        "mean_brightness": float(crop_gray.mean()),
                        "laplacian_variance": float(cv2.Laplacian(crop_gray, cv2.CV_64F).var()),
                    },
                    **self.model.analyze(crop),
                })
        return {
            "schema_version": "0.1",
            "image_size_wh": [int(frame.shape[1]), int(frame.shape[0])],
            "detector": "opencv_haar_baseline",
            "eyes": detections,
        }
