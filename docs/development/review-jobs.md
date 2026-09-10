# Recoverable Astra reviews and combined analysis

## Timeout finding

Recent iPhone requests had completed `endpoint-prediction.json` files on the Mac even though the phone displayed a timeout. One inspected response took 62.26 seconds. This establishes a response-delivery/wait failure for those cases, not a missing API key or an absent model response. It does not identify which network/session timer caused every failure.

## Mobile job protocol

- `GET /api/review-job/{case}` checks a saved case without invoking Astra. States: not_started, running, completed, failed, interrupted. Completed responses include the cached result.
- `POST /api/review-job/{case}` explicitly starts a Mac background task. Repeated starts of a running/completed case reuse it. Only one new review runs at a time. Existing synchronous `/api/review/{case}` remains for browser compatibility.
- The phone checks cached state first, submits only when needed, then polls the Mac every two seconds (up to 120 polls). Individual calls use a 15-second request timeout and explicit URLSession timeout configuration.
- Dismissing the popup does not stop the Mac task. Network failure or app suspension can still interrupt polling; reopening checks the same saved case. Completed server results are recovered even from reopened phone-library records before considering a new snapshot.
- Job status persists beside the case. An unfinished job after a Mac restart is reported as interrupted; an explicit send can restart it. The original upstream request might have been billed. Polling itself never submits an OpenAI request.

The job is on the Mac, not OpenAI's background API. The existing upstream `store=false`, model and no-retry settings remain unchanged. OpenAI also documents an asynchronous response/polling option in its [background-mode guide](https://developers.openai.com/api/docs/guides/background); this implementation addresses the phone-to-Mac wait without changing upstream retention behavior.

## Combined analysis and segmentation

The old native selector controlled local processing/overlays, not which research targets Astra assessed. Pupil/iris geometry estimates relative dimensions; conjunctival vessel coverage uses a selected tissue region. Astra already reviewed all six targets.

New native captures use `combined`, which runs both existing local measurement methods in one pass; the selector is removed. The review popup and saved image show available pupil/iris ellipse candidates and vessel masks together. Missing/failed boundaries stay unavailable. Existing records retain their original case/options for cache recovery.

These are experimental local boundaries, not Astra-generated or validated anatomical masks. Vessel coverage still requires a user-designated conjunctival rectangle. A useful next segmentation milestone is a dedicated tissue model evaluated against independently labeled pupil, iris, conjunctiva and glare masks; Astra can describe the original image while quantitative mask validation remains separate. No new full automatic conjunctival segmentation model is claimed in this change.

## Verification

39 Python tests passed, including delayed-job single submission, repeated start/poll, cached recovery, failed jobs, interrupted state after restart, and combined measurements. The native client recovered a recent completed six-target result from the running backend without model submission. Signed iPhone build/install/launch passed. No paid request was made during this fix.
