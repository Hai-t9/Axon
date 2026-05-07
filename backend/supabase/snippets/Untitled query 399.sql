-- ============================================
-- Migration: Model Submission System Updates
-- ============================================

-- 1. Add model_spec column to config table
ALTER TABLE config ADD COLUMN IF NOT EXISTS model_spec jsonb DEFAULT NULL;

COMMENT ON COLUMN config.model_spec IS 'Organizer-defined Docker submission requirements';

-- 2. Fix Evaluation.model_id Foreign Key Type

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

-- 3. Ensure Model table has correct defaults
ALTER TABLE model ALTER COLUMN id SET DEFAULT uuid_generate_v4();

-- 4. Add indexes for common model queries
CREATE INDEX IF NOT EXISTS idx_model_team_id ON model(team_id);
CREATE INDEX IF NOT EXISTS idx_model_competition_id ON model(competition_id);
CREATE INDEX IF NOT EXISTS idx_model_submitted_by ON model(submitted_by);
CREATE INDEX IF NOT EXISTS idx_model_status ON model(status);
CREATE INDEX IF NOT EXISTS idx_model_hash ON model(model_hash);
CREATE INDEX IF NOT EXISTS idx_model_team_competition_version 
  ON model(team_id, competition_id, version DESC);
