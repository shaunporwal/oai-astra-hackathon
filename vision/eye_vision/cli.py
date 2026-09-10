import argparse
import json
from pathlib import Path
import time

import cv2

from .pipeline import Pipeline


def main():
    parser = argparse.ArgumentParser(description="Local eye capture; q quits, s saves a sample")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--camera", type=int, default=0)
    source.add_argument("--video", type=Path)
    parser.add_argument("--output", type=Path, default=Path("runs"))
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--max-frames", type=int, default=0, help="0 means unlimited")
    parser.add_argument("--save-every", type=int, default=0, help="Save every Nth frame; 0 disables automatic saving")
    args = parser.parse_args()
    if args.max_frames < 0 or args.save_every < 0:
        parser.error("Frame counts must be nonnegative")
    if args.video and not args.video.is_file():
        parser.error(f"Video does not exist: {args.video}")
    pipeline = Pipeline()
    cap = cv2.VideoCapture(str(args.video) if args.video else args.camera)
    count = 0
    session = None
    started = time.monotonic()
    try:
        if not cap.isOpened():
            raise RuntimeError("Cannot open input. Check camera index, macOS camera permission, or video format.")
        while not args.max_frames or count < args.max_frames:
            ok, frame = cap.read()
            if not ok:
                if args.video and count:
                    break
                raise RuntimeError("Input stopped delivering frames")
            result = pipeline.analyze(frame)
            result["frame_index"] = count
            result["timestamp_ms"] = float(cap.get(cv2.CAP_PROP_POS_MSEC)) if args.video else (time.monotonic() - started) * 1000
            key = -1
            if not args.headless:
                preview = frame.copy()
                for eye in result["eyes"]:
                    x, y, w, h = eye["bbox_xywh"]
                    cv2.rectangle(preview, (x, y), (x + w, y + h), (0, 255, 0), 2)
                cv2.putText(preview, "s: save | q: quit | ROI baseline", (12, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
                cv2.imshow("Eye vision", preview)
                key = cv2.waitKey(1) & 0xFF
            if key == ord("q"):
                break
            if key == ord("s") or (args.save_every and count % args.save_every == 0):
                if session is None:
                    from datetime import datetime, timezone
                    session = args.output / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
                    session.mkdir(parents=True, exist_ok=False)
                sample = session / f"{count:08d}"
                sample.mkdir()
                if not cv2.imwrite(str(sample / "frame.jpg"), frame):
                    raise RuntimeError("Failed to save frame")
                for index, eye in enumerate(result["eyes"]):
                    x, y, w, h = eye["bbox_xywh"]
                    name = f"eye_{index}.png"
                    if not cv2.imwrite(str(sample / name), frame[y:y+h, x:x+w]):
                        raise RuntimeError("Failed to save eye crop")
                    eye["crop_file"] = name
                (sample / "result.json").write_text(json.dumps(result, indent=2) + "\n")
                print(f"Saved {sample}")
            count += 1
    finally:
        cap.release()
        if not args.headless:
            cv2.destroyAllWindows()
    print(f"Processed {count} frames")


if __name__ == "__main__":
    main()
