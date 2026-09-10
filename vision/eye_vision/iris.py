"""Experimental radial-edge ellipse fitting, with explicit rejection diagnostics."""
import cv2
import numpy as np

METHOD = 'radial_limbus_ellipse_v1'


def fit_iris(frame, pupil):
    diagnostics = {'method': METHOD, 'status': 'rejected', 'reason': 'No pupil candidate'}
    if pupil is None:
        return None, diagnostics
    gray = cv2.GaussianBlur(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), (7, 7), 0).astype(np.float32)
    h, w = gray.shape
    cx, cy = pupil['center_xy']
    radius = pupil['diameter_px']/2
    radii = np.arange(max(radius*1.65, radius+8), min(radius*5, min(h,w)*.6), 1, dtype=np.float32)
    if len(radii) < 15:
        diagnostics['reason'] = 'Insufficient room around pupil'
        return None, diagnostics
    angles = np.linspace(0, 2*np.pi, 120, endpoint=False).astype(np.float32)
    xx = cx + np.cos(angles[:, None])*radii
    yy = cy + np.sin(angles[:, None])*radii
    samples = cv2.remap(gray, xx, yy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    # A dark iris meeting lighter sclera should produce a positive radial transition.
    differences = samples[:, 8:] - samples[:, :-8]
    valid = (xx[:,4:-4]>5)&(xx[:,4:-4]<w-6)&(yy[:,4:-4]>5)&(yy[:,4:-4]<h-6)
    differences[~valid] = -1000
    peaks = differences.argmax(axis=1)
    strength = differences[np.arange(len(angles)), peaks]
    selected = strength > 18
    points = np.stack([xx[np.arange(120),peaks+4], yy[np.arange(120),peaks+4]],axis=1)
    if selected.sum() < 75:
        diagnostics['reason'] = 'Insufficient outer-boundary contrast or coverage'
        return None, diagnostics
    # Deterministic robust initialization prevents reflection edges dominating a least-squares fit.
    rng = np.random.default_rng(0)
    available = np.flatnonzero(selected)
    keep = selected.copy()
    best_count = 0
    for _ in range(100):
        candidate = cv2.fitEllipse(points[rng.choice(available, 8, replace=False)].astype(np.float32))
        (ex,ey),(a,b),angle = candidate
        if min(a,b)<radius*3 or max(a,b)>min(h,w)*1.2 or min(a,b)/max(a,b)<.65:
            continue
        if np.hypot(ex-cx,ey-cy)>.18*np.sqrt(a*b):
            continue
        theta = np.deg2rad(angle)
        delta = points-[ex,ey]
        u = delta[:,0]*np.cos(theta)+delta[:,1]*np.sin(theta)
        v = -delta[:,0]*np.sin(theta)+delta[:,1]*np.cos(theta)
        residual = np.abs(np.sqrt((2*u/a)**2+(2*v/b)**2)-1)
        support = selected & (residual<.08)
        if support.sum()>best_count:
            best_count=int(support.sum()); keep=support

    for _ in range(4):
        if keep.sum() < 60:
            break
        ellipse = cv2.fitEllipse(points[keep].astype(np.float32))
        (ex,ey),(a,b),angle = ellipse
        theta = np.deg2rad(angle)
        delta = points - [ex,ey]
        u = delta[:,0]*np.cos(theta)+delta[:,1]*np.sin(theta)
        v = -delta[:,0]*np.sin(theta)+delta[:,1]*np.cos(theta)
        residual = np.abs(np.sqrt((2*u/max(a,1))**2+(2*v/max(b,1))**2)-1)
        keep = selected & (residual < .08)
    sectors = len(set((np.flatnonzero(keep)//10).tolist()))
    diagnostics.update(edge_support_fraction=float(keep.mean()), supported_sectors=sectors)
    if keep.sum() < 78 or sectors < 11:
        diagnostics['reason'] = 'Outer-boundary fit lacks circumferential support'
        return None, diagnostics
    (ex,ey),(a,b),angle = cv2.fitEllipse(points[keep].astype(np.float32))
    diameter = float(np.sqrt(a*b))
    ratio = pupil['diameter_px']/diameter
    if min(a,b)/max(a,b)<.65 or np.hypot(ex-cx,ey-cy)>.18*diameter:
        diagnostics['reason'] = 'Off-axis or inconsistent pupil/iris geometry'
        return None, diagnostics
    theta = np.deg2rad(angle)
    extent_x = np.sqrt((a*np.cos(theta))**2+(b*np.sin(theta))**2)/2
    extent_y = np.sqrt((a*np.sin(theta))**2+(b*np.cos(theta))**2)/2
    if not .15 <= ratio <= .65 or ex-extent_x<0 or ex+extent_x>w or ey-extent_y<0 or ey+extent_y>h:
        diagnostics['reason'] = 'Implausible scale or clipped outer boundary'
        return None, diagnostics
    iris = {'center_xy':[float(ex),float(ey)], 'axes_wh':[float(a),float(b)],
            'angle_degrees':float(angle),'diameter_px':diameter,
            'contour_xy':points[keep].tolist()}
    diagnostics.update(status='estimated',reason='Experimental ellipse ratio; inspect both boundaries',
                       diameter_convention='sqrt(major_axis_px * minor_axis_px)',validated=False)
    return iris, diagnostics
