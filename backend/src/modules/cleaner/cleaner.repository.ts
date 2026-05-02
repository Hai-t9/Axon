import { ImageRecord } from '../image/image.interface';

export class CleanerRepository {
  async findImagesByCompetition(compId: number): Promise<ImageRecord[]> {
    // mock returning images to clean
    return [];
  }

  async findDuplicatesByHash(hash: string): Promise<ImageRecord[]> {
    return [];
  }

  async findCorruptedImages(): Promise<ImageRecord[]> {
    return [];
  }

  async findUnlabeledImages(compId: number): Promise<ImageRecord[]> {
    return [];
  }

  async updateImageStatus(imageId: number, status: string): Promise<boolean> {
    return true;
  }

  async deleteImage(imageId: number): Promise<boolean> {
    return true;
  }

  async bulkUpdate(images: ImageRecord[]): Promise<number> {
    return images.length;
  }

  async bulkDelete(images: ImageRecord[]): Promise<number> {
    return images.length;
  }
}
