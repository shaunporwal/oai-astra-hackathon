# Partner UI integration assessment

Reviewed 2026-09-10 at [f98f3b7](https://github.com/shaunporwal/oai-astra-hackathon/tree/f98f3b7824fcb771736248af3e02f3cae33e00f4) on `feat/optlab-guided-eye-imaging`. The branch shares origin/main as its base, not our latest analysis work. It adds a complete SwiftUI application with 39 changed files, approximately 5,900 lines and its own endpoint engine.

## Recommendation

Use the partner's OptLab app as the intended main native experience after integration checks. Retain the backup as a fallback and the browser as a development console. Maintain one authoritative backend measurement/specification layer. This is a recommendation and preparation work; the partner UI has not been merged into our app.

| Partner component | Relevance | Integration action |
|---|---|---|
| Theme/components, home/session/protocol/review screens | More complete native workflow than the backup | Reuse UI structure, with honest research/demo wording |
| FrameSource, CameraService, full-resolution photo output | Native hardware ownership and still capture | Keep the interface; add an external-attachment camera mode |
| Alignment, motion, quality loop, voice guidance | Immediate acquisition feedback without API spend | Reuse, but make acceptance criteria target-specific |
| EyeCapture, ImageStore, sessions | Original images, eye identity and visit organization | Attach backend case IDs and explicit source/ROI provenance |
| Native EndpointAnalyzer, scale model and endpoint export | Duplicate outputs with incompatible semantics | Replace clinical-facing endpoint source with our shared backend |
| Synthetic source and tests | Reproducible software demonstrations | Keep clearly labeled and segregated from real captures |

Source findings: [native endpoint analyzer](https://github.com/shaunporwal/oai-astra-hackathon/blob/f98f3b7824fcb771736248af3e02f3cae33e00f4/OptLab/Analysis/EndpointAnalyzer.swift), [camera service](https://github.com/shaunporwal/oai-astra-hackathon/blob/f98f3b7824fcb771736248af3e02f3cae33e00f4/OptLab/Capture/CameraService.swift), [models](https://github.com/shaunporwal/oai-astra-hackathon/blob/f98f3b7824fcb771736248af3e02f3cae33e00f4/OptLab/Models/Models.swift).

The native scale uses an assumed HVID of 11.71 mm, reports that reference as an iris-diameter endpoint, and derives millimeter values from it. Its vessel-density output is a relative red-contrast threshold fraction, not our morphological candidate-vessel segmentation. A limbal brightness ratio and blue-deficit index are also emitted with metabolic/neuro-trauma/drug-efficacy groupings. These do not become clinically validated because the camera quality gate passes. They conflict with the limits documented in [specs/details.json](../../specs/details.json).

The capture flow requests a new full-resolution still after the live stability gate; this is useful, but the still must be rechecked rather than assuming the best live frame and subsequent photo match. The code already includes a final quality report, which is worth retaining. Its optics-based working distance assumes native lens geometry and does not account for the external macro attachment.

## Concrete work completed

Extracted the existing backup API client into `ios/shared/analysis_client.swift` and updated its Xcode reference. Added [OptLab bridge](../../ios/integrations/optlab/readme.md) that reuses this client with the partner's image/capture model and retains capture/eye association. Verified combined Swift type compatibility, resolved a DTO name collision and documented exact screen/persistence/camera changes still required. Original partner code remains unchanged.

Next implementation is one review-screen entry into backend analysis, with explicit pairing and conjunctival ROI, followed by replacement of the old endpoint table/export. After that, exercise a real capture-to-result flow on the phone before adopting the combined app as the main demo. Signing and device setup remain separate from this source integration.
