import { ImageRepository } from './image.repository';
import * as crypto from 'crypto';
import ExifReader from 'exifreader';

export class ImageService {
  private repository = new ImageRepository();

  async uploadImage(userId: number, teamId: number, file: Express.Multer.File, label?: string) {
    this.validateImageFormat(file);
    this.validateImageSize(file);
    
    const hash = this.generateImageHash(file);
    await this.checkDuplicateImage(hash);
    
    const filepath = await this.storeImageFile(file);
    
    const metadata = this.extractMetadata(file);
    const deviceName = metadata.Model !== 'Unknown' ? `${metadata.Make} ${metadata.Model}`.trim() : 'Unknown';
    
    const record = await this.saveImageRecord(userId, teamId, filepath, hash, deviceName, label);
    await this.storeImageMetadata(record.id, metadata);

    const fullRecord = await this.getImageById(record.id);
    return fullRecord;
  }

  async getImageById(imageId: number) {
    return await this.repository.findById(imageId);
  }

  async getImagesByTeam(teamId: number, status?: string, page: number = 1) {
    return await this.repository.findByTeam(teamId, status, page);
  }

  async getImagesByCompetition(compId: number, status?: string) {
    return await this.repository.findByCompetition(compId, status);
  }

  async getImagesByStatus(status: string) {
    return await this.repository.findByStatus(status);
  }

  async updateImageStatus(imageId: number, status: 'onhold' | 'verified') {
    // (optional) trigger validation workflow here if verified
    return await this.repository.updateStatus(imageId, status);
  }

  async deleteImage(imageId: number) {
    const image = await this.getImageById(imageId);
    if (!image) return false;

    await this.deleteMetadata(imageId);
    await this.deleteFile(image.filepath);
    
    return await this.repository.delete(imageId);
  }

  async getImageStats(compId: number) {
    return await this.repository.getStats(compId);
  }

  private validateImageFormat(file: Express.Multer.File) {
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/jpg'];
    if (!allowedMimeTypes.includes(file.mimetype)) {
      throw new Error(`Invalid format. Allowed: ${allowedMimeTypes.join(', ')}`);
    }
  }

  private validateImageSize(file: Express.Multer.File) {
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (file.size > maxSize) {
      throw new Error('Image size exceeds the maximum allowed limit of 5MB.');
    }
  }

  private generateImageHash(file: Express.Multer.File): string {
    return crypto.createHash('sha256').update(file.buffer).digest('hex');
  }

  private async checkDuplicateImage(hash: string) {
    const existing = await this.repository.findByHash(hash);
    if (existing) {
      throw new Error('Duplicate image detected based on hash.');
    }
  }

  private async storeImageFile(file: Express.Multer.File): Promise<string> {
    // In a real application, save file buffer to disk/S3 and return path
    return `uploads/${file.originalname}`;
  }

  private async saveImageRecord(userId: number, teamId: number, filepath: string, hash: string, device: string, label?: string) {
    return await this.repository.create({
      team_id: teamId,
      author_id: userId,
      filepath,
      image_hash: hash,
      label,
      old_size_mb: 0, // Should be computed dynamically before resizing
      old_width: 0,
      old_height: 0,
      device: device,
      metadata: {} as any // Will be updated by storeImageMetadata
    });
  }

  private extractMetadata(file: Express.Multer.File) {
    let tags: any = {};
    try {
      tags = ExifReader.load(file.buffer);
    } catch (e) {
      console.warn('Failed to extract EXIF data', e);
    }

    return {
      ImageWidth: tags['ImageWidth']?.value || 1024,
      ImageLength: tags['ImageLength']?.value || 768,
      New_size_mb: file.size / (1024 * 1024),
      Make: tags['Make']?.description || 'Unknown',
      Model: tags['Model']?.description || 'Unknown',
      Software: tags['Software']?.description || 'Axon Default',
      GPSInfo: (tags['GPSLatitude'] && tags['GPSLongitude']) 
        ? `${tags['GPSLatitude'].description}, ${tags['GPSLongitude'].description}` 
        : undefined,
      Orientation: tags['Orientation']?.value,
      DateTime: tags['DateTimeOriginal']?.description ? new Date(tags['DateTimeOriginal'].description.replace(/:/g, '/')) : new Date(),
      format_change: file.mimetype.split('/')[1] || 'unknown'
    };
  }

  private async storeImageMetadata(imageId: number, metadata: any) {
    const image = await this.repository.findById(imageId);
    if (image) {
      image.metadata = metadata;
    }
  }

  private async deleteMetadata(imageId: number) {
    // Mock logic to remove attached metadata/records from related tables
    console.log(`Deleted metadata for image ${imageId}`);
  }

  private async deleteFile(filepath: string) {
    // Mock logic to delete from S3/disk
    console.log(`Deleted file at ${filepath}`);
  }
}
