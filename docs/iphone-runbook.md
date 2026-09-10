# iPhone 15 Pro development runbook

## Record and transfer

Use the iPhone Camera app while the Swift app is developed separately. For the first engineering clip, record 5–10 seconds of one eye in comfortable diffuse light. Keep the eye in focus and the phone steady; move back if the camera cannot focus. Include an ordinary blink to exercise frame selection. This is a capture experiment, not a clinical examination protocol.

For predictable decoding, use a standard SDR video recording and avoid HDR/Log/Cinematic modes for this first pass. The pipeline does not implement HDR tone mapping or color calibration. AirDrop the original MOV/MP4 to this Mac. Store personal clips in `vision/data/`, which Git ignores, or outside the repository. Do not put footage under `docs/`.

Wireless Continuity Camera is an alternative for live preview. Apple documents iPhone XR or newer, iOS 16+, macOS Ventura+, the same Apple Account with two-factor authentication, Wi-Fi/Bluetooth on, and a nearby locked phone. Enable Settings → General → AirPlay & Continuity → Continuity Camera. Source: [Apple setup](https://support.apple.com/en-us/102546). This repo has not verified Continuity Camera discovery from Python on this Mac; `eye-vision --camera N` uses backend camera indices. Recording and AirDrop require no live Python camera connection.

## Install

From the repository root:

```sh
cd vision
python3 -m venv .venv
source .venv/bin/activate
pip install -e '.[astra]'
```

The `astra` extra is optional for local video preparation and evaluation; install it to run the model adapter and its SDK tests. It is already installed in the working environment used for this implementation.

## Prepare locally

Commands below run from `vision/` with the virtual environment activated:

```sh
eye-prepare ~/Downloads/eye.mov --output runs/phone-001
open runs/phone-001/contact_sheet.jpg
```

Defaults: inspect up to the first 60 seconds, sample about once per second, keep at most eight frames, and reduce each selected image to a maximum side of 1536 pixels. Every candidate is treated as a close-up image; there is no full-face requirement and no claim that an eye was detected. Selection ranks sharpness with a penalty for dark/clipped pixels, which can still favor eyelashes, noise, or background. Always inspect the contact sheet.

The output includes individual JPEGs, a contact sheet, and `manifest.json`. The original video is unchanged. The export directory must not exist, to preserve earlier experiments.

If the decoded image is sideways, rerun into a new directory with `--rotate 90`, `180`, or `270`. The decoder may already apply container orientation: `--rotate` is an additional clockwise rotation. An optional pixel crop is applied after orientation:

```sh
eye-prepare ~/Downloads/eye.mov --output runs/phone-001-crop \
  --rotate 90 --roi 100 200 800 800 --sample-seconds 0.5 --max-frames 8
```

The example ROI must be replaced with coordinates that fit your oriented image. This is a manually specified rectangular crop, not segmentation. Omit it to use the full frame. If decoding fails, re-export as SDR H.264 MOV/MP4; actual iPhone HEVC/HDR files have not yet been tested here.

## Validate an Astra request locally

```sh
eye-astra runs/phone-001/manifest.json --case-id phone-001
```

This verifies paths/hashes and constructs the request in memory. It sends nothing, requires no API key, and produces no model prediction.

## Run one experimental Astra review

Configure `OPENAI_API_KEY` through your local shell/secret tooling. The program reads the environment, does not load `.env` automatically, and does not require a key in source code. Then:

```sh
eye-astra runs/phone-001/manifest.json --case-id phone-001 \
  --send --output runs/phone-001/prediction.json
```

`--send` uploads the selected JPEGs to OpenAI and incurs API usage. It does not upload the source movie, audio, contact sheet, or reference labels. Full-frame JPEGs can include the surrounding face/background unless you supplied a crop. The default model is `gpt-6-astra`; `--model` is available for an explicit comparison. Account access has not been tested.

The adapter uses structured output, a 4096-output-token limit, a 120-second timeout, and no automatic retries. Refusal/incomplete results become abstentions; malformed or inconsistent responses fail without a valid prediction file. `store=false` is requested; this is not a claim of zero service-side retention. See [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).

The result describes capture usability and visible evidence only. It does not provide a disease diagnosis. See [evaluation instructions](evaluation.md) before interpreting scores.
