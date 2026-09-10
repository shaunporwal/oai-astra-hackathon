# Eye Lab backup iPhone app

Independent SwiftUI/AVFoundation client for iPhone 15 Pro, with iOS 17+ deployment target. It does not edit or depend on the partner's Swift application. Open [eye-backup.xcodeproj](eye-backup.xcodeproj) in Xcode.

## Implemented

- Rear **physical wide camera**, fixed at 1× to avoid automatic camera changes under the macro attachment.
- Native live preview, autofocus/lock and bounded exposure compensation. No automatic torch or lens switching.
- Capture the most recent video frame, encoded as a JPEG with a longest side of 960 pixels. This is a video-frame capture, not full-resolution still photography or saved video recording.
- Retain captured JPEGs in the app Documents directory, with export through the share sheet.
- Mark a normalized conjunctival rectangle on the captured image, or choose pupil/iris mode.
- Send the exact JPEG/options to the shared Python snapshot endpoint. Display native overlays and local measurements.
- Explicit **Ask Astra** action for the existing six-target assessment. No OpenAI credential is stored on the phone. No automatic API requests or retry loops.

Swift only handles camera, region selection, transport and presentation. The transport/models are shared from `ios/shared/analysis_client.swift`, referenced by the Xcode target. Measurement algorithms remain in Python. The browser's live automatic-selection controller is not ported into this backup client; capture is manual. Full offline analysis and on-phone Astra inference are not implemented.

## Build

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ios/backup/eye-backup.xcodeproj -target eye-backup \
  -configuration Debug -sdk iphoneos \
  SYMROOT="$PWD/vision/runs/ios-build-products" \
  OBJROOT="$PWD/vision/runs/ios-build-intermediates" \
  CODE_SIGNING_ALLOWED=NO build
```

The unsigned build passed with Xcode 26.6 / iOS SDK 26.5. Using `-target` works on this Mac; the scheme destination build currently reports a missing iOS platform component. An unsigned build cannot be installed on the phone. The user subsequently connected an iPhone 15 Pro and USB pairing was confirmed. Developer Mode was disabled at detection and this Mac had no signing identity, so physical camera behavior and installation remain untested.

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

Use Universal Clipboard or another private transfer to paste the full JSON into **Pair with analysis server** on the phone, then tap **Use pairing configuration**. Pairing lives in app memory and must be re-entered after app termination. The server regenerates the token on every restart. Pairing files and captures are Git-ignored; the file is mode 0600. The remote root page does not reveal a session token, and analysis endpoints require the pairing token. Redirects are refused by the native client.

After capture, select a region and tap **Analyze on Mac**. This makes no Astra request. Inspect the overlay and measurement status before using **Ask Astra**. Results apply to the captured image; changing the target or region invalidates the old local result. The current model remains experimental and does not establish a diagnosis.

## Verification

Swift SDK typecheck and unsigned device build passed. A native Foundation contract executable decoded a real Python-generated synthetic snapshot response and round-tripped normalized ROI options. The Python suite contains 35 tests, including remote token non-disclosure, host restrictions and authenticated phone-style JPEG analysis. No simulator runtime was installed. The physical iPhone was detected but the app was not installed; UI gestures, focus behavior, exposure changes and local-network permission flows require the device smoke check above.

Apple references: [AVCam camera app](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app), [capture-device configuration](https://developer.apple.com/documentation/avfoundation/avcapturedevice/lockforconfiguration()), [local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [local networking ATS key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).
