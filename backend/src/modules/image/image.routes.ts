import { Router } from 'express';
import multer from 'multer';
import { ImageController } from './image.controller';

const router = Router();
const upload = multer({ storage: multer.memoryStorage() }); // In memory for hashing
const imageController = new ImageController();

// Image upload
router.post('/teams/:teamId/images', upload.single('file'), imageController.handleUploadImage);

// Get image by ID
router.get('/images/:id', imageController.handleGetImageById);

// Get images by team
router.get('/teams/:teamId/images', imageController.handleGetImagesByTeam);

// Get images by competition
router.get('/competitions/:compId/images', imageController.handleGetImagesByCompetition);

// Get images by status
router.get('/images/status', imageController.handleGetImagesByStatus);

// Update status
router.patch('/images/:id/status', imageController.handleUpdateImageStatus);

// Delete image
router.delete('/images/:id', imageController.handleDeleteImage);

// Image stats
router.get('/competitions/:compId/images/stats', imageController.handleGetImageStats);

export default router;
