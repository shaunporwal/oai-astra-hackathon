# iPhone macro capture and shared research endpoint assessment

Adds a browser dashboard and independent native iPhone client for saving eye-video frames and assessing them through one Python backend. The native client pins the rear wide camera at 1× for an external macro attachment, supports focus/exposure adjustment and region selection, and offers a single **Analyze + Ask Astra** action. Local-only processing remains available without API use. Saved-frame previews, session recovery, and compact expandable results support the browser flow.

Python owns candidate vessel coverage, pupil/iris geometry and structured review of six literature-grounded research targets. Missing or unsupported numerical values remain unavailable. Astra supplies observations rather than invented measurements; the application does not establish diagnoses. Credentials stay on the Mac, mobile access uses a rotating pairing token, and successful saved-case reviews are cached. API requests are explicit, with no automatic retry loop. LAN HTTP is development transport.

The backup and prepared partner-UI bridge share one Swift API client. Partner screens are not yet integrated. Specifications, literature, evaluation plans and setup guides are organized under lowercase paths.

## Validation and remaining limits

- Full unsigned native iPhone build and Swift contract checks passed, including decoding an actual six-target Astra response.
- Existing Python suite: 35 tests passed at the preceding backend milestone. Browser fake-camera checks covered manual/automatic save, stale sessions, annotation/server failures and compact layout.
- Latest running-backend smoke check used one frame from the user's macro recording and one paid Astra request: snapshot/review succeeded, but all numerical endpoints were unavailable for that frame.
- Connected iPhone and Developer Mode confirmed. Signed build and native installation succeeded. First launch is pending developer trust on the phone; attachment alignment and phone-to-Mac capture flow remain unverified. A one-use USB pairing import avoids initial clipboard setup.
- Segmentation and endpoint measurements remain experimental. Clinical evaluation needs suitable targeted captures and independent reference labels.
