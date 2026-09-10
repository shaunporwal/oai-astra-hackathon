# Eye vision research prototype

Python tooling for iPhone eye-video preparation, experimental capture review, and evaluation. The current recording uses an iPhone 15 Pro with a 15× macro attachment. The Swift app is a separate workstream.

## Repository layout

```text
specs/                   Target definitions and original proposal CSV
docs/
  guides/                Capture and manual-review instructions
  research/              Literature, targets, data, evaluation, and healthcare boundaries
  development/           Architecture, activity log, and PR description
vision/
  eye_vision/            Python implementation
  tests/                 Automated checks
  examples/              Annotation template
  runs/                  Local generated artifacts (Git-ignored)
data/                    Original recordings and capture metadata (Git-ignored)
```

## Start here

- [Documentation index](docs/readme.md)
- [iPhone workflow](docs/guides/iphone-runbook.md)
- [Python package and commands](vision/readme.md)
- [Research targets](specs/details.json) and [original proposal](specs/details.csv)
- [Presentation literature](docs/research/literature-review.md)
- [Activity log](docs/development/activity-log.md)

## Local setup

From the repository root:

```sh
cd vision
python3 -m venv .venv
source .venv/bin/activate
pip install -e '.[astra]'
eye-prepare ../data/img_2377.mov --output runs/phone-002
```

Choose a new output directory for every preparation run. See the workflow guide to review frames manually or run the optional API adapter.

The pipeline currently prepares video and supports capture-quality review/evaluation. Segmentation, biomarker accuracy, and clinical diagnostic performance have not been established.

For a selectable live iPhone camera and analysis dashboard, see the [live demo guide](docs/guides/live-demo.md).

## Backup iPhone client

An independent SwiftUI/AVFoundation capture client is in [ios/backup](ios/backup/readme.md). It shares the Python measurement service and leaves the partner app separate.
