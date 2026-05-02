import { Router } from 'express';
import { CleanerController } from './cleaner.controller';

const router = Router();
const cleanerController = new CleanerController();

// Run full cleaning pipeline
router.post('/competitions/:compId/cleaner/run', cleanerController.handleRunCleaningPipeline);

// Scan for duplicate images
router.post('/competitions/:compId/cleaner/scan-duplicates', cleanerController.handleScanDuplicates);

// Clean dataset for a team
router.post('/teams/:teamId/cleaner/clean', cleanerController.handleCleanDataset);

// Optimize storage
router.post('/competitions/:compId/cleaner/optimize-storage', cleanerController.handleOptimizeStorage);

export default router;

