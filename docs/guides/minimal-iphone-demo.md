# Minimal iPhone macro demo

Use the independent native client in `ios/backup` with the existing Python backend. Partner UI integration can wait. The flow is live rear-camera preview → save one frame → mark conjunctival region (or select pupil/iris) → **Analyze + Ask Astra** → expand endpoint results.

## Current installation step

The app has been signed with the user's Personal Team and installed on the connected iPhone 15 Pro. Developer Mode is enabled. The first launch was blocked by iOS pending developer trust; signature verification passed and the provisioning profile includes the phone. On the phone, open **Settings → General → VPN & Device Management**, select the developer account, and trust it (follow any restart prompt). Then open **Eye Lab Backup** and allow Camera/Local Network access.

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

Paste into **Pair with analysis server** on the phone using Universal Clipboard, then tap **Use pairing configuration**. Re-pair after restarting the app or server. The API key stays in the Mac environment; it is not embedded in the iPhone app.

## Capture and assess

1. Put the external 15× attachment over the **rear main/wide camera**, used at 1×. Check preview for correct lens placement, focus and reflections. Stop Mac Continuity Camera use before opening the native camera.
2. Capture a frame. This freezes a 960-pixel-long-side JPEG from video; it does not record a temporal video sequence or take a full-resolution still.
3. For conjunctival vessels, drag a rectangle over exposed conjunctiva, excluding iris, skin and eyelids. For pupil/iris mode, a region is not needed.
4. Tap **Analyze + Ask Astra**. The Mac measures the saved JPEG, then sends that same frame for structured Astra review. Expand endpoint results and local measurements to inspect output.
5. Retake to start another capture. No background Astra loop is running. Completed assessments disable the main action; a failed review retains its saved case for explicit retry. Server-cached successful reviews do not incur another request. A failed or interrupted upstream request may still be billed.

The optional **Local analysis only** dropdown runs measurements without an Astra request. Captured JPEGs can be exported from the phone; backend cases and structured JSON are stored under ignored `vision/runs/mobile/`.

## What the demo demonstrates

Native macro-image acquisition, reproducible frame-specific processing, candidate vessel coverage or pupil/iris ratio when measurable, and Astra observations for six specified research endpoints. Numerical measurements come from the local image algorithms; Astra does not invent missing values. Some endpoints need different views, calibration or temporal protocols and will remain unavailable. This is a capture-and-assessment prototype, not a validated diagnostic application. See [clinical value](../research/clinical-value.md) for the clinical workflow and evidence plan.

Installation succeeded. First launch after trust, camera alignment through this attachment, and phone-to-Mac networking still require an on-device smoke check.
