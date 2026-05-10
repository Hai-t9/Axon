-- If you may have existing integer data, note: it cannot be reliably converted to uuid.
-- Consider backing up or handling data first.

ALTER TABLE image
  DROP CONSTRAINT IF EXISTS image_duplicate_of_id_fkey;

ALTER TABLE image
  DROP COLUMN IF EXISTS duplicate_of_id;

ALTER TABLE image
  ADD COLUMN duplicate_of_id uuid;

ALTER TABLE image
  ADD CONSTRAINT image_duplicate_of_id_fkey
  FOREIGN KEY (duplicate_of_id) REFERENCES image(id) ON DELETE SET NULL;

ALTER TABLE image
  ADD COLUMN IF NOT EXISTS is_duplicate boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS duplicate_reason text,
  ADD COLUMN IF NOT EXISTS corrupted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS corrupted_error text;

CREATE INDEX IF NOT EXISTS idx_image_is_duplicate ON image(is_duplicate);
CREATE INDEX IF NOT EXISTS idx_image_corrupted ON image(corrupted);