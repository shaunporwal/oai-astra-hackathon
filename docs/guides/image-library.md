# On-device image library

Tap **Library** beside **Import Photos** to reopen an image. New camera captures and imported photos are saved automatically. Each row shows a thumbnail, date, source and whether an Astra review is saved. The selected image returns to the capture page; **View Astra review** reopens its saved assessment without another request or API charge.

## Storage location

The database lives on the iPhone inside this app's private container:

```text
Library/Application Support/eye-library/captures.store
```

SwiftData uses SQLite with framework-managed image storage alongside the database. Records contain the image, date, source, target/region, local measurement snapshot and latest Astra review. CloudKit sync is disabled. Ordinary device backups may include app data depending on the user's backup settings; this is not a separate hosted database. Deleting the app removes its local library unless restored from backup.

Export creates a temporary JPEG for the share sheet. Original Photos assets are unchanged. Earlier `Documents/capture-*.jpg` files are indexed automatically once without deleting the originals; their original acquisition source is marked unknown and no missing historical assessment is invented.

## Offline and network behavior

Browsing images and saved reviews works offline. New Astra requests still require the Mac backend and internet access. Sending an image also retains a backend case on the Mac under `vision/runs/mobile/`; adding a phone database does not remove those copies. Reopened incomplete cases create a fresh backend snapshot before a new review, avoiding stale server case IDs. Completed phone-cached reviews reopen locally.

The library keeps the latest analysis/settings for each image rather than a full version history. Saving happens on capture/import, during analysis, and before replacing/reopening an image. File-save failures are reported rather than pretending persistence succeeded. This milestone does not add cloud sync, patient accounts, multi-device sharing or a deletion UI.

Saved outputs remain research observations and experimental measurements, not validated diagnoses.
