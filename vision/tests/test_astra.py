"""Exercise the real SDK against an in-memory HTTP transport; no network or API key."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import cv2
import numpy as np

try:
    import httpx
    from openai import OpenAI
    from eye_vision.astra import analyze, build_request
    EXTRAS = True
except ImportError:
    EXTRAS = False


@unittest.skipUnless(EXTRAS, "Install .[astra] to run SDK adapter tests")
class AstraTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        path = self.root / "frame.jpg"
        cv2.imwrite(str(path), np.zeros((64, 64, 3), dtype=np.uint8))
        self.manifest = {"schema_version": "0.2", "source_sha256": "a"*64,
                         "frames": [{"frame_index": 0, "timestamp_ms": 0, "image_file": path.name,
                                     "image_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}]}
        self.path = self.root / "manifest.json"
        self.path.write_text(json.dumps(self.manifest))

    def client(self, content):
        def handler(request):
            payload = json.loads(request.content)
            self.assertEqual(payload["model"], "gpt-6-astra")
            self.assertFalse(payload["store"])
            self.assertTrue(payload["text"]["format"]["strict"])
            self.assertEqual(payload["input"][1]["content"][1]["type"], "input_image")
            return httpx.Response(200, json={
                "id": "resp_test", "object": "response", "created_at": 0,
                "status": "completed", "model": "gpt-6-astra",
                "output": [{"id": "msg_test", "type": "message", "role": "assistant", "status": "completed", "content": [content]}],
            })
        client = OpenAI(api_key="offline-test-only", http_client=httpx.Client(transport=httpx.MockTransport(handler)))
        self.addCleanup(client.close)
        return client

    def test_structured_output_roundtrip(self):
        data = {"prediction": "unusable", "eye_visible": "no", "evidence_frame_indices": [0],
                "observations": ["No eye visible"], "limitations": ["Synthetic black frame"]}
        result = analyze(self.path, "fixture", client=self.client({"type": "output_text", "text": json.dumps(data), "annotations": []}))
        self.assertEqual(result["prediction"], "unusable")
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["diagnosis"]["status"], "not_configured")
        self.assertEqual(result["review"], data)

    def test_refusal_abstains(self):
        result = analyze(self.path, "fixture", client=self.client({"type": "refusal", "refusal": "Cannot assess"}))
        self.assertEqual(result["prediction"], "abstain")
        self.assertEqual(result["status"], "incomplete_or_refused")

    def test_unknown_evidence_rejected(self):
        data = {"prediction": "usable", "eye_visible": "yes", "evidence_frame_indices": [999],
                "observations": [], "limitations": []}
        with self.assertRaisesRegex(ValueError, "not supplied"):
            analyze(self.path, "fixture", client=self.client({"type": "output_text", "text": json.dumps(data), "annotations": []}))

    def test_hash_tampering_and_path_escape_rejected(self):
        (self.root / "frame.jpg").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            build_request(self.path)
        self.manifest["frames"][0]["image_file"] = "../outside.jpg"
        self.path.write_text(json.dumps(self.manifest))
        with self.assertRaisesRegex(ValueError, "manifest directory"):
            build_request(self.path)
