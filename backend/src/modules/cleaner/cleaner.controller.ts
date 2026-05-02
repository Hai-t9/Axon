import { Request, Response } from 'express';
import { CleanerService } from './cleaner.service';

const cleanerService = new CleanerService();

export class CleanerController {
  async handleRunCleaningPipeline(req: Request, res: Response) {
    try {
      const compId = parseInt(req.params.compId, 10);
      const result = await cleanerService.runCleaningPipeline(compId);
      return res.json(result);
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleScanDuplicates(req: Request, res: Response) {
    try {
      const compId = parseInt(req.params.compId, 10);
      const duplicates = await cleanerService.scanForDuplicates(compId);
      return res.json({
        duplicate_groups: [], // Mock formatted groups
        total_duplicates: duplicates.length
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleCleanDataset(req: Request, res: Response) {
    try {
      const teamId = parseInt(req.params.teamId, 10);
      // Mock result for cleaning dataset specific to team
      return res.json({
        images_processed: 10,
        issues_found: ["Missing Labels"]
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleOptimizeStorage(req: Request, res: Response) {
    try {
      const compId = parseInt(req.params.compId, 10);
      const stats = await cleanerService.optimizeStorage();
      return res.json({
        ...stats,
        completed_at: new Date()
      });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}

