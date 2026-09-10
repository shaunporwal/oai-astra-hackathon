import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import cv2
import numpy as np

from eye_vision.prepare import prepare, transform
from eye_vision.evaluate import evaluate, read_labels, TASK


def label(case="one", subject="p1", digest="a"*64, split="test", value="usable"):
    return {"case_id": case, "subject_id": subject, "source_sha256": digest, "manifest_sha256": "d"*64,
            "split": split, "task": TASK, "label": value,
            "label_source": "human_review", "reviewer_id": "r1",
            "device": "synthetic_fixture", "capture_type": "synthetic"}


class PreparationTests(unittest.TestCase):
    def test_video_exports_bounded_chronological_frames(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "fixture.avi"
            writer = cv2.VideoWriter(str(source), cv2.VideoWriter_fourcc(*"MJPG"), 10, (160, 120))
            self.assertTrue(writer.isOpened())
            rng = np.random.default_rng(7)
            for _ in range(20):
                writer.write(rng.integers(30, 220, (120, 160, 3), dtype=np.uint8))
            writer.release()
            result = prepare(source, root / "output", max_frames=3, sample_seconds=.2, rotate=90, roi=[0, 0, 100, 100])
            frames = result["frames"]
            self.assertEqual(len(frames), 3)
            self.assertEqual(result["sampled_frames"], 10)
            self.assertEqual([f["frame_index"] for f in frames], sorted(f["frame_index"] for f in frames))
            self.assertEqual(result["source_sha256"], hashlib.sha256(source.read_bytes()).hexdigest())
            self.assertTrue((root / "output/contact_sheet.jpg").is_file())
            self.assertEqual(frames[0]["oriented_size_wh"], [120, 160])
            self.assertEqual(frames[0]["roi_xywh"], [0, 0, 100, 100])
            for frame in frames:
                self.assertEqual(cv2.imread(str(root / "output" / frame["image_file"])).shape, (100, 100, 3))
            with self.assertRaisesRegex(ValueError, "already exists"):
                prepare(source, root / "output")

    def test_transform_preserves_known_pixel_coordinates(self):
        image = np.arange(12*10*3, dtype=np.uint8).reshape(12, 10, 3)
        result, meta = transform(image, rotate=90, roi=[2, 3, 5, 4])
        np.testing.assert_array_equal(result, np.rot90(image, k=-1)[3:7, 2:7])
        self.assertEqual(meta["oriented_size_wh"], [12, 10])
        with self.assertRaises(ValueError):
            transform(image, roi=[9, 9, 5, 5])

    def test_invalid_video_leaves_no_export(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "invalid.mov"
            source.write_bytes(b"not video")
            with self.assertRaises(ValueError):
                prepare(source, root / "out")
            self.assertFalse((root / "out").exists())


class EvaluationTests(unittest.TestCase):
    def test_abstentions_and_missing_are_not_removed_from_denominator(self):
        rows = [label(), label("two", "p2", "b"*64, value="unusable"), label("three", "p3", "c"*64)]
        predictions = [{"case_id": "one", "source_sha256": "a"*64, "manifest_sha256": "d"*64, "task": TASK, "prediction": "usable"},
                       {"case_id": "two", "source_sha256": "b"*64, "manifest_sha256": "d"*64, "task": TASK, "prediction": "abstain"}]
        result = evaluate(rows, predictions)
        self.assertEqual(result["answer_coverage"], 1/3)
        self.assertEqual(result["accuracy_answered"], 1)
        self.assertEqual(result["usable_recall_all"], .5)
        self.assertEqual(result["missing_predictions"], 1)
        self.assertEqual(result["abstentions"], 1)
        self.assertIsNone(result["unusable_recall_answered"])
        self.assertIsNone(evaluate(rows, [])["accuracy_answered"])

    def test_rejects_leakage_and_model_ground_truth(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "labels.jsonl"
            for rows in (
                [label(), label("two", split="dev")],
                [label(), label("two", subject="p2", split="dev")],
                [{**label(), "label_source": "astra"}],
                [label(), label()],
            ):
                with self.subTest(rows=rows):
                    path.write_text("\n".join(json.dumps(row) for row in rows))
                    with self.assertRaises(ValueError):
                        read_labels(path)
            path.write_text(json.dumps(label()))
            self.assertEqual(len(read_labels(path)), 1)

    def test_rejects_mismatched_video_and_duplicate_prediction(self):
        row = {"case_id": "one", "task": TASK, "source_sha256": "b"*64, "manifest_sha256": "d"*64, "prediction": "usable"}
        with self.assertRaises(ValueError):
            evaluate([label()], [row])
        row["source_sha256"] = "a"*64
        with self.assertRaises(ValueError):
            evaluate([label()], [row, row])
        row["manifest_sha256"] = "e"*64
        with self.assertRaisesRegex(ValueError, "different prepared frame set"):
            evaluate([label()], [row])
