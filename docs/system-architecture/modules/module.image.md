# Image Module

## Controllers

- `handleUploadImage()`
- `handleGetImageById()`
- `handleGetImagesByTeam()`
- `handleGetImagesByCompetition()`
- `handleGetImagesByStatus()`
- `handleUpdateImageStatus()`
- `handleDeleteImage()`
- `handleGetImageStats()`

## Services

- `uploadImage(userId, teamId, file)`
  - → `validateImageFormat(file)`
  - → `validateImageSize(file)`
  - → `generateImageHash(file)`
  - → `checkDuplicateImage(hash)`
  - → `storeImageFile(file)`
  - → `saveImageRecord(userId, teamId, filepath, hash)`
  - → `extractMetadata(file)`
  - → `storeImageMetadata(imageId, metadata)`

- `getImageById(imageId)`
- `getImagesByTeam(teamId)`
- `getImagesByCompetition(compId)`
- `getImagesByStatus(status)`

- `updateImageStatus(imageId, status)`
  - → (optional) trigger validation workflow

- `deleteImage(imageId)`
  - → `deleteMetadata(imageId)`
  - → `deleteFile(filepath)`

- `getImageStats(compId)`
- `getTeamImageStats(teamId)`

- `validateImageFormat(file)`
- `validateImageSize(file)`
- `generateImageHash(file)`
- `checkDuplicateImage(hash)`

## Repository

- `create(data)`
- `findById(imageId)`
- `findByHash(hash)`
- `findByTeam(teamId)`
- `findByCompetition(compId)`
- `findByStatus(status)`
- `updateStatus(imageId, status)`
- `delete(imageId)`
- `countByTeam(teamId)`
- `countByStatus(status)`

## API Endpoints

### `POST /teams/:teamId/images`
**Description:** Upload an image
**Auth:** true
**Input:**
- `file` (multipart/file, required): image binary
- `label` (string, optional)
**Output:**
- `id` (integer)
- `filepath` (string)
- `image_hash` (string)
- `status` (enum: onhold|verified)
- `metadata` (ImageMetadata object)

### `GET /images/:id`
**Description:** Get image by ID
**Auth:** true
**Input:**
- `:id` (integer path, required)
**Output:**
- `id` (integer)
- `team_id` (integer)
- `author_id` (integer)
- `filepath` (string)
- `label` (string)
- `status` (enum: onhold|verified)
- `metadata` (ImageMetadata object)

### `GET /teams/:teamId/images`
**Description:** List images for a team
**Auth:** true
**Input:**
- `:teamId` (integer path, required)
- `status` (enum query, optional)
- `page` (integer query, optional)
**Output:**
- `images` (Image[])
- `total` (integer)
- `page` (integer)

### `GET /competitions/:compId/images`
**Description:** List all images in competition
**Auth:** true
**Input:**
- `:compId` (integer path, required)
- `status` (enum query, optional)
**Output:**
- `images` (Image[])
- `total` (integer)

### `PATCH /images/:id/status`
**Description:** Update image status
**Auth:** true
**Role:** staff|host
**Input:**
- `:id` (integer path, required)
- `status` (enum: onhold|verified, required)
**Output:**
- `id` (integer)
- `status` (string)

### `DELETE /images/:id`
**Description:** Delete an image
**Auth:** true
**Role:** staff|host
**Input:**
- `:id` (integer path, required)
**Output:**
- `message` (string)

### `GET /competitions/:compId/images/stats`
**Description:** Image statistics
**Auth:** true
**Input:**
- `:compId` (integer path, required)
**Output:**
- `total` (integer)
- `by_status` ({ onhold: int, verified: int })
- `by_team` ({ team_id: int, count: int }[])
- `by_label` ({ label: string, count: int }[])

