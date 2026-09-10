# Eye Lab backup iPhone app

SwiftUI/AVFoundation client with visual components adapted from the partner OptLab branch. Independent capture/backend integration for iPhone 15 Pro, with iOS 17+ deployment target. It does not edit or depend on the partner's Swift application. Open [eye-backup.xcodeproj](eye-backup.xcodeproj) in Xcode.

## Implemented

- Rear **physical wide camera**, fixed at 1× to avoid automatic camera changes under the macro attachment.
- Native live preview, autofocus/lock and bounded exposure compensation. No automatic torch or lens switching.
- Capture the most recent video frame, center-cropped to a square and encoded as a 960×960 JPEG. This is a video-frame capture, not full-resolution still photography or saved video recording.
- Retain captured JPEGs in the app Documents directory, with export through the share sheet.
- Mark a normalized conjunctival rectangle on the captured image, or choose pupil/iris mode.
- Send the exact JPEG/options to the shared Python snapshot endpoint. Display native overlays and local measurements.
- Explicit **Send to Astra** action for local measurement followed by the existing six-target assessment. An optional local-only dropdown uses no API credits. No OpenAI credential is stored on the phone. No automatic API requests or retry loops.

Swift only handles camera, region selection, transport and presentation. The transport/models are shared from `ios/shared/analysis_client.swift`, referenced by the Xcode target. Measurement algorithms remain in Python. The browser's live automatic-selection controller is not ported into this backup client; native automatic capture now uses local sharpness/exposure/stability checks. Full offline analysis and on-phone Astra inference are not implemented.

## Build

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/backup/eye-backup.xcodeproj -target eye-backup \
  -configuration Debug -sdk iphoneos \
  SYMROOT="$PWD/vision/runs/ios-build-products" \
  OBJROOT="$PWD/vision/runs/ios-build-intermediates" \
  CODE_SIGNING_ALLOWED=NO build
```

The unsigned build passed with Xcode 26.6 / iOS SDK 26.5. Both the direct target build and the device-destination scheme build now work after installation of the Xcode components. An unsigned build cannot be installed on the phone. The connected iPhone 15 Pro is paired and Developer Mode is enabled. A subsequent signed scheme build and USB installation succeeded with the user’s Personal Team. iOS blocked the first launch pending developer trust; camera behavior remains untested.

## Install on your phone

1. Connect and unlock the iPhone; accept Trust prompts. Stop iPhone Continuity Camera use in the Mac browser so the native app can own the camera.
2. Open the Xcode project, select the `eye-backup` target, then **Signing & Capabilities**. Choose your Personal Team or development team; use a unique bundle identifier if Xcode requests it. No team or signing credentials are committed.
3. Install any iOS platform/device support component Xcode requests under **Settings → Components**, select the connected iPhone as the run destination, and enable Developer Mode on the phone if prompted.
4. Run the app and allow Camera and Local Network access.

## Pair with the Mac

The existing desktop server remains on port 8765. For this backup app, a separate development service was started at `http://air.local:8766` on this Mac:

```sh
vision/.venv/bin/eye-live --port 8766 \
  --lan-url http://air.local:8766 --output vision/runs/mobile
```

On another Mac, replace `air` with its LocalHostName (`scutil --get LocalHostName`). Both devices must be on the same trusted LAN; allow the Python service through the Mac firewall if prompted. This development transport uses local HTTP and is not a production deployment.

Copy the pairing JSON into the clipboard without printing its token:

```sh
pbcopy < vision/runs/mobile/mobile-pairing.json
```

Open the top-right **Settings** button. Use Universal Clipboard or another private transfer to paste the full JSON into **Mac connection** on the phone, then tap **Use pairing configuration**. Pairing lives in app memory and must be re-entered after app termination. The server regenerates the token on every restart. Pairing files and captures are Git-ignored; the file is mode 0600. The remote root page does not reveal a session token, and analysis endpoints require the pairing token. Redirects are refused by the native client.

On the single capture page, choose Manual or Auto mode. After capture, optionally select a region and tap **Send to Astra** for local measurement followed by endpoint review. Use **Settings → Measure locally · no API credits** to inspect the overlay without an Astra request. Results apply to the captured image; changing the target or region invalidates the old local result. Failed reviews retain the saved case for explicit retry, and completed assessments disable the main action. The current model remains experimental and does not establish a diagnosis. See the [minimal demo guide](../../docs/guides/minimal-iphone-demo.md).

## Verification

Swift SDK typecheck and unsigned device build passed. A native Foundation contract executable decoded a real Python-generated synthetic snapshot response and round-tripped normalized ROI options. The Python suite contains 35 tests, including remote token non-disclosure, host restrictions and authenticated phone-style JPEG analysis. The user subsequently installed the simulator/platform components. The physical iPhone app was signed and installed. Signature verification and device inclusion in the provisioning profile passed. First launch requires developer trust in iPhone Settings → General → VPN & Device Management; UI gestures, focus behavior, exposure changes and local-network permission flows still require the device smoke check above.

Apple references: [AVCam camera app](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app), [capture-device configuration](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lockforconfiguration()), [local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [local networking ATS key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

### USB pairing during development

A paired development Mac can copy the ignored `mobile-pairing.json` file to `tmp/mobile-pairing.json` inside this app’s data container using `devicectl device copy to`. At startup the app decodes this one-use file and deletes it, retaining pairing in memory. This avoids clipboard setup on the initial install; it does not embed credentials in the app bundle or persist the OpenAI key. After termination, re-provision the file or use manual pairing.

### Astra access

The primary Astra action accepts a saved frame without a drawn ROI. A conjunctival ROI is needed only for local vessel measurements. Startup and Settings include an authenticated connection/configuration check through the shared client; this does not spend API credits or validate an upstream key. The root `.env` `oai_api_key` alias is loaded by the Mac service. An API key is never embedded in the native app.

### Square framing

The live viewfinder is square and uses aspect-fill. The video-frame encoder saves the corresponding centered square before resizing to 960×960; the review canvas and backend therefore operate on square pixels without display-only stretching. The portrait sensor frame loses its excess top/bottom area. Keep the eye inside the visible square. This changes newly captured files only.

### Automatic capture and compact controls

The live capture screen uses a height-aware square viewfinder without scrolling. Retake is pinned in the top header whenever a frame exists, including Results. Tap **Auto capture when sharp** to arm a single local capture, or **Capture frame** for manual capture. Auto capture can be canceled and stops after 20 seconds, on opening Settings, when the app leaves the foreground, or after saving a frame. It never sends an Astra request.

Quality is measured on a 96×96 grayscale sample of the center 70% of the square. Autofocus and autoexposure must settle; mean intensity must be 45–225, pixels below 25 at most 35%, pixels at least 248 at most 8%, and Laplacian variance at least 80. Four eligible frames across at least 0.8 seconds are required, with no gap over 0.6 seconds and mean absolute pixel change at most 5. The sharpest exact JPEG from this window is saved through the same manual-capture path. This is an experimental engineering gate: textured non-eye scenes can pass, and passing does not prove focus across all tissue or diagnostic adequacy. Thresholds need evaluation on actual eye captures.

### Single-page capture and review popup

The numbered step navigation is removed. Auto mode is selected initially and arms local selection; Manual mode provides an explicit shutter. Retake remains in the top header after capture and re-arms selection when Auto mode is selected. **Send to Astra** opens a bounded popup immediately, showing the exact captured image, progress/errors, and expandable endpoint results inside an internal scroll view. Tap the dimmed backdrop or close button to dismiss it. Dismissal does not cancel a submitted API request; the main action reopens the in-progress/completed review without submitting again. Capture/region/settings changes are disabled while processing to keep results associated with the correct saved frame. Local-only processing is in Settings.

### Import from Photos

Tap **Import from Photos** on the main page to choose one image using Apple's system picker. Opening the picker stops local automatic capture. Importing does not contact the Mac or OpenAI. On success, the image replaces the current in-memory capture and clears prior ROI/results; on failure, the previous capture remains and an error is shown. Existing exported local capture files are retained. **Retake** returns to the camera. **Send to Astra** uses the same captured-image review modal and shared API path.

JPEG/HEIC/PNG and other still formats decodable by ImageIO are normalized to pixel-only JPEG, with orientation applied and full aspect ratio preserved (no square crop). The original Photos asset is unchanged. The longest side is at most 960 pixels; inputs over 30 MB, undecodable files and outputs under 64 pixels on either axis are rejected. Original GPS/EXIF metadata is not copied. Imported images may have display margins to preserve their full framing. The API tags these images as `imported_image`, not `live_camera`; lens/capture conditions are not verified. Outputs remain research assessments, not validated diagnoses.
