import { Request, Response } from 'express';
import { ImageService } from './image.service';

const imageService = new ImageService();

export class ImageController {
  async handleUploadImage(req: Request, res: Response) {
    try {
      const teamId = parseInt(req.params.teamId, 10);
      const userId = (req as any).user?.id || 1; // mocked user id from auth
      const label = req.body.label;
      const file = req.file;

      if (!file) {
        return res.status(400).json({ error: 'Image file is required' });
      }

      const result = await imageService.uploadImage(userId, teamId, file, label);
      return res.status(201).json(result);
    } catch (error: any) {
      return res.status(400).json({ error: error.message });
    }
  }

  async handleGetImageById(req: Request, res: Response) {
    try {
      const id = parseInt(req.params.id, 10);
      const image = await imageService.getImageById(id);
      if (!image) {
        return res.status(404).json({ error: 'Image not found' });
      }
      return res.json(image);
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleGetImagesByTeam(req: Request, res: Response) {
    try {
      const teamId = parseInt(req.params.teamId, 10);
      const status = req.query.status as string;
      const page = parseInt(req.query.page as string, 10) || 1;

      const result = await imageService.getImagesByTeam(teamId, status, page);
      return res.json({ ...result, page });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleGetImagesByCompetition(req: Request, res: Response) {
    try {
      const compId = parseInt(req.params.compId, 10);
      const status = req.query.status as string;

      const result = await imageService.getImagesByCompetition(compId, status);
      return res.json(result);
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleGetImagesByStatus(req: Request, res: Response) {
    try {
      const status = req.query.status as string;
      if (!status) {
         return res.status(400).json({ error: 'Status parameter is required' });
      }
      const images = await imageService.getImagesByStatus(status);
      return res.json({ images, total: images.length });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleUpdateImageStatus(req: Request, res: Response) {
    try {
      const id = parseInt(req.params.id, 10);
      const { status } = req.body;

      if (status !== 'onhold' && status !== 'verified') {
        return res.status(400).json({ error: 'Invalid status' });
      }

      const updated = await imageService.updateImageStatus(id, status);
      if (!updated) {
        return res.status(404).json({ error: 'Image not found' });
      }

      return res.json({ id: updated.id, status: updated.status });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleDeleteImage(req: Request, res: Response) {
    try {
      const id = parseInt(req.params.id, 10);
      const deleted = await imageService.deleteImage(id);

      if (!deleted) {
        return res.status(404).json({ error: 'Image not found' });
      }

      return res.json({ message: 'Image deleted successfully' });
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }

  async handleGetImageStats(req: Request, res: Response) {
    try {
      const compId = parseInt(req.params.compId, 10);
      const stats = await imageService.getImageStats(compId);
      return res.json(stats);
    } catch (error: any) {
      return res.status(500).json({ error: error.message });
    }
  }
}
