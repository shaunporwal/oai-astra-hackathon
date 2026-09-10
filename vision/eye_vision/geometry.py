"""Conservative dark-region pupil candidate for close-up prototype footage.

This is not a trained anatomical segmenter and does not verify that an eye is present.
"""
import cv2
import numpy as np

from .prepare import quality
from .iris import fit_iris


def analyze_frame(frame):
    if frame is None or frame.dtype != np.uint8 or frame.ndim != 3 or frame.shape[2] != 3 or not frame.size:
        raise ValueError("Expected a nonempty uint8 BGR frame")
    h, w = frame.shape[:2]
    result = {"schema_version": "0.3", "image_size_wh": [w, h], "quality": quality(frame),
              "method": "dark_region_ellipse_v1", "pupil": None,
              "iris": None, "pupil_to_iris_ratio": None,
              "ratio_assessment": {"status": "rejected", "reason": "No pupil candidate"},
              "diagnosis": {"status": "not_configured"},
              "status": "no_reliable_candidate"}
    if min(h, w) < 64:
        return result
    gray = cv2.GaussianBlur(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), (5, 5), 0)
    # Exclude the outer margin where black borders, brows and vignetting dominate.
    x0, x1 = int(.1*w), int(.9*w)
    y0, y1 = int(.15*h), int(.85*h)
    region = gray[y0:y1, x0:x1]
    gradient = cv2.magnitude(cv2.Sobel(region, cv2.CV_32F, 1, 0), cv2.Sobel(region, cv2.CV_32F, 0, 1))
    best = None
    otsu, _ = cv2.threshold(region, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    thresholds = sorted({float(np.percentile(region, p)) for p in (2, 5, 10, 15, 20)} | {otsu})
    # Include intermediate levels so JPEG rounding does not force a fit inside the dark core.
    thresholds = sorted(set(thresholds) | {(a+b)/2 for a,b in zip(thresholds,thresholds[1:])})
    for threshold in thresholds:
        mask = (region <= threshold).astype(np.uint8)*255
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            if len(contour) < 12:
                continue
            bx, by, bw, bh = cv2.boundingRect(contour)
            if bx <= 1 or by <= 1 or bx+bw >= region.shape[1]-1 or by+bh >= region.shape[0]-1:
                continue
            ellipse = cv2.fitEllipse(contour)
            (cx, cy), (a, b), angle = ellipse
            if min(a, b) < .06*min(w, h) or max(a, b) > .45*min(w, h):
                continue
            if min(a, b)/max(a, b) < .6:
                continue
            area = cv2.contourArea(contour)
            fill = area / (np.pi*a*b/4)
            if not .75 <= fill <= 1.2:
                continue
            inside = np.zeros_like(region)
            cv2.ellipse(inside, ellipse, 255, -1)
            expanded = np.zeros_like(region)
            cv2.ellipse(expanded, ((cx,cy),(a*1.45,b*1.45),angle),255,-1)
            annulus = (expanded > 0) & (inside == 0)
            if not annulus.any() or not (inside > 0).any():
                continue
            contrast = float(np.median(region[annulus])-np.median(region[inside>0]))
            if contrast < 12:
                continue
            distance = np.hypot((cx+x0-w/2)/w, (cy+y0-h/2)/h)
            boundary = contour[:, 0, :]
            edge_strength = float(np.median(gradient[boundary[:, 1], boundary[:, 0]]))
            score = contrast * min(fill, 1) * (1 + edge_strength/255) / (1+3*distance)
            if best is None or score > best[0]:
                points=contour[:,0,:].copy()
                points[:,0]+=x0
                points[:,1]+=y0
                best=(score, {"center_xy": [float(cx+x0), float(cy+y0)],
                              "axes_wh": [float(a),float(b)], "angle_degrees":float(angle),
                              "diameter_px":float(np.sqrt(a*b)),
                              "contour_xy":points[::max(1,len(points)//100)].tolist(),
                              "local_contrast":contrast})
    if best is not None:
        result.update(pupil=best[1],status="candidate_found")
        iris, diagnostics = fit_iris(frame, best[1])
        result.update(iris=iris, ratio_assessment=diagnostics)
        if iris is not None:
            result['pupil_to_iris_ratio'] = best[1]['diameter_px']/iris['diameter_px']
    return result
