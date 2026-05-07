-- Migration: Model Submission System Updates
-- Description:
--   1. Add model_spec JSON column to config table
--   2. Fix Evaluation.model_id FK type from Integer to UUID
--   3. Add necessary indexes for model queries
-- Date: 2026-05-07

-- ============================================
-- 1. Add model_spec column to config table
-- ============================================
ALTER TABLE config ADD COLUMN IF NOT EXISTS model_spec jsonb DEFAULT NULL;

COMMENT ON COLUMN config.model_spec IS 'Organizer-defined Docker submission requirements (required files, model formats, max size, etc.)';

-- ============================================
-- 2. Fix Evaluation.model_id Foreign Key Type
-- ============================================

-- Drop the old foreign key constraint
ALTER TABLE evaluation DROP CONSTRAINT IF EXISTS evaluation_model_id_fkey;

-- Drop the old column
ALTER TABLE evaluation DROP COLUMN IF EXISTS model_id;

-- Add the new UUID column with proper foreign key
ALTER TABLE evaluation ADD COLUMN model_id uuid NOT NULL UNIQUE;

ALTER TABLE evaluation ADD CONSTRAINT evaluation_model_id_fkey
  FOREIGN KEY (model_id) REFERENCES model(id) ON DELETE CASCADE;

-- Create index on the new foreign key
CREATE INDEX IF NOT EXISTS idx_evaluation_model_id ON evaluation(model_id);

-- ============================================
-- 3. Ensure Model table has correct defaults
-- ============================================

-- The id column should use uuid_generate_v4() by default
-- This is typically already set, but ensure it's correct
ALTER TABLE model ALTER COLUMN id SET DEFAULT uuid_generate_v4();

-- ============================================
-- 4. Add indexes for common model queries
-- ============================================

-- Already exist from original schema, but ensure they're there
CREATE INDEX IF NOT EXISTS idx_model_team_id ON model(team_id);
CREATE INDEX IF NOT EXISTS idx_model_competition_id ON model(competition_id);
CREATE INDEX IF NOT EXISTS idx_model_submitted_by ON model(submitted_by);
CREATE INDEX IF NOT EXISTS idx_model_status ON model(status);
CREATE INDEX IF NOT EXISTS idx_model_hash ON model(model_hash);

-- Additional index for version tracking per team/competition
CREATE INDEX IF NOT EXISTS idx_model_team_competition_version
  ON model(team_id, competition_id, version DESC);

-- ============================================
-- 5. Verify schema integrity
-- ============================================

-- Ensure Model.format column has the ModelFormat enum type
-- (This should already exist from the initial schema)

-- Add comment to the new model_spec column
COMMENT ON COLUMN public.config.model_spec IS
  'Docker submission spec defined by organizer: {
    required_files: string[],
    model_dir: string,
    data_dir: string,
    inference_function: string,
    allowed_model_formats: string[],
    required_packages: string[],
    max_size_mb: float,
    python_version_min: string | null
  }';
