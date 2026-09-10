"""Loopback-only browser camera demo; no mobile app changes required."""
import argparse
import asyncio
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import time

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from starlette.concurrency import run_in_threadpool
from starlette.middleware.trustedhost import TrustedHostMiddleware

from .geometry import analyze_frame
from .config import configure_api_key

STATIC = Path(__file__).parent / "static"


def create_app(output=None):
    output = Path(output) if output else Path(__file__).resolve().parents[1]/"runs"
    token = secrets.token_urlsafe(32)
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["localhost", "127.0.0.1", "testserver"])
    app.mount("/static", StaticFiles(directory=STATIC), name="static")
    review_lock = asyncio.Lock()
    frame_lock = asyncio.Lock()

    def has_astra():
        return bool(os.environ.get("OPENAI_API_KEY")) and importlib.util.find_spec("openai") is not None

    def authorize(request):
        if not secrets.compare_digest(request.headers.get("x-live-token", ""), token):
            raise HTTPException(403, "Open the local dashboard to start a session")

    async def read_frame(request):
        authorize(request)
        if request.headers.get("content-type", "").split(";")[0] != "image/jpeg":
            raise HTTPException(415, "Send a JPEG frame")
        data = bytearray()
        async for chunk in request.stream():
            data.extend(chunk)
            if len(data) > 2_000_000:
                raise HTTPException(413, "Frame exceeds 2 MB")
        frame = await run_in_threadpool(cv2.imdecode, np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
        if frame is None or min(frame.shape[:2]) < 64 or max(frame.shape[:2]) > 1600:
            raise HTTPException(422, "Expected a decodable frame with dimensions between 64 and 1600 pixels")
        return bytes(data), frame

    @app.get("/")
    async def index():
        return HTMLResponse((STATIC/"live.html").read_text().replace("__SESSION_TOKEN__", token), headers={"Cache-Control":"no-store"})

    @app.get("/api/status")
    async def status():
        return {"astra_available":has_astra(), "diagnosis_status":"not_configured", "transport":"loopback_browser_frames"}

    @app.post("/api/frame")
    async def frame(request: Request):
        if frame_lock.locked():
            raise HTTPException(429, "Frame analysis busy; send the next frame later")
        async with frame_lock:
            _, decoded = await read_frame(request)
            start=time.monotonic()
            result=await run_in_threadpool(analyze_frame, decoded)
            result["processing_ms"]=(time.monotonic()-start)*1000
            return result

    @app.post("/api/snapshot")
    async def snapshot(request: Request):
        data, decoded = await read_frame(request)
        mode=request.headers.get("x-source-mode", "unknown")
        if mode not in ("live_camera", "recorded_video"):
            raise HTTPException(422, "Specify live_camera or recorded_video source")
        case="live-"+secrets.token_hex(8)
        folder=output/case
        folder.mkdir(parents=True,exist_ok=False)
        (folder/"frame_00000000.jpg").write_bytes(data)
        digest=hashlib.sha256(data).hexdigest()
        metrics=await run_in_threadpool(analyze_frame, decoded)
        manifest={"schema_version":"0.2", "source_sha256":digest,
                  "source_name":"browser_snapshot.jpg", "source_type":"single_frame",
                  "capture_mode":mode, "captured_at_utc":datetime.now(timezone.utc).isoformat(),
                  "timestamp_note":"Server receipt time, not sensor exposure time",
                  "frames":[{"frame_index":0,"timestamp_ms":0,"image_file":"frame_00000000.jpg",
                             "image_sha256":digest,"image_size_wh":metrics['image_size_wh']}],
                  "diagnosis":{"status":"not_configured"}}
        (folder/"manifest.json").write_text(json.dumps(manifest,indent=2)+'\n')
        (folder/"geometry.json").write_text(json.dumps(metrics,indent=2)+'\n')
        return {"case_id":case,"mode":mode,"snapshot_url":f"/api/snapshot/{case}","saved_directory":str(folder)}

    def case_folder(case):
        if not re.fullmatch(r"live-[0-9a-f]{16}",case):
            raise HTTPException(404,"Unknown snapshot")
        folder=output/case
        if not (folder/"manifest.json").is_file():
            raise HTTPException(404,"Unknown snapshot")
        return folder

    @app.get("/api/snapshot/{case}")
    async def snapshot_image(case: str, request: Request):
        authorize(request)
        return FileResponse(case_folder(case)/"frame_00000000.jpg",headers={"Cache-Control":"no-store"})

    @app.post("/api/review/{case}")
    async def review(case: str, request: Request):
        authorize(request)
        folder=case_folder(case)
        existing=folder/"endpoint-prediction.json"
        if existing.exists():
            return json.loads(existing.read_text())
        if not has_astra():
            raise HTTPException(503,"Configure OPENAI_API_KEY and install the astra extra, then restart eye-live")
        if review_lock.locked():
            raise HTTPException(409,"A review is already running")
        async with review_lock:
            from .astra import analyze
            try:
                result=await run_in_threadpool(analyze,folder/"manifest.json",case,endpoint_review=True)
            except Exception:
                raise HTTPException(502,"Astra review failed; no diagnosis or substitute result was generated") from None
            existing.write_text(json.dumps(result,indent=2)+'\n')
            return result

    return app


def main():
    parser=argparse.ArgumentParser(description="Local live eye-camera demo")
    parser.add_argument("--port",type=int,default=8765)
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("Port must be between 1 and 65535")
    import uvicorn
    configure_api_key()
    print(f"Open http://127.0.0.1:{args.port} on this Mac; choose the iPhone Continuity Camera.")
    uvicorn.run(create_app(args.output),host="127.0.0.1",port=args.port,access_log=False)


if __name__ == "__main__":
    main()
