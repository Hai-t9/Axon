import { ImageRecord } from '../image/image.interface';
import { prisma } from '../../lib/prisma';

export class CleanerRepository {
  async findImagesByCompetition(compId: number): Promise<ImageRecord[]> {
    const images = await prisma.image.findMany({
      where: { team: { comp_id: compId } },
      include: { metadata: true }
    });
    return images as unknown as ImageRecord[];
  }

  async findDuplicatesByHash(hash: string): Promise<ImageRecord[]> {
    const images = await prisma.image.findMany({
      where: { image_hash: hash },
      include: { metadata: true }
    });
    return images as unknown as ImageRecord[];
  }

  async findCorruptedImages(): Promise<ImageRecord[]> {
    // Conceptually, check for missing constraints or sizes
    const images = await prisma.image.findMany({
      where: {
        OR: [
          { old_size_mb: { equals: 0 } },
          { image_hash: { equals: '' } }
        ]
      },
      include: { metadata: true }
    });
    return images as unknown as ImageRecord[];
  }

  async findUnlabeledImages(compId: number): Promise<ImageRecord[]> {
    const images = await prisma.image.findMany({
      where: {
        team: { comp_id: compId },
        label: null
      },
      include: { metadata: true }
    });
    return images as unknown as ImageRecord[];
  }

  async updateImageStatus(imageId: number, status: string): Promise<boolean> {
    try {
      await prisma.image.update({
        where: { id: imageId },
        data: { status }
      });
      return true;
    } catch {
      return false;
    }
  }

  async deleteImage(imageId: number): Promise<boolean> {
    try {
      await prisma.imageMetadata.deleteMany({ where: { image_id: imageId } });
      await prisma.image.delete({ where: { id: imageId } });
      return true;
    } catch {
      return false;
    }
  }

  async bulkUpdate(images: ImageRecord[]): Promise<number> {
    const operations = images.map(img =>
      prisma.image.update({
        where: { id: img.id },
        data: { status: img.status }
      })
    );
    await prisma.$transaction(operations);
    return images.length;
  }

  async bulkDelete(images: ImageRecord[]): Promise<number> {
    const ids = images.map(img => img.id);
    await prisma.imageMetadata.deleteMany({
      where: { image_id: { in: ids } }
    });
    const result = await prisma.image.deleteMany({
      where: { id: { in: ids } }
    });
    return result.count;
  }
}
