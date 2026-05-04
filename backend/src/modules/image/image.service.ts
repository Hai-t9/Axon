import { ImageRepository } from './image.repository';
import * as crypto from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { v4 as uuid } from 'uuid';
import ExifReader from 'exifreader';
import sharp from 'sharp';
import { prisma } from '../../lib/prisma';

export class ImageService {
  private repository = new ImageRepository();

  async uploadImage(userId: number, teamId: number, file: Express.Multer.File, label?: string) {
    this.validateImageFormat(file);
    this.validateImageSize(file);

    const hash = this.generateImageHash(file);
    await this.checkDuplicateImage(hash);

    const filepath = await this.storeImageFile(file);
    const metadata = await this.extractMetadata(file); // Made async for sharp
    const deviceName = metadata.Model && metadata.Model !== 'Unknown'
      ? `${metadata.Make} ${metadata.Model}`.trim()
      : 'Unknown';

    const record = await this.repository.create({
      team_id: teamId,
      author_id: userId,
      filepath,
      image_hash: hash,
      label,
      original_filename: file.originalname || 'unknown',
      old_extension: file.originalname?.split('.').pop() || 'unknown',
      old_size_mb: file.size / (1024 * 1024),
      old_width: metadata.ImageWidth,
      old_height: metadata.ImageLength,
      device: deviceName,
      metadata: {
        ImageWidth: metadata.ImageWidth,
        ImageLength: metadata.ImageLength,
        New_size_mb: metadata.New_size_mb,
        Make: metadata.Make,
        Model: metadata.Model,
        Software: metadata.Software,
        GPSInfo: metadata.GPSInfo,
        Orientation: metadata.Orientation,
        DateTime: metadata.DateTime,
        format_change: metadata.format_change
      },
    });

    return record;
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
    return await this.repository.updateStatus(imageId, status);
  }

  async deleteImage(imageId: number) {
    const image = await this.getImageById(imageId);
    if (!image) return false;

    await this.deleteFileFromDisk(image.filepath);
    await this.deleteMetadataFromDb(imageId);

    return await this.repository.delete(imageId);
  }

  async getImageStats(compId: number) {
    return await this.repository.getStats(compId);
  }

  private validateImageFormat(file: Express.Multer.File) {
    const allowed = ['image/jpeg', 'image/png', 'image/jpg'];
    if (!allowed.includes(file.mimetype)) {
      throw new Error(`Invalid format. Allowed: ${allowed.join(', ')}`);
    }
  }

  private validateImageSize(file: Express.Multer.File) {
    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
      throw new Error('Image size exceeds 5MB limit.');
    }
  }

  private generateImageHash(file: Express.Multer.File): string {
    return crypto.createHash('sha256').update(file.buffer).digest('hex');
  }

  private async checkDuplicateImage(hash: string) {
    const existing = await this.repository.findByHash(hash);
    if (existing) {
      throw new Error('Duplicate image detected.');
    }
  }

  private async storeImageFile(file: Express.Multer.File): Promise<string> {
    const uploadsDir = path.join(process.cwd(), 'uploads');
    await fs.mkdir(uploadsDir, { recursive: true });

    const ext = file.originalname.split('.').pop();
    const filename = `${uuid()}.${ext}`;
    const filepath = path.join('uploads', filename);

    await fs.writeFile(path.join(process.cwd(), filepath), file.buffer);
    return filepath;
  }

  private async extractMetadata(file: Express.Multer.File) {
    let tags: any = {};
    let safeWidth = 0;
    let safeHeight = 0;

    try {
      tags = ExifReader.load(file.buffer);
    } catch (e) {
      console.warn('Failed to extract EXIF data');
    }

    try {
      const metadata = await sharp(file.buffer).metadata();
      safeWidth = metadata.width || 0;
      safeHeight = metadata.height || 0;
    } catch (e) {
      console.warn('Failed to extract structural dimensions via Sharp');
    }

    return {
      ImageWidth: tags['ImageWidth']?.value || safeWidth,
      ImageLength: tags['ImageLength']?.value || safeHeight,
      New_size_mb: file.size / (1024 * 1024),
      Make: tags['Make']?.description || 'Unknown',
      Model: tags['Model']?.description || 'Unknown',
      Software: tags['Software']?.description || 'Unknown',
      GPSInfo: (tags['GPSLatitude'] && tags['GPSLongitude'])
        ? `${tags['GPSLatitude'].description}, ${tags['GPSLongitude'].description}`
        : undefined,
      Orientation: tags['Orientation']?.value || 1,
      DateTime: tags['DateTimeOriginal']?.description
        ? new Date(tags['DateTimeOriginal'].description.replace(/:/g, '/'))
        : new Date(),
      format_change: file.mimetype.split('/')[1] || 'unknown',
    };
  }

  private async deleteFileFromDisk(filepath: string) {
    try {
      await fs.unlink(path.join(process.cwd(), filepath));
    } catch (e) {
      console.warn(`Could not delete file at ${filepath}`);
    }
  }

  private async deleteMetadataFromDb(imageId: number) {
    try {
      await prisma.imageMetadata.deleteMany({ where: { image_id: imageId } });
    } catch (e) {
      console.warn(`Could not delete metadata for image ${imageId}`);
    }
  }
}