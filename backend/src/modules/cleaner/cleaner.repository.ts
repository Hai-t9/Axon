export class CleanerRepository {
  async findImagesByCompetition(compId: number) {
    // mock returning images to clean, including 'corrupted' flag mock maybe
    return [];
  }

  async findDuplicatesByHash(hash: string) {
    return [];
  }

  async findCorruptedImages() {
    return [];
  }

  async findUnlabeledImages(compId: number) {
    return [];
  }

  async updateImageStatus(imageId: number, status: string) {
    return true;
  }

  async deleteImage(imageId: number) {
    return true;
  }

  async bulkUpdate(images: any[]) {
    return images.length;
  }

  async bulkDelete(images: any[]) {
    return images.length;
  }
}

