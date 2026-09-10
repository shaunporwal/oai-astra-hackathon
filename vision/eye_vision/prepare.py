"""Bounded local preparation of close-up phone video, independent of face detection."""
import argparse
import hashlib
import heapq
import json
import math
from pathlib import Path

import cv2
import numpy as np


def quality(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return {
        "mean_brightness": float(gray.mean()),
        "laplacian_variance": float(cv2.Laplacian(gray, cv2.CV_64F).var()),
        "dark_fraction": float((gray <= 10).mean()),
        "bright_fraction": float((gray >= 245).mean()),
    }


def transform(frame, rotate=0, roi=None, max_side=1536):
    if rotate:
        frame = cv2.rotate(frame, {90: cv2.ROTATE_90_CLOCKWISE,
                                 180: cv2.ROTATE_180,
                                 270: cv2.ROTATE_90_COUNTERCLOCKWISE}[rotate])
    height, width = frame.shape[:2]
    x, y, w, h = roi if roi is not None else (0, 0, width, height)
    if min(x, y) < 0 or min(w, h) <= 0 or x + w > width or y + h > height:
        raise ValueError("ROI must fit entirely inside the oriented frame")
    image = frame[y:y+h, x:x+w]
    scale = min(1.0, max_side / max(w, h))
    image = cv2.resize(image, (max(1, round(w*scale)), max(1, round(h*scale))), interpolation=cv2.INTER_AREA)
    return image, {"oriented_size_wh": [width, height], "roi_xywh": [x, y, w, h],
                   "image_size_wh": [image.shape[1], image.shape[0]]}


def prepare(video, output, *, sample_seconds=1.0, max_frames=8, max_seconds=60.0,
            rotate=0, roi=None, max_side=1536):
    video, output = Path(video), Path(output)
    if not video.is_file():
        raise ValueError(f"Video does not exist: {video}")
    if output.exists():
        raise ValueError(f"Output already exists: {output}; choose a new directory")
    if not all(math.isfinite(v) and v > 0 for v in (sample_seconds, max_seconds)):
        raise ValueError("Sampling interval and duration must be finite and positive")
    if not 1 <= max_frames <= 32 or not 64 <= max_side <= 2048 or rotate not in (0, 90, 180, 270):
        raise ValueError("Use 1–32 frames, 64–2048 max-side pixels, and a right-angle rotation")
    cap = cv2.VideoCapture(str(video))
    selected = []
    sampled = decoded = 0
    timestamp_sources = set()
    try:
        if not cap.isOpened():
            raise ValueError("Could not decode video; export an SDR H.264 MOV/MP4 and retry")
        fps = float(cap.get(cv2.CAP_PROP_FPS))
        if not math.isfinite(fps) or fps <= 0:
            raise ValueError("Video has no usable frame rate for timestamp fallback")
        # OpenCV backends may apply container rotation. Manual --rotate is ADDITIONAL.
        auto_rotation = bool(cap.get(cv2.CAP_PROP_ORIENTATION_AUTO))
        backend = cap.getBackendName()
        next_sample = 0.0
        previous_ms = -1.0
        frame_limit = max(1, math.ceil(max_seconds * fps))
        while decoded < frame_limit:
            ok, frame = cap.read()
            if not ok:
                break
            index = decoded
            decoded += 1
            reported_ms = float(cap.get(cv2.CAP_PROP_POS_MSEC))
            valid = math.isfinite(reported_ms) and reported_ms >= 0 and reported_ms > previous_ms
            timestamp_ms = reported_ms if valid else max(index / fps * 1000, previous_ms + 1000 / fps)
            timestamp_sources.add("decoder" if valid else "fps_fallback")
            previous_ms = timestamp_ms
            seconds = timestamp_ms / 1000
            if seconds >= max_seconds:
                break
            if seconds + 1e-6 < next_sample:
                continue
            next_sample = seconds + sample_seconds
            image, geometry = transform(frame, rotate, roi, max_side)
            metrics = quality(image)
            # A ranking heuristic only; no frame is declared clinically usable here.
            score = metrics["laplacian_variance"] * max(0.0, 1 - metrics["dark_fraction"] - metrics["bright_fraction"])
            metadata = {"frame_index": index, "timestamp_ms": timestamp_ms,
                        "quality": metrics, "selection_score": score, **geometry}
            item = (score, index, metadata, image)
            sampled += 1
            if len(selected) < max_frames:
                heapq.heappush(selected, item)
            elif item[:2] > selected[0][:2]:
                heapq.heapreplace(selected, item)
    finally:
        cap.release()
    if not selected:
        raise ValueError("No frames decoded within the requested duration")
    with video.open("rb") as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    output.mkdir(parents=True, exist_ok=False)
    records, tiles = [], []
    for _, index, metadata, image in sorted(selected, key=lambda item: item[1]):
        name = f"frame_{index:08d}.jpg"
        path = output / name
        if not cv2.imwrite(str(path), image, [cv2.IMWRITE_JPEG_QUALITY, 95]):
            raise OSError(f"Failed to save {path}")
        metadata.update({"image_file": name, "image_sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        records.append(metadata)
        thumb, _ = transform(image, max_side=300)
        tile = np.zeros((340, 320, 3), dtype=np.uint8)
        h, w = thumb.shape[:2]
        tile[:h, :w] = thumb
        cv2.putText(tile, f"#{index} {metadata['timestamp_ms']/1000:.2f}s", (8, 325),
                    cv2.FONT_HERSHEY_SIMPLEX, .5, (255, 255, 255), 1)
        tiles.append(tile)
    while len(tiles) % 4:
        tiles.append(np.zeros_like(tiles[0]))
    sheet = np.vstack([np.hstack(tiles[i:i+4]) for i in range(0, len(tiles), 4)])
    if not cv2.imwrite(str(output / "contact_sheet.jpg"), sheet):
        raise OSError("Could not write contact sheet")
    manifest = {
        "schema_version": "0.2", "source_sha256": digest, "source_name": video.name,
        "backend": backend, "fps": fps, "decoder_auto_rotation": auto_rotation,
        "timestamp_sources": sorted(timestamp_sources), "decoded_frames": decoded,
        "sampled_frames": sampled,
        "preparation": {"sample_seconds": sample_seconds, "max_frames": max_frames,
                        "max_seconds": max_seconds, "rotate": rotate, "roi": roi,
                        "max_side": max_side, "selector": "sharpness_exposure_v1",
                        "opencv_version": cv2.__version__},
        "frames": records,
        "segmentation": {"status": "not_configured"},
        "diagnosis": {"status": "not_configured"},
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, allow_nan=False) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description="Prepare close-up iPhone video locally; no uploads")
    parser.add_argument("video", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sample-seconds", type=float, default=1.0)
    parser.add_argument("--max-frames", type=int, default=8)
    parser.add_argument("--max-seconds", type=float, default=60.0)
    parser.add_argument("--rotate", type=int, choices=(0, 90, 180, 270), default=0)
    parser.add_argument("--roi", type=int, nargs=4, metavar=("X", "Y", "W", "H"))
    parser.add_argument("--max-side", type=int, default=1536)
    args = vars(parser.parse_args())
    try:
        result = prepare(**args)
    except (ValueError, OSError, cv2.error) as exc:
        parser.exit(1, f"Preparation failed: {exc}\n")
    print(f"Prepared {len(result['frames'])} frames in {args['output']}")


if __name__ == "__main__":
    main()
