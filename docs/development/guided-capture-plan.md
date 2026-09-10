# Astra-guided capture plan

Status: local stable-window selection and camera capability reporting are implemented as a heuristic prototype. Astra action execution and persistent attempt budgets below remain proposed. No additional API requests were made to prepare this plan.

## Demonstration

User starts an eye capture session. Local image processing supplies fast positioning/stability feedback and retains a short rolling buffer. Astra periodically reviews a small selection, returns structured capture instructions, and accepts a view or requests another attempt. The interface shows its actual decisions, selected evidence, and completion time. Accepted views can feed a separate research finding-assessment task. No Swift application changes are needed for the initial browser capture work.

## Control boundary

Astra proposes actions through a constrained tool contract; the camera adapter validates supported capabilities and parameter ranges, applies permitted settings, and reports success/failure and actual settings. Proposed actions include request_refocus, set_exposure_bias, capture_best_frame, request_user_reposition, accept_view and abstain. These are design names, not existing SDK methods. Do not let model output execute arbitrary code. Do not automatically enable the torch or change physical camera lenses beneath the macro attachment.

The browser must inspect the selected track's capabilities and report which settings actually work. Receiving iPhone video through Continuity Camera does not establish access to focus, exposure or physical lens selection. Unsupported actions become positioning instructions. Native iPhone control can later use the partner's AVFoundation adapter through the same contract; implementing that adapter requires coordination with the partner, not editing their app here.

References: [browser track capabilities](https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamTrack/getCapabilities), [W3C image capture constraints](https://www.w3.org/TR/image-capture/), [Apple capture device](https://developer.apple.com/documentation/avfoundation/avcapturedevice).

## Two processing loops

Local loop: eye-region framing, sharpness, motion, exposure and reflection heuristics; stable-window selection; retain exact candidate image bytes and timestamps. Current global sharpness and dark-region pupil heuristics are insufficient to certify clear eye images. Use temporal consistency and compare selected frames against independently chosen reference frames. Capturing the already-scored frame avoids selecting a subsequent blurry frame by accident. Begin at the current processing rate and measure actual throughput before promising a frame rate.

Astra loop: one or two candidate images per request with recent local metrics and previous action outcomes. Return evidence-linked feedback plus an allowlisted action. Apply cooldowns, stale-result rejection, and one request in flight. Local movement feedback continues while the request runs. The first successful single-frame API review took 7.73 seconds; this is one observation, not a latency guarantee. It used 1,867 input and 182 output tokens. A token count alone does not establish dollar cost.

## Proposed spending limits

Default automated session: at most three API attempts total, including any final research assessment; at least 15 seconds between request starts; one request in flight; no automatic retries. Only start a request on meaningful candidate improvement or an explicit new view. Cache by image, task, prompt version and model. Stop at acceptance or the limit. Replays and selector tests default to API disabled.

Implement the attempt counter on the server, persist reservations before dispatch, and retain it across reload/restart; a browser counter is insufficient. Display usage and remaining calls. A dollar ceiling additionally requires verified pricing for this account/model and conservative preflight token reservation. Until that is known, report call/token limits without claiming a dollar guarantee. Existing code only has manual requests and no automatic retries; these proposed session limits are not yet implemented.

## Findings and evaluation

Current Astra task only assesses capture usability. Add visible findings and possible diagnoses for clinician review only after defining an evidence-grounded target, structured abstention and an independently labeled evaluation set. Never present uncertainty, model-generated labels, or a normal-looking frame as a definitive diagnosis or disease exclusion. Update findings after accepted captures with their timestamps; do not imply frame-rate diagnostic inference. The 15× attachment does not itself validate a disease endpoint; see the literature review and target specification.

First benchmark: time to an accepted view, independent usable-capture rate, false acceptance of unusable frames, selected-frame quality versus manual selection, API attempts and tokens per session. Compare guided selection against an unguided capture baseline. Clinical assessment needs separate patient-disjoint reference labels and performance evaluation.

## Implementation order

1. Inspect camera capabilities; add rolling candidate selection, stable-window auto-save and local feedback. Evaluate using the existing recording without API spend.
2. Add structured Astra capture actions, a capability-checked executor and persistent server-side attempt budget. Exercise with mocked model responses before a bounded live trial.
3. Add research finding assessment for a defined target and independently labeled cases. Integrate native camera controls through the partner's adapter if browser capabilities are insufficient.
