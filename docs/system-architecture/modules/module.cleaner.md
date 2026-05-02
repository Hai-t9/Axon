# Cleaner System

## Controllers

- `handleRunCleaningPipeline()`
- `handleScanDuplicates()`
- `handleCleanDataset(teamId)`
- `handleOptimizeStorage()`

## Services

- `runCleaningPipeline(compId)`
  - → `scanForDuplicates(compId)`
  - → `flagDuplicateImages(duplicates)`
  - → `removeDuplicateImages(duplicates)`
  - → `detectCorruptedImages(compId)`
  - → `removeCorruptedImages()`
  - → `normalizeImageFormat(compId)`
  - → `resizeImages(compId)`
  - → `cleanMetadata(compId)`
  - → `enforceDatasetRules(compId)`
  - → `rebuildDatasets(compId)`
  - → `optimizeStorage()`

- `scanForDuplicates(compId)`
- `getDuplicateCandidates(images)`
- `compareHashes()`

- `flagDuplicateImages(duplicates)`
- `removeDuplicateImages(duplicates)`

- `detectCorruptedImages(compId)`
- `removeCorruptedImages()`

- `normalizeImageFormat(compId)`
- `resizeImages(compId)`
- `compressImages(compId)`

- `cleanMetadata(compId)`
- `removeSensitiveMetadata(imageId)`

- `enforceDatasetRules(compId)`
  - → `checkMissingLabels()`
  - → `checkInvalidFormats()`
  - → `checkDatasetBalance()`

- `rebuildDatasets(compId)`
  - → call `DatasetService.updatePath()`

- `optimizeStorage()`
  - → `removeUnusedFiles()`
  - → `compressOldData()`

## Repository

- `findImagesByCompetition(compId)`
- `findDuplicatesByHash(hash)`
- `findCorruptedImages()`
- `findUnlabeledImages(compId)`
- `updateImageStatus(imageId, status)`
- `deleteImage(imageId)`
- `bulkUpdate(images)`
- `bulkDelete(images)`

## API Endpoints

### `POST /competitions/:compId/cleaner/run`
**Description:** Run full cleaning pipeline
**Auth:** true
**Role:** host|staff
**Input:**
- `:compId` (integer path, required)
**Output:**
- `duplicates_removed` (integer)
- `corrupted_removed` (integer)
- `images_normalized` (integer)
- `images_resized` (integer)
- `datasets_rebuilt` (boolean)
- `storage_freed_mb` (float)
- `completed_at` (timestamp)

### `POST /competitions/:compId/cleaner/scan-duplicates`
**Description:** Scan for duplicate images
**Auth:** true
**Role:** host|staff
**Input:**
- `:compId` (integer path, required)
**Output:**
- `duplicate_groups` (`{ hash: string, image_ids: integer[] }[]`)
- `total_duplicates` (integer)

### `POST /teams/:teamId/cleaner/clean`
**Description:** Clean dataset for a team
**Auth:** true
**Role:** host|staff
**Input:**
- `:teamId` (integer path, required)
**Output:**
- `images_processed` (integer)
- `issues_found` (string[])

### `POST /competitions/:compId/cleaner/optimize-storage`
**Description:** Optimize storage
**Auth:** true
**Role:** host
**Input:**
- `:compId` (integer path, required)
**Output:**
- `freed_mb` (float)
- `files_removed` (integer)
- `completed_at` (timestamp)

