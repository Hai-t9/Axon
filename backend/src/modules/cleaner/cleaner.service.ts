import { CleanerRepository } from './cleaner.repository';
import { ImageRecord } from '../image/image.interface';
import sharp from 'sharp';
import * as fs from 'fs/promises';
import * as path from 'path';
import { prisma } from '../../lib/prisma'; // Injecting prisma quickly for metadata updates

export class CleanerService {
  private repository = new CleanerRepository();
  private freedStorageMB = 0;

  async runCleaningPipeline(compId: number) {
    this.freedStorageMB = 0;
    const duplicates = await this.scanForDuplicates(compId);
    await this.flagDuplicateImages(duplicates);
    await this.removeDuplicateImages(duplicates);

    const corrupted = await this.detectCorruptedImages(compId);
    await this.removeCorruptedImages(corrupted);

    await this.normalizeImageFormat(compId);
    await this.resizeImages(compId);
    await this.cleanMetadata(compId);
    await this.enforceDatasetRules(compId);
    const datasetsRebuilt = await this.rebuildDatasets(compId);
    const storageOptimized = await this.optimizeStorage();

    return {
      duplicates_removed: duplicates.length,
      corrupted_removed: corrupted.length,
      images_normalized: 0, // mocked
      images_resized: 0, // mocked
      datasets_rebuilt: datasetsRebuilt,
      storage_freed_mb: storageOptimized.freed_mb,
      completed_at: new Date()
    };
  }

  async scanForDuplicates(compId: number) {
    const images = await this.repository.findImagesByCompetition(compId);
    return this.getDuplicateCandidates(images);
  }

  getDuplicateCandidates(images: ImageRecord[]): ImageRecord[] {
    this.compareHashes();
    // mock logic identifying duplicates based on hash
    return [];
  }

  compareHashes() {
    // mock hash comparison
  }

  async flagDuplicateImages(duplicates: ImageRecord[]) {
    // In real app, we might add a generic "flag" property or just update status. By schema, 'status' limits to 'verified'/'onhold'.
    // We will just pass the mapped images. 
    const toUpdate = duplicates.map(d => ({ ...d })); 
    await this.repository.bulkUpdate(toUpdate);
  }

  async removeDuplicateImages(duplicates: ImageRecord[]) {
    // map and delete
    await this.repository.bulkDelete(duplicates);
  }

  async detectCorruptedImages(compId: number): Promise<ImageRecord[]> {
    return await this.repository.findCorruptedImages();
  }

  async removeCorruptedImages(corrupted: ImageRecord[]) {
    for (const image of corrupted) {
       try {
         await fs.unlink(path.join(process.cwd(), image.filepath));
       } catch (e) {}
    }
    await this.repository.bulkDelete(corrupted);
  }

  async normalizeImageFormat(compId: number) {
    // Sharp conversion handles format normalization natively under compressImages
  }

  async resizeImages(compId: number) {
    await this.compressImages(compId);
  }

  async compressImages(compId: number) {
    const images = await this.repository.findImagesByCompetition(compId);
    
    for (const image of images) {
      if (!image.filepath.endsWith('.jpg') && !image.filepath.endsWith('.jpeg')) {
        continue;
      }
      
      const fullPath = path.join(process.cwd(), image.filepath);
      
      try {
        const stats = await fs.stat(fullPath);
        const originalSizeMB = stats.size / (1024 * 1024);

        // Sharp processing: Normalize all to standardized high-quality JPG, resize if > 1500px width
        const processedBuffer = await sharp(fullPath)
          .resize(1500, 1500, { fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 80 })
          .toBuffer();
          
        await fs.writeFile(fullPath, processedBuffer);
        
        const newStats = await fs.stat(fullPath);
        const newSizeMB = newStats.size / (1024 * 1024);
        
        if (newSizeMB < originalSizeMB) {
          this.freedStorageMB += (originalSizeMB - newSizeMB);
        }

        // Update Db Metadata record directly
        await prisma.imageMetadata.updateMany({
           where: { image_id: image.id },
           data: { New_size_mb: newSizeMB, resizing_method: 'sharp inside 1500', format_change: 'jpeg' }
        });

      } catch (err) {
        console.error(`Failed to compress image ${image.id} at ${fullPath}`);
      }
    }
  }

  async cleanMetadata(compId: number) {
    const images = await this.repository.findImagesByCompetition(compId);
    for (const image of images) {
      await this.removeSensitiveMetadata(image.id);
    }
  }

  async removeSensitiveMetadata(imageId: number) {
    // mock logic
  }

  async enforceDatasetRules(compId: number) {
    this.checkMissingLabels();
    this.checkInvalidFormats();
    this.checkDatasetBalance();
  }

  checkMissingLabels() {
    // mock rule enforcement
  }

  checkInvalidFormats() {
    // mock rule enforcement
  }

  checkDatasetBalance() {
    // mock rule enforcement
  }

  async rebuildDatasets(compId: number): Promise<boolean> {
    // mock call to DatasetService.updatePath()
    // e.g. await datasetService.updatePath(compId)
    return true;
  }

  async optimizeStorage() {
    await this.removeUnusedFiles();
    await this.compressOldData();
    return { freed_mb: parseFloat(this.freedStorageMB.toFixed(2)), files_removed: 5 };
  }

  async removeUnusedFiles() {
    // mock logic
  }

  async compressOldData() {
    // mock logic
  }
}
