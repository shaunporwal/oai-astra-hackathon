# Minimal iPhone macro demo

Use the independent native client in `ios/backup` with the existing Python backend. Partner UI integration can wait. The flow is live rear-camera preview → save one frame → mark conjunctival region (or select pupil/iris) → **Send to Astra** → expand endpoint results.

## Current installation step

The app has been signed with the user's Personal Team and installed on the connected iPhone 15 Pro. Developer Mode is enabled. Developer trust is now confirmed: launching the installed app through `devicectl` succeeded. Signature verification passed and the provisioning profile includes the phone. On the phone, open **Settings → General → VPN & Device Management**, select the developer account, and trust it (follow any restart prompt). Then open **Eye Lab Backup** and allow Camera/Local Network access.

For future builds, use the connected iPhone as the Xcode run destination and select your Team under Signing & Capabilities. The signed scheme build now works after the Xcode components were installed. Personal signing details are supplied locally, not committed.

## Start and pair

The Mac service is running at `http://air.local:8766`. If stopped, start it from the repository root:

```sh
vision/.venv/bin/eye-live --port 8766 --lan-url http://air.local:8766 --output vision/runs/mobile
```

Keep the phone and Mac on the same trusted Wi-Fi and allow Camera/Local Network prompts. Copy pairing configuration without printing its token:

```sh
pbcopy < vision/runs/mobile/mobile-pairing.json
```

For this installation, pairing was transferred over USB into a one-use temporary file. The app imports and deletes it at startup; it remains in memory only. Manual pairing is still available:

Open the top-right **Settings** button and paste into **Mac connection** on the phone using Universal Clipboard, then tap **Use pairing configuration**. Re-pair after restarting the app or server. The API key stays in the Mac environment; it is not embedded in the iPhone app.

## Capture and assess

1. Put the external 15× attachment over the **rear main/wide camera**, used at 1×. Check preview for correct lens placement, focus and reflections. Stop Mac Continuity Camera use before opening the native camera.
2. Choose **Manual** and tap **Capture frame**, or use **Auto · quality**, which automatically waits for local sharpness/exposure/stability checks (20-second timeout, no API cost). This freezes a 960×960 center-square JPEG from video, matching the square viewfinder; it does not record a temporal video sequence or take a full-resolution still.
3. Optionally drag a rectangle over exposed conjunctiva to include candidate vessel measurements, excluding iris, skin and eyelids. Astra can review the saved frame without a region; local-only vessel measurement needs one. For pupil/iris mode, a region is not needed.
4. Tap **Send to Astra**. The Mac measures the saved JPEG, then sends that same frame for structured Astra review. The popup shows your captured image and assessment; scroll inside it for details. Tap outside or use Close to return to the capture page.
5. Use **Retake** in the top header to start another capture. No background Astra loop is running. Completed assessments disable the main action; a failed review retains its saved case for explicit retry. Server-cached successful reviews do not incur another request. A failed or interrupted upstream request may still be billed.

The optional **Settings → Measure locally · no API credits** action runs measurements without an Astra request. Captured JPEGs can be exported from the phone; backend cases and structured JSON are stored under ignored `vision/runs/mobile/`.

## What the demo demonstrates

Native macro-image acquisition, reproducible frame-specific processing, candidate vessel coverage or pupil/iris ratio when measurable, and Astra observations for six specified research endpoints. Numerical measurements come from the local image algorithms; Astra does not invent missing values. Some endpoints need different views, calibration or temporal protocols and will remain unavailable. This is a capture-and-assessment prototype, not a validated diagnostic application. See [clinical value](../research/clinical-value.md) for the clinical workflow and evidence plan.

Installation succeeded. Launch after trust succeeded. Camera alignment through this attachment and phone-to-Mac networking still require an on-device smoke check.

## Astra connection status

The app now checks the authenticated Mac connection at startup and after pairing. **Mac connected · Astra configured** means the phone reached the backend and the backend has an API key/SDK configured; it does not verify API balance or key validity upstream. Use **Settings → Check connection · no API credits** to retry after allowing Local Network access or changing Wi-Fi. The bottom **Send to Astra** action sends the saved frame through the Mac to Astra. **Measure locally** intentionally makes no API request. The root `.env` alias `oai_api_key` is supported; restart the Mac service and refresh phone pairing after changing the key.

## Use an existing photo

Tap **Import from Photos**, choose an image and wait for the preview. The original photo stays unchanged; the app creates an orientation-corrected JPEG for analysis. The full image is retained without the camera's square crop. Optionally mark conjunctiva, then tap **Send to Astra**. Importing alone does not upload anything or use API credits. Close the review popup to return to the image, or use Retake to return to the camera. The Mac must still be running and connected for assessment.

## Reopen saved images

Tap **Library** next to Import Photos. Captures, imports and completed assessments are saved on the iPhone; reopening a saved review makes no API request. See [image library](image-library.md) for storage details.
